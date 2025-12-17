# frozen_string_literal: true

module Memories
  module Research
    # Registry for all research memory classes.
    module Registry
      ALL = [
        ResearchGoalMemory,
        SubQuestionsMemory,
        DiscoveredFilesMemory,
        FindingsMemory,
        ContextChainMemory
      ].freeze

      BY_SECTION = ALL.each_with_object({}) do |klass, h|
        h[klass.section_name] = klass
      end.freeze

      def self.for(section)
        BY_SECTION[section.to_s]
      end

      def self.all
        ALL
      end
    end
  end
end

