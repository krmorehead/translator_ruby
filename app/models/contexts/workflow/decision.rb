# frozen_string_literal: true

module Contexts
  module Workflow
    # Represents a decision made during workflow execution.
    # Tracks the decision, rationale, and context that informed it.
    class Decision
      attr_reader :id, :decision, :rationale, :decision_context, :state_at_decision, :timestamp

      def initialize(decision:, rationale:, context: {}, state_at_decision:)
        raise ArgumentError, "decision must be a String" unless decision.is_a?(String)
        raise ArgumentError, "rationale must be a String" unless rationale.is_a?(String)
        raise TypeError, "context must be a Hash" unless context.is_a?(Hash)
        raise ArgumentError, "state_at_decision must be a Symbol" unless state_at_decision.is_a?(Symbol)

        @id = SecureRandom.uuid
        @decision = decision
        @rationale = rationale
        @decision_context = context
        @state_at_decision = state_at_decision
        @timestamp = Time.now.utc.iso8601
      end

      def to_h
        {
          id: @id,
          decision: @decision,
          rationale: @rationale,
          decision_context: @decision_context,
          state_at_decision: @state_at_decision,
          timestamp: @timestamp
        }
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required keys" unless
          hash.key?(:id) && hash.key?(:decision) && hash.key?(:rationale) && hash.key?(:state_at_decision)

        decision = allocate
        decision.instance_variable_set(:@id, hash[:id])
        decision.instance_variable_set(:@decision, hash[:decision])
        decision.instance_variable_set(:@rationale, hash[:rationale])
        decision.instance_variable_set(:@decision_context, hash[:decision_context] || {})
        decision.instance_variable_set(:@state_at_decision, hash[:state_at_decision])
        decision.instance_variable_set(:@timestamp, hash[:timestamp])
        decision
      end
    end
  end
end


