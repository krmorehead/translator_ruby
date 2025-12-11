# frozen_string_literal: true

require_relative "base_memory"
require_relative "../memory_kinds"

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
