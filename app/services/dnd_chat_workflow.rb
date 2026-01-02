# frozen_string_literal: true

# Workflow that performs DnD chat actions.
# Detects actions from user prompts, executes tools, and generates narrative.
#
# State Flow:
#   pending → running → complete
class DndChatWorkflow < BaseWorkflow
  DEFAULT_SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a DnD assistant with access to tools (memory, inventory, dice, skill checks, etc.).
    Respond by selecting appropriate tools and narrating outcomes in a story-focused way.
  PROMPT

  def self.workflow_name
    "dnd_chat"
  end

  # Workflow performs the deterministic work
  def execute
    trigger(:start)
    
    # Use prompts to detect actions, execute tools, generate narrative
    detected_actions = detect_actions_from_prompt
    action_results = execute_actions(detected_actions)
    narrative = generate_narrative(action_results)
    
    result = {
      narrative: narrative,
      actions: action_results,
      conversation: conversation
    }
    
    mark_complete(result)
    result
  rescue => e
    mark_failed(e.message)
    raise
  end
  
  private
  
  def detect_actions_from_prompt
    # Use ActionDetectionPrompt to identify what tools to use
    tools = ToolCallService.available_dnd_tools
    detection_prompt = ActionDetectionPrompt.new(tools: tools)
    context = build_context_for_detection
    
    result = detection_prompt.execute(prompt: prompt, context: context)
    # ActionDetectionPrompt returns array of actions directly
    result[:content] || []
  end
  
  def execute_actions(actions)
    return [] if actions.empty?
    
    tool_service = ToolCallService.new
    actions.map do |action|
      tool_service.execute(tool_name: action[:tool_name], arguments: action[:arguments])
    end
  end
  
  def generate_narrative(action_results)
    narrative_prompt = NarrativePrompt.new
    context = build_context_for_narrative(action_results)
    
    result = narrative_prompt.execute(prompt: prompt, context: context)
    result[:content]
  end
  
  def build_context_for_detection
    # Build DndChatContext from parent memory
    dnd_context = Contexts::DndChatContext.new
    populate_context_from_memory(dnd_context)
    dnd_context
  end
  
  def build_context_for_narrative(action_results)
    dnd_context = build_context_for_detection
    
    # Add completed actions
    action_results.each do |result|
      dnd_context.add_action(
        action_name: result[:tool] || "action",
        result: result[:result].to_s,
        metadata: result
      )
    end
    
    dnd_context
  end
  
  def populate_context_from_memory(dnd_context)
    return unless parent_memory
    
    # Scene
    scene_data = parent_memory.get_section(MemoryKinds::CURRENT_SCENE)
    if scene_data.present?
      scene_text = scene_data.is_a?(String) ? scene_data : scene_data.to_s
      dnd_context.scene.set_location(name: "Current Scene", description: scene_text)
    end
    
    # People
    people_data = parent_memory.get_section(MemoryKinds::PEOPLE) || []
    Array(people_data).each do |person|
      text = person.is_a?(Hash) ? (person[:text] || person["text"]) : person.to_s
      next if text.blank?
      dnd_context.add_person(name: "NPC", description: text)
    end
    
    # Quests
    quest_data = parent_memory.get_section(MemoryKinds::QUEST_LOG) || []
    Array(quest_data).each do |quest|
      text = quest.is_a?(Hash) ? (quest[:text] || quest["text"]) : quest.to_s
      status = quest.is_a?(Hash) ? (quest[:status] || quest["status"] || "active") : "active"
      next if text.blank?
      dnd_context.add_quest(title: text.truncate(50), description: text, status: status)
    end
    
    # Recent conversation
    conv_data = parent_memory.get_section(MemoryKinds::RECENT_CONVERSATION) || []
    Array(conv_data).last(5).each do |msg|
      text = msg.is_a?(Hash) ? (msg[:text] || msg["text"]) : msg.to_s
      speaker = msg.is_a?(Hash) ? (msg[:speaker] || msg["speaker"] || "unknown") : "unknown"
      next if text.blank?
      dnd_context.add_message(speaker: speaker, message: text)
    end
  end

end
