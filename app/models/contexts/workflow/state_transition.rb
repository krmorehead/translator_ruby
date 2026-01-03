# frozen_string_literal: true

module Contexts
  module Workflow
    # Represents a state transition in a workflow.
    # Tracks the from/to states, triggering event, and payload data.
    class StateTransition
      attr_reader :id, :from_state, :to_state, :event, :payload, :timestamp

      def initialize(from:, to:, event:, payload: {})
        raise ArgumentError, "from must be a Symbol" unless from.is_a?(Symbol)
        raise ArgumentError, "to must be a Symbol" unless to.is_a?(Symbol)
        raise ArgumentError, "event must be a Symbol" unless event.is_a?(Symbol)
        raise TypeError, "payload must be a Hash" unless payload.is_a?(Hash)

        @id = SecureRandom.uuid
        @from_state = from
        @to_state = to
        @event = event
        @payload = payload
        @timestamp = Time.now.utc.iso8601
      end

      def to_h
        {
          id: @id,
          from_state: @from_state,
          to_state: @to_state,
          event: @event,
          payload: @payload,
          timestamp: @timestamp
        }
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required keys" unless
          hash.key?(:id) && hash.key?(:from_state) && hash.key?(:to_state) && hash.key?(:event)

        transition = allocate
        transition.instance_variable_set(:@id, hash[:id])
        transition.instance_variable_set(:@from_state, hash[:from_state])
        transition.instance_variable_set(:@to_state, hash[:to_state])
        transition.instance_variable_set(:@event, hash[:event])
        transition.instance_variable_set(:@payload, hash[:payload] || {})
        transition.instance_variable_set(:@timestamp, hash[:timestamp])
        transition
      end
    end
  end
end








