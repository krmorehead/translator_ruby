# frozen_string_literal: true

module Memories
  # Memory for tracking the player's current immediate goal.
  # Inherits goal tracking capabilities from GoalBasedMemory.
  class CurrentGoalMemory < GoalBasedMemory
    SECTION = MemoryKinds::CURRENT_GOAL

    def self.section_name
      SECTION
    end

    # Current goal is highest priority
    def self.weight
      1.0
    end
  end
end
