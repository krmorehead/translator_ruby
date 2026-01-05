# frozen_string_literal: true

module Memories
  module Research
    # Memory for storing research findings and analysis results.
    class FindingsMemory < BaseResearchMemory
      SECTION = ResearchMemoryKinds::FINDINGS

      def self.section_name
        SECTION
      end

      # Findings are high priority
      def self.weight
        0.8
      end

      # Add a research finding
      # @param store [ResearchMemoryStore] The memory store to update
      # @param text [String] The finding text
      # @param options [Hash] Additional options (sub_question_id, file_path, confidence, pass_number)
      # @return [WorkflowMemories::Finding] The created finding object
      def self.add_finding(store:, text:, **options)
        finding = WorkflowMemories::Finding.new(
          text: text,
          file_path: options.fetch(:file_path),
          confidence: options.fetch(:confidence, 0.8),
          pass_number: options.fetch(:pass_number, 1),
          sub_question_id: options[:sub_question_id],
          relevance: options[:relevance]
        )

        store.update_section(name: section_name, content: finding, append: true)
        finding
      end

      # Mark a finding as validated (confirmed across multiple passes)
      # @param store [ResearchMemoryStore] The memory store to update
      # @param id [String] Finding ID
      # @return [WorkflowMemories::Finding, nil] The finding or nil if not found
      def self.validate_finding(store:, id:)
        entries = store.get_section(section_name) || []
        finding = entries.find { |f| f.id == id }
        return nil unless finding

        # Findings are immutable - would need to create a new one with validated flag
        # For now, just return the finding
        finding
      end

      # Get validated findings only
      # @param store [ResearchMemoryStore] The memory store to query
      # @return [Array<WorkflowMemories::Finding>] All findings (validation tracking removed for now)
      def self.validated(store:)
        entries = store.get_section(section_name) || []
        entries
      end

      # Get findings for a specific sub-question
      # @param store [ResearchMemoryStore] The memory store to query
      # @param sub_question_id [String] Sub-question ID
      # @return [Array<WorkflowMemories::Finding>] Findings for the sub-question
      def self.for_question(store:, sub_question_id:)
        entries = store.get_section(section_name) || []
        entries.select { |f| f.sub_question_id == sub_question_id }
      end

      # Group findings by pass number for cross-validation
      # @param store [ResearchMemoryStore] The memory store to query
      # @return [Hash<Integer, Array<WorkflowMemories::Finding>>] Findings grouped by pass
      def self.by_pass(store:)
        entries = store.get_section(section_name) || []
        entries.group_by(&:pass_number)
      end

      # Summarize findings
      def self.summarize(store:)
        entries = store.get_section(section_name) || []
        texts = entries.map(&:text)

        {
          section: section_name,
          summary: texts.take(3).join("; "),
          total_count: entries.size,
          validated_count: entries.size,  # All findings are considered validated now
          pending_validation: 0
        }
      end
    end
  end
end

