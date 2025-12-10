# frozen_string_literal: true

require "securerandom"
require "time"

# Value object representing a detected action in the workflow.
class ActionRecord
  STATUSES = {
    pending: :pending,
    executed: :executed,
    failed: :failed
  }.freeze

  attr_reader :id, :prompt_reference, :tool_name, :arguments,
              :status, :result, :consequence, :error, :timestamp

  def initialize(prompt_reference:, tool_name:, arguments:, id: nil, status: STATUSES[:pending], result: nil, consequence: nil, error: nil, timestamp: nil)
    raise ArgumentError, "tool_name is required" unless tool_name
    raise ArgumentError, "arguments must be a hash" unless arguments.is_a?(Hash)

    @id = id || SecureRandom.uuid
    @prompt_reference = prompt_reference
    @tool_name = tool_name
    @arguments = arguments
    @status = status.to_sym
    @result = result
    @consequence = consequence
    @error = error
    @timestamp = timestamp || Time.now
  end

  def with(**attrs)
    ActionRecord.new(
      id: attrs.fetch(:id, id),
      prompt_reference: attrs.fetch(:prompt_reference, prompt_reference),
      tool_name: attrs.fetch(:tool_name, tool_name),
      arguments: attrs.fetch(:arguments, arguments),
      status: attrs.fetch(:status, status),
      result: attrs.fetch(:result, result),
      consequence: attrs.fetch(:consequence, consequence),
      error: attrs.fetch(:error, error),
      timestamp: attrs.fetch(:timestamp, timestamp)
    )
  end

  def to_h
    {
      id: id,
      prompt_reference: prompt_reference,
      tool_name: tool_name,
      arguments: arguments,
      status: status,
      result: result,
      consequence: consequence,
      error: error,
      timestamp: timestamp
    }
  end
end
