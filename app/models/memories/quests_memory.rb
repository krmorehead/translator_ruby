# frozen_string_literal: true

module Memories
  class QuestsMemory < BaseMemory
    SECTION = MemoryKinds::QUESTS
    def self.section_name = SECTION
  end
end
