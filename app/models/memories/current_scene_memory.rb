# frozen_string_literal: true

module Memories
  class CurrentSceneMemory < BaseMemory
    SECTION = MemoryKinds::CURRENT_SCENE
    def self.section_name
      SECTION
    end

    def self.weight
      1.0
    end

    # Use CurrentSceneContext for scene-specific relevance filtering
    def self.context_class
      Contexts::CurrentSceneContext
    end
  end
end
