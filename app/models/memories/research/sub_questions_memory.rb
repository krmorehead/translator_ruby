# frozen_string_literal: true

module Memories
  module Research
    # Memory for tracking decomposed research sub-questions.
    # Inherits goal tracking capabilities from GoalBasedMemory.
    class SubQuestionsMemory < Memories::GoalBasedMemory
      SECTION = ResearchMemoryKinds::SUB_QUESTIONS

      def self.section_name
        SECTION
      end

      # Sub-questions are high priority
      def self.weight
        0.9
      end

      # Get leaf questions (those marked as no further decomposition needed)
      # @param store [ResearchMemoryStore] The memory store to query
      # @return [Array<Hash>] Leaf question entries
      def self.leaf_questions(store:)
        entries = store.get_section(section_name) || []
        Array(entries).select do |entry|
          entry[:is_leaf] || entry["is_leaf"]
        end
      end

      # Get questions by parent ID (for tree reconstruction)
      # @param store [ResearchMemoryStore] The memory store to query
      # @param parent_id [String, nil] Parent question ID (nil for root)
      # @return [Array<Hash>] Child question entries
      def self.children_of(store:, parent_id:)
        entries = store.get_section(section_name) || []
        Array(entries).select do |entry|
          (entry[:parent_id] || entry["parent_id"]) == parent_id
        end
      end

      # Add a sub-question with proper structure
      # @param store [ResearchMemoryStore] The memory store to update
      # @param question [String] The question text
      # @param options [Hash] Additional options (priority, is_leaf, parent_id, rationale)
      # @return [Hash] The created question entry
      def self.add_question(store:, question:, **options)
        entry = {
          id: SecureRandom.uuid,
          text: question,
          priority: options.fetch(:priority, 1),
          is_leaf: options.fetch(:is_leaf, false),
          parent_id: options[:parent_id],
          rationale: options[:rationale],
          status: Memories::GoalBasedMemory::STATUS_PENDING,
          created_at: Time.now.utc.iso8601,
          timestamp: Time.now.utc.iso8601
        }

        store.update_section(name: section_name, content: entry, append: true)
        entry
      end
    end
  end
end

