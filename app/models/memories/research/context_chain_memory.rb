# frozen_string_literal: true

module Memories
  module Research
    # Memory for maintaining reasoning chains across research iterations.
    # Enables the researcher to build on previous understanding without losing context.
    class ContextChainMemory < BaseResearchMemory
      SECTION = ResearchMemoryKinds::CONTEXT_CHAIN

      # Default token limit before compression
      DEFAULT_TOKEN_LIMIT = 8000

      def self.section_name
        SECTION
      end

      # Context chain is high priority for context preservation
      def self.weight
        0.95
      end

      # Add a context entry to the chain
      # @param store [ResearchMemoryStore] The memory store to update
      # @param options [Hash] Context entry options
      # @option options [Integer] :iteration Current iteration number
      # @option options [String] :sub_question The sub-question being addressed
      # @option options [String] :key_insights Key insights from this iteration
      # @option options [Array<String>] :files_examined Files examined in this context
      # @return [Hash] The created context entry
      def self.add_context(store:, **options)
        entry = {
          id: SecureRandom.uuid,
          iteration: options.fetch(:iteration, store.current_iteration),
          sub_question: options[:sub_question],
          key_insights: options[:key_insights],
          files_examined: options[:files_examined] || [],
          timestamp: Time.now.utc.iso8601
        }

        store.update_section(name: section_name, content: entry, append: true)
        entry
      end

      # Retrieve context chain for a specific sub-question
      # @param store [ResearchMemoryStore] The memory store to query
      # @param sub_question [String] The sub-question to filter by
      # @return [Array<Hash>] Relevant context entries
      def self.chain_for(store:, sub_question:)
        entries = store.get_section(section_name) || []
        entries.select do |entry|
          (entry[:sub_question] || entry["sub_question"]) == sub_question
        end
      end

      # Get the full context chain ordered by timestamp
      # @param store [ResearchMemoryStore] The memory store to query
      # @return [Array<Hash>] Context entries in chronological order
      def self.ordered_chain(store:)
        entries = store.get_section(section_name) || []
        entries.sort_by { |e| e[:timestamp] || e["timestamp"] || "" }
      end

      # Estimate token count for the context chain
      # @param store [ResearchMemoryStore] The memory store to query
      # @return [Integer] Estimated token count
      def self.estimate_tokens(store:)
        entries = store.get_section(section_name) || []
        # Rough estimate: 1 token per 4 characters
        total_chars = entries.sum do |entry|
          insights = entry[:key_insights] || entry["key_insights"] || ""
          question = entry[:sub_question] || entry["sub_question"] || ""
          insights.length + question.length
        end
        (total_chars / 4.0).ceil
      end

      # Check if compression is needed
      # @param store [ResearchMemoryStore] The memory store to query
      # @param limit [Integer] Token limit (default: DEFAULT_TOKEN_LIMIT)
      # @return [Boolean] True if compression is needed
      def self.needs_compression?(store:, limit: DEFAULT_TOKEN_LIMIT)
        estimate_tokens(store: store) > limit
      end

      # Compress older context entries to stay within token limit
      # @param store [ResearchMemoryStore] The memory store to update
      # @param limit [Integer] Token limit to target
      # @return [Array<Hash>] The compressed context chain
      def self.compress!(store:, limit: DEFAULT_TOKEN_LIMIT)
        entries = store.get_section(section_name) || []
        return entries unless needs_compression?(store: store, limit: limit)

        # Keep the most recent entries and summarize older ones
        recent_count = [entries.size / 2, 5].max
        recent = entries.last(recent_count)
        older = entries.first(entries.size - recent_count)

        # Create a summary entry for older context
        if older.any?
          combined_insights = older.map { |e| e[:key_insights] || e["key_insights"] }.compact.join("; ")
          summary_entry = {
            id: SecureRandom.uuid,
            iteration: 0,
            sub_question: "[Compressed historical context]",
            key_insights: combined_insights.truncate(1000),
            compressed: true,
            original_count: older.size,
            timestamp: older.first[:timestamp] || older.first["timestamp"]
          }
          compressed = [summary_entry] + recent
        else
          compressed = recent
        end

        store.set_section(section_name, compressed)
        compressed
      end

      # Summarize the context chain
      def self.summarize(store:)
        entries = store.get_section(section_name) || []
        questions = entries.map { |e| e[:sub_question] || e["sub_question"] }.compact.uniq

        {
          section: section_name,
          summary: "#{entries.size} context entries across #{questions.size} sub-questions",
          entry_count: entries.size,
          question_count: questions.size,
          estimated_tokens: estimate_tokens(store: store)
        }
      end
    end
  end
end

