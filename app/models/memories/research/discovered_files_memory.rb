# frozen_string_literal: true

module Memories
  module Research
    # Memory for tracking files discovered during research.
    class DiscoveredFilesMemory < BaseResearchMemory
      SECTION = ResearchMemoryKinds::DISCOVERED_FILES

      def self.section_name
        SECTION
      end

      # Files are medium priority
      def self.weight
        0.7
      end

      # Add a discovered file with relevance information
      # @param store [ResearchMemoryStore] The memory store to update
      # @param path [String] File path
      # @param options [Hash] Additional options (relevance_score, sub_question_id, reasoning)
      # @return [Hash] The created file entry
      def self.add_file(store:, path:, **options)
        entry = {
          id: SecureRandom.uuid,
          path: path,
          relevance_score: options.fetch(:relevance_score, 0.5),
          sub_question_id: options[:sub_question_id],
          reasoning: options[:reasoning],
          analyzed: false,
          discovered_at: Time.now.utc.iso8601,
          timestamp: Time.now.utc.iso8601
        }

        store.update_section(name: section_name, content: entry, append: true)
        entry
      end

      # Mark a file as analyzed
      # @param store [ResearchMemoryStore] The memory store to update
      # @param path [String] File path to mark
      # @return [Hash, nil] The updated entry or nil if not found
      def self.mark_analyzed(store:, path:)
        entries = store.get_section(section_name) || []
        entry = entries.find { |e| (e[:path] || e["path"]) == path }
        return nil unless entry

        entry[:analyzed] = true
        entry[:analyzed_at] = Time.now.utc.iso8601
        store.set_section(section_name, entries)
        entry
      end

      # Get files ordered by relevance score
      # @param store [ResearchMemoryStore] The memory store to query
      # @param limit [Integer] Maximum number of files to return
      # @return [Array<Hash>] Files sorted by relevance (highest first)
      def self.by_relevance(store:, limit: nil)
        entries = store.get_section(section_name) || []
        sorted = entries.sort_by { |e| -(e[:relevance_score] || e["relevance_score"] || 0) }
        limit ? sorted.take(limit) : sorted
      end

      # Get files for a specific sub-question
      # @param store [ResearchMemoryStore] The memory store to query
      # @param sub_question_id [String] Sub-question ID
      # @return [Array<Hash>] Files associated with the sub-question
      def self.for_question(store:, sub_question_id:)
        entries = store.get_section(section_name) || []
        entries.select { |e| (e[:sub_question_id] || e["sub_question_id"]) == sub_question_id }
      end

      # Summarize discovered files
      def self.summarize(store:)
        entries = store.get_section(section_name) || []
        analyzed = entries.count { |e| e[:analyzed] || e["analyzed"] }
        paths = entries.map { |e| e[:path] || e["path"] }.compact

        {
          section: section_name,
          summary: "Discovered #{entries.size} files (#{analyzed} analyzed): #{paths.first(5).join(', ')}",
          total_count: entries.size,
          analyzed_count: analyzed,
          pending_count: entries.size - analyzed
        }
      end
    end
  end
end

