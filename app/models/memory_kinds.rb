# frozen_string_literal: true

# Defines canonical memory section names for the DnD tools.
module MemoryKinds
  RECENT_CONVERSATION = "recent_conversation".freeze
  QUESTS = "quests".freeze
  MAIN_QUEST = "main_quest".freeze
  CURRENT_GOAL = "current_goal".freeze
  CURRENT_SCENE = "current_scene".freeze
  PEOPLE = "people".freeze
  MISC = "misc".freeze
  QUEST_LOG = "quest_log".freeze

  ALL = [
    RECENT_CONVERSATION,
    QUESTS,
    MAIN_QUEST,
    CURRENT_GOAL,
    CURRENT_SCENE,
    PEOPLE,
    MISC,
    QUEST_LOG
  ].freeze
end
