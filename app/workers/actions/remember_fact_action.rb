# frozen_string_literal: true

module Actions
  # Action to store a fact or event in the campaign memory.
  # Wraps the memory tool for the agentic workflow.
  class RememberFactAction < BaseAction
    def execute(fact:, category: "general")
      memory_store.update_section(
        name: category_to_section(category),
        content: { text: fact, timestamp: Time.now.utc.iso8601 },
        append: true
      )

      success_result(
        result: "Remembered: #{fact.truncate(50)}",
        summary: "Stored fact in #{category} memory"
      )
    end

    private

    def category_to_section(category)
      case category.to_s.downcase
      when "quest" then MemoryKinds::QUEST_LOG
      when "npc", "person" then MemoryKinds::PEOPLE
      when "location", "scene" then MemoryKinds::CURRENT_SCENE
      when "item", "inventory" then MemoryKinds::INVENTORY
      else MemoryKinds::GENERAL_KNOWLEDGE
      end
    end
  end
end

