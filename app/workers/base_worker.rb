# frozen_string_literal: true

# Abstract base class for Workers that orchestrate multiple workflows.
# Workers manage the lifecycle of research sessions, maintain shared context,
# and coordinate workflow execution order.
#
# Uses StateMachine for enforced state transitions.
class BaseWorker
  include StateMachine

  # Define the base state machine
  initial_state :pending

  state :pending,  description: "Worker created, not yet started"
  state :running,  description: "Worker is executing"
  state :complete, description: "Worker finished successfully"
  state :failed,   description: "Worker encountered an error"

  # Define valid transitions
  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :complete, on: :finish
  transition from: [:pending, :running], to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  # Automatically record state transitions to memory
  on_transition do |from, to, event, payload|
    record_state_transition_to_memory(from, to, event, payload)
  end

  DEFAULT_STATE_PATH = ".agents/state"
  DEFAULT_OUTPUT_PATH = ".agents/references"

  attr_reader :owner_id, :goal, :path, :context, :result, :error, :workflows

  class << self
    def registered_workflows
      @registered_workflows ||= []
    end

    # Register a workflow class to be executed by this worker
    def register_workflow(workflow_class)
      registered_workflows << workflow_class unless registered_workflows.include?(workflow_class)
    end

    def worker_name
      name.demodulize.underscore
    end
  end

  # Initialize a new worker instance
  # @param goal [String] The goal/objective to work toward
  # @param path [String] The target path (e.g., codebase root for research)
  # @param context [Hash] Optional seed context/information for the worker
  # @param options [Hash] Additional options
  def initialize(goal:, path:, context: {}, **options)
    initialize_state_machine
    @owner_id = SecureRandom.uuid
    @goal = goal
    @path = validate_path!(path)
    @context = context || {}
    @options = options
    @result = nil
    @error = nil
    @workflows = []
    @workflow_results = {}
  end

  # Execute the worker's goal
  # Must be implemented by subclasses
  def execute
    raise NotImplementedError, "#{self.class.name} must implement #execute"
  end

  # Path for storing worker state files
  def state_path
    base = ENV["AGENT_STATE_PATH"] || File.join(path, DEFAULT_STATE_PATH)
    File.join(base, owner_id)
  end

  # Path for writing output files
  def output_path
    ENV["RESEARCH_OUTPUT_PATH"] || File.join(path, DEFAULT_OUTPUT_PATH)
  end

  # Query memory for specific sections - used by workflows to get context
  # @param section_names [Array<Symbol>] Section names to retrieve
  # @return [Hash] Hash of section_name => section_data
  def query_memory(*section_names)
    return {} unless respond_to?(:memory_store) && memory_store

    result = {}
    section_names.each do |name|
      begin
        data = memory_store.get_section(name)
        result[name] = data if data
      rescue StandardError
        # Section doesn't exist, skip
      end
    end
    result
  end

  # Get compressed context summary for passing to workflows/prompts
  # @return [Hash] Summary of current memory state
  def context_summary
    return {} unless respond_to?(:memory_store) && memory_store
    return memory_store.summarize_findings if memory_store.respond_to?(:summarize_findings)

    {}
  end

  # Convenience methods for checking state
  # These delegate to the state machine
  def status
    current_state
  end

  def pending?
    in_state?(:pending)
  end

  def running?
    in_state?(:running)
  end

  def complete?
    in_state?(:complete)
  end

  def failed?
    in_state?(:failed)
  end

  protected

  # Transition to running state
  def mark_running
    trigger(:start)
  end

  # Transition to complete state with result
  def mark_complete(result)
    @result = result
    trigger(:finish)
  end

  # Transition to failed state with error message
  def mark_failed(message)
    @error = message
    trigger(:fail)
  end

  # Retry from failed state
  def mark_retry
    @error = nil
    trigger(:retry)
  end

  # Store result from a workflow execution
  def store_workflow_result(workflow_name, result)
    @workflow_results[workflow_name] = result
  end

  # Get result from a previous workflow
  def workflow_result(workflow_name)
    @workflow_results[workflow_name]
  end

  # Ensure state directory exists
  def ensure_state_directory!
    FileUtils.mkdir_p(state_path)
  end

  # Ensure output directory exists
  def ensure_output_directory!
    FileUtils.mkdir_p(output_path)
  end

  private

  def record_state_transition_to_memory(from, to, event, payload)
    return unless respond_to?(:memory_store) && memory_store
    return unless memory_store.respond_to?(:record_state_transition)

    memory_store.record_state_transition(
      from: from,
      to: to,
      event: event,
      source: self.class.worker_name,
      payload: payload
    )
  end

  def validate_path!(path)
    expanded = File.expand_path(path)
    unless File.exist?(expanded) && File.readable?(expanded)
      raise ArgumentError, "Path does not exist or is not readable: #{path}"
    end
    expanded
  end
end
