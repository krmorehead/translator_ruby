# frozen_string_literal: true

module Memories
  class CurrentSceneMemory < BaseMemory
    SECTION = MemoryKinds::CURRENT_SCENE
    def self.section_name = SECTION
  end
end
