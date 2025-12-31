# frozen_string_literal: true

module Contexts
  module Actions
    # Specialized action for tool executions.
    # Tracks additional tool-specific data like tool name and detailed results.
    class ToolAction < BaseAction
      attr_reader :tool_name, :tool_result

      def initialize(tool_name:, arguments:, result:, iteration:, cached: false)
        raise ArgumentError, "tool_name must be a String" unless tool_name.is_a?(String)

        @tool_name = tool_name
        @tool_result = result

        super(
          name: tool_name.to_sym,
          arguments: arguments,
          result: result,
          iteration: iteration,
          cached: cached
        )
      end

      def to_h
        {
          **super,
          tool_name: @tool_name,
          tool_result: @tool_result
        }
      end

      def self.from_h(hash)
        raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
        raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
        raise ArgumentError, "Missing required tool action keys" unless
          hash.key?(:tool_name) && hash.key?(:tool_result)

        action = allocate
        action.instance_variable_set(:@id, hash[:id])
        action.instance_variable_set(:@name, hash[:name])
        action.instance_variable_set(:@arguments, hash[:arguments])
        action.instance_variable_set(:@success, hash[:success])
        action.instance_variable_set(:@result_summary, hash[:result_summary])
        action.instance_variable_set(:@iteration, hash[:iteration])
        action.instance_variable_set(:@cached, hash[:cached] || false)
        action.instance_variable_set(:@timestamp, hash[:timestamp])
        action.instance_variable_set(:@tool_name, hash[:tool_name])
        action.instance_variable_set(:@tool_result, hash[:tool_result])
        action
      end
    end
  end
end

