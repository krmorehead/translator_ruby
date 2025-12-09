# frozen_string_literal: true

module Memories
  class CurrentGoalMemory < BaseMemory
    SECTION = MemoryKinds::CURRENT_GOAL
    def self.section_name = SECTION
  end
end
