# frozen_string_literal: true

# Workflow orchestrating DnD chat: detect actions, run tools, resolve consequences, narrate.
class DndChatWorkflow < BaseWorkflow
  DEFAULT_SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a DnD assistant with access to tools (memory, inventory, dice, skill checks, etc.).
    Respond by selecting appropriate tools and narrating outcomes in a story-focused way.
  PROMPT

  def self.workflow_name
    "dnd_chat"
  end

  def initialize(tool_call_service: nil, memory_store_class: MemoryStore)
    super()
    @tool_call_service = tool_call_service
    @memory_store_class = memory_store_class
  end

  # Temporary compatibility for controller/tests until controller is refactored to orchestrator path.
  # Builds OpenAI chat parameters for tool selection.
  def chat_parameters(user_prompt:, model: nil, extra_system_prompt: nil, tools: ToolCallService.available_dnd_tools)
    tool_names = tools.map { |t| t[:function][:name] }
    
    params = {
      model: model || BasePrompt.new.model,
      messages: [
        { role: "system", content: system_prompt(extra_system_prompt) },
        { role: "user", content: user_prompt }
      ]
    }
    
    # Only add response_format if we have tools
    # vLLM rejects schemas with empty enums
    if tool_names.any?
      params[:response_format] = {
        type: "json_schema",
        json_schema: {
          name: "tool_call",
          strict: true,
          schema: {
            type: "object",
            properties: {
              tool: { type: "string", enum: tool_names },
              arguments: { type: "object", additionalProperties: true }
            },
            required: %w[tool arguments],
            additionalProperties: false
          }
        }
      }
    end
    
    params
  end

  # Orchestrates the full workflow; marks complete or failed accordingly.
  def execute
    trigger(:start) # Move to running state
    state = WorkflowState.new(status: WorkflowState::STATUSES[:running], prompt: prompt)

    memory_store = build_memory_store
    tools = available_dnd_tools

    detected_actions = detect_actions(tools: tools, memory_store: memory_store)
    action_records = detected_actions.map do |action|
      ActionRecord.new(
        prompt_reference: action[:prompt_reference],
        tool_name: action[:tool_name],
        arguments: action[:arguments] || {}
      )
    end

    completed_actions = process_actions(action_records, memory_store)

    narrative = generate_narrative(completed_actions, memory_store)
    assistant_message = Message.new(source: "assistant", target: "user", message: narrative)
    conversation << assistant_message if conversation

    result_hash = {
      narrative: narrative,
      actions: completed_actions.map(&:to_h),
      conversation: conversation,
      thoughts: @latest_thoughts
    }

    mark_complete(result_hash)
    state = state.with(status: WorkflowState::STATUSES[:complete], data: result_hash)
    state
  rescue => e
    mark_failed(e.message)
    state = state&.with(status: WorkflowState::STATUSES[:failed], error: e.message) || WorkflowState.new(status: WorkflowState::STATUSES[:failed], error: e.message)
    state
  end

  private

  def build_memory_store
    path = File.join(sandbox_path || Dir.mktmpdir, "memory.json")
    @memory_store_class.new(path: path, sandbox_path: sandbox_path)
  end

  # Build a DndChatContext from the memory store
  # @param memory_store [MemoryStore] The memory store
  # @return [Contexts::DndChatContext] Populated DnD context
  def build_dnd_context(memory_store)
    dnd_context = Contexts::DndChatContext.new

    # Populate scene context
    scene_data = memory_store.get_section(MemoryKinds::CURRENT_SCENE)
    if scene_data.present?
      scene_text = scene_data.is_a?(String) ? scene_data : scene_data.to_s
      dnd_context.scene.set_location(name: "Current Scene", description: scene_text)
    end

    # Populate people context
    people_data = memory_store.get_section(MemoryKinds::PEOPLE) || []
    Array(people_data).each do |person|
      text = person.is_a?(Hash) ? (person[:text] || person["text"]) : person.to_s
      next if text.blank?

      dnd_context.add_person(name: "NPC", description: text)
    end

    # Populate quests context
    quest_data = memory_store.get_section(MemoryKinds::QUEST_LOG) || []
    Array(quest_data).each do |quest|
      text = quest.is_a?(Hash) ? (quest[:text] || quest["text"]) : quest.to_s
      status = quest.is_a?(Hash) ? (quest[:status] || quest["status"] || "active") : "active"
      next if text.blank?

      dnd_context.add_quest(title: text.truncate(50), description: text, status: status)
    end

    # Populate conversation context
    conv_data = memory_store.get_section(MemoryKinds::RECENT_CONVERSATION) || []
    Array(conv_data).each do |msg|
      text = msg.is_a?(Hash) ? (msg[:text] || msg["text"]) : msg.to_s
      speaker = msg.is_a?(Hash) ? (msg[:speaker] || msg["speaker"] || "unknown") : "unknown"
      next if text.blank?

      dnd_context.add_message(speaker: speaker, message: text)
    end

    # Populate actions context
    actions_data = memory_store.get_section(MemoryKinds::ACTIONS) || []
    Array(actions_data).each do |action|
      next unless action.is_a?(Hash)

      action_name = action[:tool_name] || action["tool_name"] || "action"
      result = action[:result] || action["result"] || ""
      dnd_context.add_action(action_name: action_name, result: result.to_s, metadata: action)
    end

    dnd_context
  end

  def available_dnd_tools
    ToolCallService.available_dnd_tools
  end

  def detect_actions(tools:, memory_store:)
    prompt = ActionDetectionPrompt.new(tools: tools)

    # Build DndChatContext for action detection
    dnd_context = build_dnd_context(memory_store)

    result = prompt.execute(prompt: self.prompt, context: dnd_context)
    result[:content]
  end

  def process_actions(action_records, memory_store)
    service = @tool_call_service || ToolCallService.new(sandbox_path: sandbox_path)
    completed = []

    action_records.each do |record|
      result = service.execute(tool_name: record.tool_name, arguments: record.arguments)
      record = if result[:success]
        record.with(status: :executed, result: result[:result])
      else
        record.with(status: :failed, error: result[:error])
      end

      consequence_text = resolve_consequence(record, result, memory_store)
      record = record.with(consequence: consequence_text) if consequence_text

      memory_store.update_section(name: MemoryKinds::ACTIONS, content: record.to_h, append: true)
      completed << record
    end

    completed
  end

  def resolve_consequence(action_record, tool_result, memory_store)
    prompt = OutcomePrompt.new

    # Build a focused context for consequence resolution
    dnd_context = build_dnd_context(memory_store)
    dnd_context.add_action(
      action_name: action_record.tool_name,
      result: tool_result[:result].to_s,
      metadata: { action: action_record.to_h, tool_result: tool_result }
    )

    response = prompt.execute(prompt: self.prompt, context: dnd_context)
    content = response[:content]
    content.is_a?(Hash) ? content[:consequence] : nil
  end

  def generate_narrative(completed_actions, memory_store)
    prompt = NarrativePrompt.new

    # Build DndChatContext for narrative generation
    dnd_context = build_dnd_context(memory_store)

    # Add completed actions to the context
    completed_actions.each do |action|
      dnd_context.add_action(
        action_name: action.tool_name,
        result: action.result.to_s,
        metadata: action.to_h
      )
    end

    # Use condense if context is too large
    context = if exceeds_context_limit_for_context?(dnd_context)
      dnd_context.condense(max_entries: 10)
    else
      dnd_context
    end

    result = prompt.execute(prompt: self.prompt, context: context)
    @latest_thoughts = result[:thoughts]
    result[:content]
  end

  # Check if a DndChatContext exceeds the token limit
  def exceeds_context_limit_for_context?(context)
    # Estimate by counting all entries
    total_entries = context.all_entries.size
    total_entries > 20  # Simple heuristic
  end

  # Legacy method for hash-based context - kept for compatibility
  def exceeds_context_limit?(context)
    return false unless context.is_a?(Hash)

    approx_tokens = JSON.generate(context).size / 4.0
    approx_tokens > NarrativePrompt::CONTEXT_TOKEN_MAX
  end

  def system_prompt(extra)
    return DEFAULT_SYSTEM_PROMPT unless extra&.strip&.length&.positive?

    "#{DEFAULT_SYSTEM_PROMPT}\n\n#{extra}".strip
  end
end
