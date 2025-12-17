# frozen_string_literal: true

module Memories
  # Abstract base class for goal/quest-like memories.
  # Provides common structure for tracking objectives and their completion states.
  # Used by both D&D memories (CurrentGoal, MainQuest, Quests) and research memories.
  class GoalBasedMemory < BaseMemory
    # Goal status constants
    STATUS_PENDING = "pending"
    STATUS_ACTIVE = "active"
    STATUS_COMPLETE = "complete"
    STATUS_FAILED = "failed"

    VALID_STATUSES = [STATUS_PENDING, STATUS_ACTIVE, STATUS_COMPLETE, STATUS_FAILED].freeze

    # Default weight for goal-based memories (high priority for context)
    def self.weight
      0.9
    end

    # Get all active goals from the store
    # @param store [MemoryStore] The memory store to query
    # @return [Array<Hash>] Active goal entries
    def self.active_goals(store:)
      entries = store.get_section(section_name) || []
      Array(entries).select do |entry|
        status = entry[:status] || entry["status"]
        status == STATUS_ACTIVE
      end
    end

    # Get all pending goals from the store
    # @param store [MemoryStore] The memory store to query
    # @return [Array<Hash>] Pending goal entries
    def self.pending_goals(store:)
      entries = store.get_section(section_name) || []
      Array(entries).select do |entry|
        status = entry[:status] || entry["status"]
        status == STATUS_PENDING
      end
    end

    # Mark a goal as complete by its ID or index
    # @param store [MemoryStore] The memory store to update
    # @param id [String, Integer] Goal ID or index
    # @return [Hash, nil] The updated goal or nil if not found
    def self.complete_goal(store:, id:)
      entries = store.get_section(section_name) || []
      goal = find_goal(entries, id)
      return nil unless goal

      goal[:status] = STATUS_COMPLETE
      goal[:completed_at] = Time.now.utc.iso8601
      store.set_section(section_name, entries)
      goal
    end

    # Activate a pending goal
    # @param store [MemoryStore] The memory store to update
    # @param id [String, Integer] Goal ID or index
    # @return [Hash, nil] The updated goal or nil if not found
    def self.activate_goal(store:, id:)
      entries = store.get_section(section_name) || []
      goal = find_goal(entries, id)
      return nil unless goal

      goal[:status] = STATUS_ACTIVE
      goal[:activated_at] = Time.now.utc.iso8601
      store.set_section(section_name, entries)
      goal
    end

    # Create a normalized goal entry with proper structure
    # @param content [String, Hash] Goal content
    # @param priority [Integer] Goal priority (1 = highest)
    # @param status [String] Initial status (default: pending)
    # @return [Hash] Normalized goal entry
    def self.create_goal_entry(content:, priority: 1, status: STATUS_PENDING)
      text = content.is_a?(Hash) ? content[:text] || content["text"] : content

      {
        id: SecureRandom.uuid,
        text: text,
        priority: priority,
        status: status,
        created_at: Time.now.utc.iso8601,
        timestamp: Time.now.utc.iso8601
      }
    end

    # Summarize goals grouped by status
    # @param store [MemoryStore] The memory store to summarize
    # @return [Hash] Summary with section name and goal counts by status
    def self.summarize(store:)
      entries = store.get_section(section_name) || []

      by_status = entries.group_by { |e| e[:status] || e["status"] || STATUS_PENDING }

      active = by_status[STATUS_ACTIVE] || []
      pending = by_status[STATUS_PENDING] || []
      complete = by_status[STATUS_COMPLETE] || []

      active_texts = active.map { |e| e[:text] || e["text"] }.compact
      pending_texts = pending.map { |e| e[:text] || e["text"] }.compact

      {
        section: section_name,
        summary: "Active: #{active_texts.join('; ')}. Pending: #{pending_texts.join('; ')}",
        active_count: active.size,
        pending_count: pending.size,
        complete_count: complete.size,
        total_count: entries.size
      }
    end

    private_class_method def self.find_goal(entries, id)
      if id.is_a?(Integer)
        entries[id]
      else
        entries.find { |e| (e[:id] || e["id"]) == id }
      end
    end
  end
end

