# frozen_string_literal: true

module Memories
  # Memory for tracking active side quests.
  # Inherits goal tracking capabilities from GoalBasedMemory.
  class QuestsMemory < GoalBasedMemory
    SECTION = MemoryKinds::QUESTS

    def self.section_name
      SECTION
    end

    # Quests are highest priority
    def self.weight
      1.0
    end
  end
end
