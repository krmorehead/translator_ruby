# frozen_string_literal: true

module Actions
  # Action that retrieves information from memory
  class RecallMemoryAction < BaseAction
    def execute(query:, category: nil)
      section = category ? category_to_section(category) : nil
      
      if section
        data = memory_store.get_section(section)
        results = Array(data)
      else
        # Search all sections
        results = []
        memory_store.list_sections.each do |section_name|
          data = memory_store.get_section(section_name)
          results.concat(Array(data))
        end
      end
      
      # Filter by query
      query_words = query.downcase.split
      relevant = results.select do |item|
        text = item.is_a?(Hash) ? (item[:text] || item["text"] || item.to_s) : item.to_s
        query_words.any? { |word| text.downcase.include?(word) }
      end
      
      summary = "Found #{relevant.size} memories matching '#{query}'"
      success_result(relevant, summary: summary)
    end
    
    private
    
    def category_to_section(category)
      case category.to_s.downcase
      when "quest" then MemoryKinds::QUEST_LOG
      when "npc", "person" then MemoryKinds::PEOPLE
      when "location", "scene" then MemoryKinds::CURRENT_SCENE
      when "item" then MemoryKinds::INVENTORY
      else MemoryKinds::MISC
      end
    end
  end
end
