# frozen_string_literal: true

require "active_support/core_ext/string/inflections"

# Minimal contract for workflows used by the orchestrator.
class BaseWorkflow
  STATUSES = {
    pending: :pending,
    running: :running,
    complete: :complete,
    failed: :failed
  }.freeze

  attr_reader :prompt, :conversation, :sandbox_path, :result, :error

  def self.workflow_name
    name.demodulize.underscore
  end

  def initialize
    @state = STATUSES[:pending]
    @result = nil
    @error = nil
  end

  # Stores incoming context; returns self for chaining.
  def setup(prompt:, conversation:, sandbox_path:)
    @prompt = prompt
    @conversation = conversation
    @sandbox_path = sandbox_path
    self
  end

  # Must be implemented by subclasses.
  def execute
    raise NotImplementedError, "#{self.class.name} must implement #execute"
  end

  def complete?
    @state == :complete
  end

  def failed?
    @state == :failed
  end

  protected

  def mark_complete(result)
    @result = result
    @state = STATUSES[:complete]
  end

  def mark_failed(message)
    @error = message
    @state = STATUSES[:failed]
  end
end
