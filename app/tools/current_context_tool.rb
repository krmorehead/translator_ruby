# frozen_string_literal: true


# Read-only tool to fetch the current context for narration.
class CurrentContextTool < BaseTool
  NAME = "current_context".freeze

  def self.name_identifier
    NAME
  end

  def self.description
    "Returns current scene context: scene, people, current quest, and recent conversation."
  end

  def self.parameters_schema
    {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: "Memory file path (optional, defaults to agent data path)"
        }
      },
      required: [],
      additionalProperties: false
    }
  end

  def execute(path: nil)
    store = MemoryStore.new(path: path || default_file_path)

    success_result({
      scene: store.get_section(MemoryKinds::CURRENT_SCENE),
      people: store.get_section(MemoryKinds::PEOPLE),
      current_quest: store.get_section(MemoryKinds::CURRENT_GOAL) || store.get_section(MemoryKinds::MAIN_QUEST),
      recent_conversation: store.get_section(MemoryKinds::RECENT_CONVERSATION)
    })
  end
end
# Register with ToolCallService
ToolCallService.register_tool(CurrentContextTool)
