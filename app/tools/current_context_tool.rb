# frozen_string_literal: true


# Read-only tool to fetch the current context for narration.
class CurrentContextTool < BaseTool
  DEFAULT_FILENAME = "memory.json"
  PATH = File.join("tmp", "dnd_chat_sandbox", DEFAULT_FILENAME)
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
          description: "Optional memory file path (defaults to sandbox/memory.json)",
          nullable: true
        }
      },
      required: [],
      additionalProperties: false
    }
  end

  def execute(path: nil)
    store = MemoryStore.new(path: resolve_path(path), sandbox_path: sandbox_path)

    success_result({
      scene: store.get_section(MemoryKinds::CURRENT_SCENE),
      people: store.get_section(MemoryKinds::PEOPLE),
      current_quest: store.get_section(MemoryKinds::CURRENT_GOAL) || store.get_section(MemoryKinds::MAIN_QUEST),
      recent_conversation: store.get_section(MemoryKinds::RECENT_CONVERSATION)
    })
  rescue => e
    error_result("Context error: #{e.message}")
  end

  private

  def resolve_path(path)
    return path if path && !path.to_s.strip.empty? && File.absolute_path?(path)
    
    if sandbox_path
      File.join(sandbox_path, DEFAULT_FILENAME)
    else
      PATH
    end
  end
end
# Register with ToolCallService
ToolCallService.register_tool(CurrentContextTool)
