# frozen_string_literal: true

# Immutable value object for tracking workflow progress.
class WorkflowState
  STATUSES = {
    pending: :pending,
    running: :running,
    complete: :complete,
    failed: :failed
  }.freeze

  attr_reader :status, :prompt, :data, :error

  def initialize(status: STATUSES[:pending], prompt: nil, data: {}, error: nil)
    @status = status.to_sym
    @prompt = prompt
    @data = data || {}
    @error = error
  end

  def with(status: nil, prompt: nil, data: nil, error: nil)
    WorkflowState.new(
      status: status || self.status,
      prompt: prompt || self.prompt,
      data: data || self.data,
      error: error || self.error
    )
  end

  def complete?
    status == :complete
  end

  def failed?
    status == :failed
  end

  def pending?
    status == :pending
  end

  def running?
    status == :running
  end

  def to_h
    {
      status: status,
      prompt: prompt,
      data: data,
      error: error
    }
  end
end

