# frozen_string_literal: true

module Actions
  # Action that updates quest status or adds new quests
  class AdvanceQuestAction < BaseAction
    def execute(quest_name:, status:, notes: nil)
      quest_data = {
        title: quest_name,
        status: status,
        notes: notes,
        updated_at: Time.now.utc.iso8601
      }
      
      # Get existing quests
      quests = memory_store.get_section(MemoryKinds::QUEST_LOG) || []
      
      # Find and update existing quest or add new one
      existing_index = quests.find_index do |q|
        q.is_a?(Hash) && (q[:title] == quest_name || q["title"] == quest_name)
      end
      
      if existing_index
        quests[existing_index] = quest_data
        summary = "Updated quest '#{quest_name}' to #{status}"
      else
        quests << quest_data
        summary = "Added new quest '#{quest_name}' with status #{status}"
      end
      
      memory_store.set_section(MemoryKinds::QUEST_LOG, quests)
      
      success_result(quest_data, summary: summary)
    end
  end
end
