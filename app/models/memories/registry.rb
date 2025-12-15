# frozen_string_literal: true

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
      QuestLogMemory,
      ActionsMemory,
      TrainingData::ModelInteractionMemory
    ].freeze

    BY_SECTION = ALL.each_with_object({}) do |klass, h|
      h[klass.section_name] = klass
    end.freeze

    def self.for(section)
      BY_SECTION[section.to_s]
    end
  end
end
