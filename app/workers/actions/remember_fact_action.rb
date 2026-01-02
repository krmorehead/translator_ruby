# frozen_string_literal: true

module Actions
  # Action that stores facts in memory
  class RememberFactAction < BaseAction
    def execute(fact:, category: "misc")
      section = category_to_section(category)
      
      memory_store.update_section(
        name: section,
        content: { text: fact, timestamp: Time.now.utc.iso8601 },
        append: true
      )
      
      success_result(
        { fact: fact, category: category },
        summary: "Remembered: #{fact}"
      )
    end
    
    private
    
    def category_to_section(category)
      case category.to_s.downcase
      when "quest" then MemoryKinds::QUEST_LOG
      when "npc", "person" then MemoryKinds::PEOPLE
      when "location" then MemoryKinds::CURRENT_SCENE
      when "item" then MemoryKinds::INVENTORY
      else MemoryKinds::MISC
      end
    end
  end
end
