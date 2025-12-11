# frozen_string_literal: true


module Memories
  class ActionsMemory < BaseMemory
    def self.section_name
      MemoryKinds::ACTIONS
    end

    def self.default
      []
    end

    def self.weight
      1.0
    end
  end
end
