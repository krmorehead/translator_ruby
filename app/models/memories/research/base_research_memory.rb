# frozen_string_literal: true

module Memories
  module Research
    # Base class for research-specific memories.
    # Provides common functionality for research memory sections.
    class BaseResearchMemory < Memories::BaseMemory
      # Default weight for research memories
      def self.weight
        0.7
      end

      # Research memories use the research memory kinds namespace
      def self.memory_namespace
        ResearchMemoryKinds
      end
    end
  end
end

