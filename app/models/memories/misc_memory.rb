# frozen_string_literal: true

module Memories
  class MiscMemory < BaseMemory
    SECTION = MemoryKinds::MISC
    def self.section_name
      SECTION
    end

    def self.weight
      0.5
    end
  end
end
