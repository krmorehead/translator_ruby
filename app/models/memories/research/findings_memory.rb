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
      # @return [Hash] The created finding entry
      def self.add_finding(store:, text:, **options)
        entry = {
          id: SecureRandom.uuid,
          text: text,
          sub_question_id: options[:sub_question_id],
          file_path: options[:file_path],
          confidence: options.fetch(:confidence, 0.8),
          pass_number: options[:pass_number],
          validated: false,
          created_at: Time.now.utc.iso8601,
          timestamp: Time.now.utc.iso8601
        }

        store.update_section(name: section_name, content: entry, append: true)
        entry
      end

      # Mark a finding as validated (confirmed across multiple passes)
      # @param store [ResearchMemoryStore] The memory store to update
      # @param id [String] Finding ID
      # @return [Hash, nil] The updated finding or nil if not found
      def self.validate_finding(store:, id:)
        entries = store.get_section(section_name) || []
        entry = entries.find { |e| (e[:id] || e["id"]) == id }
        return nil unless entry

        entry[:validated] = true
        entry[:validated_at] = Time.now.utc.iso8601
        store.set_section(section_name, entries)
        entry
      end

      # Get validated findings only
      # @param store [ResearchMemoryStore] The memory store to query
      # @return [Array<Hash>] Validated findings
      def self.validated(store:)
        entries = store.get_section(section_name) || []
        entries.select { |e| e[:validated] || e["validated"] }
      end

      # Get findings for a specific sub-question
      # @param store [ResearchMemoryStore] The memory store to query
      # @param sub_question_id [String] Sub-question ID
      # @return [Array<Hash>] Findings for the sub-question
      def self.for_question(store:, sub_question_id:)
        entries = store.get_section(section_name) || []
        entries.select { |e| (e[:sub_question_id] || e["sub_question_id"]) == sub_question_id }
      end

      # Group findings by pass number for cross-validation
      # @param store [ResearchMemoryStore] The memory store to query
      # @return [Hash<Integer, Array<Hash>>] Findings grouped by pass
      def self.by_pass(store:)
        entries = store.get_section(section_name) || []
        entries.group_by { |e| e[:pass_number] || e["pass_number"] || 1 }
      end

      # Summarize findings
      def self.summarize(store:)
        entries = store.get_section(section_name) || []
        validated = entries.count { |e| e[:validated] || e["validated"] }
        texts = entries.map { |e| e[:text] || e["text"] }.compact

        {
          section: section_name,
          summary: texts.take(3).join("; "),
          total_count: entries.size,
          validated_count: validated,
          pending_validation: entries.size - validated
        }
      end
    end
  end
end

