# frozen_string_literal: true

require_relative "base_memory"
require_relative "recent_conversation_memory"
require_relative "quests_memory"
require_relative "main_quest_memory"
require_relative "current_goal_memory"
require_relative "current_scene_memory"
require_relative "people_memory"
require_relative "misc_memory"
require_relative "quest_log_memory"

module Memories
  module Registry
    ALL = [
      RecentConversationMemory,
      QuestsMemory,
      MainQuestMemory,
      CurrentGoalMemory,
      CurrentSceneMemory,
      PeopleMemory,
      MiscMemory,
      QuestLogMemory
    ].freeze

    BY_SECTION = ALL.each_with_object({}) do |klass, h|
      h[klass.section_name] = klass
    end.freeze

    def self.for(section)
      BY_SECTION[section.to_s]
    end
  end
end
