# frozen_string_literal: true

module Memories
  class MainQuestMemory < BaseMemory
    SECTION = MemoryKinds::MAIN_QUEST
    def self.section_name = SECTION
  end
end
