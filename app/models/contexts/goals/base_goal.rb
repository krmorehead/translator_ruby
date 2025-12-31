module Contexts
  module Goals
    class BaseGoal
      STATUSES = [
        NOT_STARTED = :not_started,
        IN_PROGRESS = :in_progress,
        COMPLETE = :complete,
        FAILED = :failed,
      ].freeze

      attr_reader :id, :goal_text, :status, :entries, :progress, :created_at, :updated_at, :metadata

      def initialize(goal_text:, entry_id:, status: NOT_STARTED, metadata: {})
        raise ArgumentError, "goal_text must be a String" unless goal_text.is_a?(String)
        raise ArgumentError, "entry_id must be a String" unless entry_id.is_a?(String)
        raise ArgumentError, "Invalid status: #{status}" unless STATUSES.include?(status)

        @id = SecureRandom.uuid
        @goal_text = goal_text
        @status = status
        @entries = [entry_id]
        @progress = 0
        @created_at = Time.now.utc.iso8601
        @updated_at = Time.now.utc.iso8601
        @metadata = metadata
      end

      def update_status(status:, entry_id:, progress: nil)
        raise ArgumentError, "Invalid status: #{status}" unless STATUSES.include?(status)
        raise ArgumentError, "entry_id must be a String" unless entry_id.is_a?(String)
        
        @progress = progress unless progress.nil?
        @entries << entry_id
        @status = status
        @updated_at = Time.now.utc.iso8601
      end

      def completed?
        @status == COMPLETE
      end

      def to_h
        {
          id: @id,
          goal_text: @goal_text,
          status: @status,
          progress: @progress,
          entries: @entries,
          created_at: @created_at,
          updated_at: @updated_at,
          metadata: @metadata
        }
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required keys" unless 
          hash.key?(:id) && hash.key?(:goal_text) && hash.key?(:status) && hash.key?(:entries)

        goal = allocate
        goal.instance_variable_set(:@id, hash[:id])
        goal.instance_variable_set(:@goal_text, hash[:goal_text])
        goal.instance_variable_set(:@status, hash[:status])
        goal.instance_variable_set(:@entries, hash[:entries])
        goal.instance_variable_set(:@progress, hash[:progress] || 0)
        goal.instance_variable_set(:@created_at, hash[:created_at])
        goal.instance_variable_set(:@updated_at, hash[:updated_at])
        goal.instance_variable_set(:@metadata, hash[:metadata] || {})
        goal
      end
    end
  end
end
