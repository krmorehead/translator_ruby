# frozen_string_literal: true

module Contexts
  module Workflow
    # Represents an error that occurred during workflow execution.
    # Tracks error details, recoverability, and state at error.
    class WorkflowError
      attr_reader :id, :error_message, :error_class, :recoverable, :state_at_error, :timestamp

      def initialize(error:, recoverable: true, state_at_error:)
        raise ArgumentError, "error must be a String or StandardError" unless error.is_a?(String) || error.is_a?(StandardError)
        raise ArgumentError, "recoverable must be a Boolean" unless [true, false].include?(recoverable)
        raise ArgumentError, "state_at_error must be a Symbol" unless state_at_error.is_a?(Symbol)

        @id = SecureRandom.uuid
        @error_message = error.is_a?(StandardError) ? error.message : error.to_s
        @error_class = error.is_a?(StandardError) ? error.class.name : nil
        @recoverable = recoverable
        @state_at_error = state_at_error
        @timestamp = Time.now.utc.iso8601
      end

      def recoverable?
        @recoverable
      end

      def fatal?
        !@recoverable
      end

      def to_h
        {
          id: @id,
          error_message: @error_message,
          error_class: @error_class,
          recoverable: @recoverable,
          state_at_error: @state_at_error,
          timestamp: @timestamp
        }
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required keys" unless
          hash.key?(:id) && hash.key?(:error_message) && hash.key?(:state_at_error)

        error = allocate
        error.instance_variable_set(:@id, hash[:id])
        error.instance_variable_set(:@error_message, hash[:error_message])
        error.instance_variable_set(:@error_class, hash[:error_class])
        error.instance_variable_set(:@recoverable, hash[:recoverable].nil? ? true : hash[:recoverable])
        error.instance_variable_set(:@state_at_error, hash[:state_at_error])
        error.instance_variable_set(:@timestamp, hash[:timestamp])
        error
      end
    end
  end
end








