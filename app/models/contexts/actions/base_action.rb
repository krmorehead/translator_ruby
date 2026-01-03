# frozen_string_literal: true

module Contexts
  module Actions
    # Base class for all action records in ActionHistoryContext.
    # Tracks execution of actions with results, success status, and caching.
    #
    # Actions are immutable records of what was executed.
    class BaseAction
      attr_reader :id, :name, :arguments, :success, :result_summary, :iteration, :cached, :timestamp

      def initialize(name:, arguments:, result:, iteration:, cached: false)
        raise ArgumentError, "name must be a Symbol or String" unless name.is_a?(Symbol) || name.is_a?(String)
        raise ArgumentError, "arguments must be a Hash" unless arguments.is_a?(Hash)
        raise TypeError, "result must be a Hash" unless result.is_a?(Hash)
        raise ArgumentError, "result must contain :success key" unless result.key?(:success)
        raise ArgumentError, "iteration must be an Integer" unless iteration.is_a?(Integer)
        raise ArgumentError, "cached must be a Boolean" unless [true, false].include?(cached)

        @id = SecureRandom.uuid
        @name = name.to_sym
        @arguments = arguments
        @success = result[:success]
        @result_summary = extract_result_summary(result)
        @iteration = iteration
        @cached = cached
        @timestamp = Time.now.utc.iso8601
      end

      def successful?
        @success
      end

      def failed?
        !@success
      end

      def to_h
        {
          id: @id,
          name: @name,
          arguments: @arguments,
          success: @success,
          result_summary: @result_summary,
          iteration: @iteration,
          cached: @cached,
          timestamp: @timestamp
        }
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required keys" unless 
          hash.key?(:id) && hash.key?(:name) && hash.key?(:arguments) && 
          hash.key?(:success) && hash.key?(:iteration)

        action = allocate
        action.instance_variable_set(:@id, hash[:id])
        action.instance_variable_set(:@name, hash[:name])
        action.instance_variable_set(:@arguments, hash[:arguments])
        action.instance_variable_set(:@success, hash[:success])
        action.instance_variable_set(:@result_summary, hash[:result_summary])
        action.instance_variable_set(:@iteration, hash[:iteration])
        action.instance_variable_set(:@cached, hash[:cached] || false)
        action.instance_variable_set(:@timestamp, hash[:timestamp])
        action
      end

      private

      def extract_result_summary(result)
        return result[:error] if result[:error]
        return result[:summary] if result[:summary]
        return "Found #{result[:count]} items" if result[:count]
        return "#{result[:findings].size} findings" if result[:findings]

        result[:success] ? "completed" : "failed"
      end
    end
  end
end


