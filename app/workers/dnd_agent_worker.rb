# frozen_string_literal: true

# Goal-driven D&D agent that uses LLM planning to select narrative actions.
# Instead of following a rigid pipeline (detect -> execute -> narrate), the agent:
# 1. Understands the player's intent
# 2. Plans the best action(s) to fulfill that intent
# 3. Executes actions, evaluating after each
# 4. Generates narrative when the intent is satisfied
#
# State Flow:
#   pending → running → planning → executing → evaluating ─┐
#                          ↑                               │
#                          └─── continue (intent unclear) ─┘
#                                        │
#                                        └─── intent_satisfied → narrating → complete
#
# @example
#   worker = DndAgentWorker.new(
#     goal: "I search the room for hidden doors",
#     path: sandbox_path,
#     memory_store: existing_memory_store
#   )
#   result = worker.execute
#   puts result[:narrative]
#
class DndAgentWorker < AgentWorker
  # D&D-specific states - narrating instead of synthesizing
  state :narrating, phase: :output, description: "Generating narrative response"

  # Override transition to use narrating instead of synthesizing
  transition from: :evaluating, to: :narrating, on: :intent_satisfied
  transition from: :narrating, to: :complete, on: :finish

  # Register D&D-specific actions
  register_action :remember_fact,
    class_name: "Actions::RememberFactAction",
    description: "Store a fact or event in the campaign memory",
    parameters: { fact: "string", category: "string (optional: quest, npc, location, item)" }

  register_action :recall_memory,
    class_name: "Actions::RecallMemoryAction",
    description: "Retrieve information from campaign memory",
    parameters: { query: "string", category: "string (optional)" }

  register_action :roll_dice,
    class_name: "Actions::RollDiceAction",
    description: "Roll dice for checks, damage, or random outcomes",
    parameters: { dice: "string (e.g. 2d6+3)", reason: "string" }

  register_action :skill_check,
    class_name: "Actions::SkillCheckAction",
    description: "Perform a skill check against a difficulty",
    parameters: { skill: "string", dc: "integer", modifier: "integer (optional)" }

  register_action :manage_inventory,
    class_name: "Actions::ManageInventoryAction",
    description: "Add, remove, or check inventory items",
    parameters: { action: "string (add/remove/check)", item: "string", quantity: "integer (optional)" }

  register_action :update_scene,
    class_name: "Actions::UpdateSceneAction",
    description: "Update the current scene description or state",
    parameters: { description: "string", changes: "array of strings (optional)" }

  register_action :advance_quest,
    class_name: "Actions::AdvanceQuestAction",
    description: "Update quest status or add new quest",
    parameters: { quest_name: "string", status: "string (active/completed/failed)", notes: "string (optional)" }

  # Lower limits for D&D - we want quick responses
  DEFAULT_MAX_ITERATIONS = 10
  DEFAULT_MAX_ACTIONS = 20

  attr_reader :narrative, :completed_actions

  def initialize(goal:, path:, memory_store: nil, conversation: nil, **options)
    super(goal: goal, path: path, **options)
    @external_memory_store = memory_store
    @conversation = conversation
    @completed_actions = []
    @narrative = nil
    @max_iterations = options.fetch(:max_iterations, DEFAULT_MAX_ITERATIONS)
    @max_actions = options.fetch(:max_actions, DEFAULT_MAX_ACTIONS)
  end

  # Override execute to produce a narrative result
  def execute
    @started_at = Time.now.utc
    trigger(:start)
    initialize_agent

    trigger(:initialized)

    # Main agent loop - plan and execute actions until intent is satisfied
    until should_stop?
      @iteration_count += 1

      # Plan phase: decide what to do next
      plan = plan_next_action
      break if plan[:action] == "narrate" || plan[:action] == "stop"

      trigger(:action_selected)

      # Execute phase: run the selected action
      result = execute_planned_action(plan)
      @completed_actions << { action: plan[:action], result: result }

      trigger(:action_completed)

      # Evaluate phase: check if player intent is satisfied
      if intent_satisfied?
        trigger(:intent_satisfied)
        break
      else
        trigger(:continue)
      end
    end

    # Transition to narrating if needed
    transition_to_narrating

    # Generate the narrative response
    @narrative = generate_narrative

    trigger(:finish)

    # Build and return result
    @result = build_dnd_result
    @result
  rescue StandardError => e
    handle_error(e)
  end

  protected

  # Use external memory store if provided, otherwise create one
  def create_memory_store
    @external_memory_store || MemoryStore.new(
      path: File.join(state_path, "memory.json"),
      sandbox_path: path
    )
  end

  # Initialize D&D-specific components
  def initialize_agent
    ensure_state_directory!
    @memory_store = create_memory_store

    # Set up goal context with player's intent
    @goal_context.set_primary_goal(
      goal,
      metadata: { type: :player_intent }
    )

    # Build initial DnD context
    @dnd_context = build_dnd_context

    record_decision(
      decision: "Starting D&D agent",
      rationale: "Player intent: #{goal}",
      context: { max_iterations: @max_iterations }
    )
  end

  # Build a DndChatContext from the memory store
  def build_dnd_context
    dnd_context = Contexts::DndChatContext.new

    # Populate from memory store
    populate_context_from_memory(dnd_context)

    dnd_context
  end

  # Populate DnD context from memory sections
  def populate_context_from_memory(dnd_context)
    # Scene
    scene_data = @memory_store.get_section(MemoryKinds::CURRENT_SCENE)
    if scene_data.present?
      scene_text = scene_data.is_a?(String) ? scene_data : scene_data.to_s
      dnd_context.scene.set_location(name: "Current Scene", description: scene_text)
    end

    # People
    people_data = @memory_store.get_section(MemoryKinds::PEOPLE) || []
    Array(people_data).each do |person|
      text = person.is_a?(Hash) ? (person[:text] || person["text"]) : person.to_s
      next if text.blank?
      dnd_context.add_person(name: "NPC", description: text)
    end

    # Quests
    quest_data = @memory_store.get_section(MemoryKinds::QUEST_LOG) || []
    Array(quest_data).each do |quest|
      text = quest.is_a?(Hash) ? (quest[:text] || quest["text"]) : quest.to_s
      status = quest.is_a?(Hash) ? (quest[:status] || quest["status"] || "active") : "active"
      next if text.blank?
      dnd_context.add_quest(title: text.truncate(50), description: text, status: status)
    end

    # Recent conversation
    conv_data = @memory_store.get_section(MemoryKinds::RECENT_CONVERSATION) || []
    Array(conv_data).last(5).each do |msg|
      text = msg.is_a?(Hash) ? (msg[:text] || msg["text"]) : msg.to_s
      speaker = msg.is_a?(Hash) ? (msg[:speaker] || msg["speaker"] || "unknown") : "unknown"
      next if text.blank?
      dnd_context.add_message(speaker: speaker, message: text)
    end
  end

  # Override to use D&D-specific planning prompt
  def plan_next_action
    prompt = DndPlanningPrompt.new(actions: available_actions)

    # Build tight context for planning
    context = build_dnd_planning_context

    result = prompt.execute(prompt: goal, context: context)
    plan = result[:content]

    record_decision(
      decision: "Planned action: #{plan[:action]}",
      rationale: plan[:rationale],
      context: { arguments: plan[:arguments] }
    )

    @current_plan = plan
    plan
  end

  # Build a tight planning context for D&D
  def build_dnd_planning_context
    context = Contexts::WorkflowContext.new

    # Add scene (most important for action selection)
    scene_summary = @dnd_context.scene.compressed_summary
    context.add(content: "Scene: #{scene_summary}", topics: ["scene"], source: "dnd") unless scene_summary.blank?

    # Add recent actions from this turn
    @completed_actions.last(3).each do |action_record|
      context.add(
        content: "Action: #{action_record[:action]} -> #{action_record[:result][:success] ? 'success' : 'failed'}",
        topics: ["action"],
        source: "agent"
      )
    end

    # Add player intent
    context.add(content: "Player says: #{goal}", topics: ["intent"], source: "player")

    context
  end

  # Check if the player's intent has been satisfied
  def intent_satisfied?
    return false if @completed_actions.empty?

    # For simple intents (single action), one successful action is enough
    return true if @completed_actions.size >= 1 && @completed_actions.last[:result][:success]

    # For complex intents, ask the LLM
    evaluate_intent_satisfaction
  end

  # Ask LLM if the intent is satisfied
  def evaluate_intent_satisfaction
    prompt = DndGoalPrompt.new
    context = build_dnd_evaluation_context

    result = prompt.execute(prompt: goal, context: context)
    result[:content][:intent_satisfied] == true
  end

  # Build context for intent evaluation
  def build_dnd_evaluation_context
    context = Contexts::WorkflowContext.new

    context.add(content: "Player intent: #{goal}", topics: ["intent"], source: "player")

    @completed_actions.each do |action_record|
      result_summary = action_record[:result][:summary] || action_record[:result][:result].to_s.truncate(100)
      context.add(
        content: "#{action_record[:action]}: #{result_summary}",
        topics: ["action", "result"],
        source: "agent"
      )
    end

    context
  end

  # Generate the narrative response
  def generate_narrative
    prompt = NarrativePrompt.new

    # Add completed actions to the DnD context
    @completed_actions.each do |action_record|
      @dnd_context.add_action(
        action_name: action_record[:action].to_s,
        result: action_record[:result][:result].to_s,
        metadata: action_record[:result]
      )
    end

    # Condense if needed
    context = if @dnd_context.all_entries.size > 20
      @dnd_context.condense(max_entries: 10)
    else
      @dnd_context
    end

    result = prompt.execute(prompt: goal, context: context)
    result[:content]
  end

  # Transition to narrating state from any valid state
  def transition_to_narrating
    case current_state
    when :evaluating
      trigger(:intent_satisfied)
    when :planning
      trigger(:action_selected)
      trigger(:action_completed)
      trigger(:intent_satisfied)
    when :narrating
      # Already there
    when :executing
      trigger(:action_completed)
      trigger(:intent_satisfied)
    end
  end

  # Build the final D&D result
  def build_dnd_result
    # Add assistant response to conversation
    @conversation << Message.new(source: "assistant", target: "user", message: @narrative)

    # Persist conversation through memory store
    persist_conversation

    {
      success: true,
      narrative: @narrative,
      actions: @completed_actions,
      goal: goal,
      conversation: @conversation,
      thoughts: nil,
      metadata: {
        iterations: @iteration_count,
        actions_executed: @action_count,
        started_at: @started_at.iso8601,
        completed_at: Time.now.utc.iso8601,
        final_state: current_state
      }
    }
  end

  # Persist conversation through the memory store
  def persist_conversation
    @memory_store.update_section(
      name: MemoryKinds::RECENT_CONVERSATION,
      content: @conversation.to_h,
      append: false
    )
  end

  # Override error handling for D&D-specific result format
  def handle_error(error)
    @error = error.message
    trigger(:fail) if can_trigger?(:fail)

    error_narrative = "The fates conspire against you... (#{error.message})"
    @conversation << Message.new(source: "assistant", target: "user", message: error_narrative)

    # Still persist conversation on error
    persist_conversation

    {
      success: false,
      narrative: error_narrative,
      error: error.message,
      actions: @completed_actions,
      goal: goal,
      conversation: @conversation,
      metadata: {
        iterations: @iteration_count,
        actions_executed: @action_count,
        completed_at: Time.now.utc.iso8601,
        final_state: current_state,
        error_class: error.class.name
      }
    }
  end
end

