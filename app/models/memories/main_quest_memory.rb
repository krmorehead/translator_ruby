# frozen_string_literal: true

module Memories
  # Memory for tracking the main quest objective.
  # Inherits goal tracking capabilities from GoalBasedMemory.
  class MainQuestMemory < GoalBasedMemory
    SECTION = MemoryKinds::MAIN_QUEST

    def self.section_name
      SECTION
    end

    # Main quest is highest priority
    def self.weight
      1.0
    end
  end
end
