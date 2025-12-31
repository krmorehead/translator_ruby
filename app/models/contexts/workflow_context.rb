# frozen_string_literal: true

module Contexts
  # Generic workflow state/history context.
  # Tracks workflow execution, decisions, and state transitions using proper OOP classes.
  #
  # Key features:
  # - Tracks state transitions with StateTransition objects
  # - Records decisions with Decision objects
  # - Records errors with WorkflowError objects
  # - Provides workflow history for debugging and context
  class WorkflowContext < BaseContext
    # Workflow-specific topic prefixes
    TOPIC_PREFIXES = {
      state: "state:",
      decision: "decision:",
      error: "error:",
      output: "output:",
      input: "input:"
    }.freeze

    attr_accessor :workflow_name, :workflow_id, :current_state
    attr_reader :transitions, :decisions, :errors, :started_at

    def initialize(workflow_name: nil, workflow_id: nil)
      super()
      raise ArgumentError, "workflow_name must be a String if provided" if workflow_name && !workflow_name.is_a?(String)
      raise ArgumentError, "workflow_id must be a String if provided" if workflow_id && !workflow_id.is_a?(String)

      @workflow_name = workflow_name
      @workflow_id = workflow_id || SecureRandom.uuid
      @current_state = :pending
      @started_at = Time.now.utc
      
      # Collections for workflow entities
      @transitions = []
      @decisions = []
      @errors = []
    end

    # Record a state transition
    # @param from [Symbol] Previous state
    # @param to [Symbol] New state
    # @param event [Symbol] Event that triggered the transition
    # @param payload [Hash] Additional data about the transition
    # @return [Workflow::StateTransition]
    def record_transition(from:, to:, event:, payload: {})
      raise ArgumentError, "from must be a Symbol" unless from.is_a?(Symbol)
      raise ArgumentError, "to must be a Symbol" unless to.is_a?(Symbol)
      raise ArgumentError, "event must be a Symbol" unless event.is_a?(Symbol)
      raise ArgumentError, "payload must be a Hash" unless payload.is_a?(Hash)

      @current_state = to

      # Create StateTransition object
      transition = Workflow::StateTransition.new(
        from: from,
        to: to,
        event: event,
        payload: payload
      )
      @transitions << transition

      # Also add as entry for context queries
      add(
        content: "#{from} → #{to} (#{event})",
        topics: [
          "#{TOPIC_PREFIXES[:state]}#{to}",
          "#{TOPIC_PREFIXES[:state]}transition"
        ],
        source: "state_machine",
        metadata: { transition_id: transition.id }
      )

      transition
    end

    # Record a decision made during workflow execution
    # @param decision [String] What was decided
    # @param rationale [String] Why this decision was made
    # @param context [Hash] Context that informed the decision
    # @return [Workflow::Decision]
    def record_decision(decision:, rationale:, context: {})
      raise ArgumentError, "decision must be a String" unless decision.is_a?(String)
      raise ArgumentError, "rationale must be a String" unless rationale.is_a?(String)
      raise ArgumentError, "context must be a Hash" unless context.is_a?(Hash)

      # Create Decision object
      decision_obj = Workflow::Decision.new(
        decision: decision,
        rationale: rationale,
        context: context,
        state_at_decision: @current_state
      )
      @decisions << decision_obj

      # Also add as entry for context queries
      add(
        content: "#{decision}: #{rationale}",
        topics: ["#{TOPIC_PREFIXES[:decision]}#{@current_state}"],
        source: "decisions",
        metadata: { decision_id: decision_obj.id }
      )

      decision_obj
    end

    # Record an error that occurred
    # @param error [String, StandardError] Error message or exception
    # @param recoverable [Boolean] Whether the error was recoverable
    # @return [Workflow::WorkflowError]
    def record_error(error, recoverable: true)
      raise ArgumentError, "recoverable must be a Boolean" unless [true, false].include?(recoverable)

      error_msg = error.is_a?(StandardError) ? error.message : error.to_s
      error_class = error.is_a?(StandardError) ? error.class.name : nil

      # Create WorkflowError object
      error_obj = Workflow::WorkflowError.new(
        error: error,
        recoverable: recoverable,
        state_at_error: @current_state
      )
      @errors << error_obj

      # Also add as entry for context queries
      add(
        content: "[#{recoverable ? 'WARN' : 'ERROR'}] #{error_msg}",
        topics: [
          "#{TOPIC_PREFIXES[:error]}#{@current_state}",
          "#{TOPIC_PREFIXES[:error]}#{recoverable ? 'recoverable' : 'fatal'}"
        ],
        source: "errors",
        metadata: { error_id: error_obj.id }
      )

      error_obj
    end

    # Record workflow input
    # @param input [Hash] Input data
    # @param input_type [String] Type/category of input
    # @return [Entry]
    def record_input(input:, input_type: "primary")
      add(
        content: "Input (#{input_type}): #{summarize_data(input)}",
        topics: ["#{TOPIC_PREFIXES[:input]}#{input_type}"],
        source: "inputs",
        metadata: {
          entity_type: :input,
          input_type: input_type,
          input_data: input
        }
      )
    end

    # Record workflow output
    # @param output [Hash] Output data
    # @param output_type [String] Type/category of output
    # @return [Entry]
    def record_output(output:, output_type: "primary")
      add(
        content: "Output (#{output_type}): #{summarize_data(output)}",
        topics: ["#{TOPIC_PREFIXES[:output]}#{output_type}"],
        source: "outputs",
        metadata: {
          entity_type: :output,
          output_type: output_type,
          output_data: output
        }
      )
    end

    # Get all fatal errors (non-recoverable)
    # @return [Array<Workflow::WorkflowError>] Fatal error objects
    def fatal_errors
      @errors.reject(&:recoverable)
    end

    # Get all recoverable errors
    # @return [Array<Workflow::WorkflowError>] Recoverable error objects  
    def recoverable_errors
      @errors.select(&:recoverable)
    end

    # Get states visited in order
    # @return [Array<Symbol>] States visited
    def states_visited
      @transitions.map(&:to_state)
    end

    # Calculate workflow duration
    # @return [Float] Duration in seconds
    def duration
      return 0.0 unless @started_at
      Time.now.utc - @started_at
    end

    # Format as an execution timeline
    # @return [String] Timeline of workflow execution
    def format_timeline
      parts = ["Workflow: #{@workflow_name} (#{@workflow_id})"]
      parts << "Duration: #{duration.round(2)}s"
      parts << "Current state: #{@current_state}"
      parts << ""

      @entries.each do |entry|
        time = entry.timestamp
        parts << "[#{time}] #{entry.content}"
      end

      parts.join("\n")
    end

    # Format as a summary for prompts
    # @return [String] Workflow summary
    def format_summary
      parts = []

      parts << "Workflow: #{@workflow_name}" if @workflow_name
      parts << "State: #{@current_state}"
      parts << "States visited: #{states_visited.uniq.join(' → ')}" if @transitions.any?

      recent_decisions = @decisions.last(3)
      if recent_decisions.any?
        parts << "Recent decisions:"
        recent_decisions.each { |d| parts << "  - #{d.decision}: #{d.rationale}" }
      end

      fatal = fatal_errors
      parts << "Errors: #{fatal.size}" if fatal.any?

      parts.join("\n")
    end

    # Override format_for_prompt for workflow-specific formatting
    # @param question [String] The question/context
    # @param format [Symbol] Output format (:timeline, :summary, :brief, :detailed)
    # @return [String] Formatted context
    def format_for_prompt(question, format: :brief)
      case format
      when :timeline
        format_timeline
      when :summary
        format_summary
      else
        super
      end
    end

    # Override to_h to include workflow-specific attributes
    def to_h
      super.merge(
        workflow_name: @workflow_name,
        workflow_id: @workflow_id,
        current_state: @current_state,
        started_at: @started_at&.iso8601,
        transitions: @transitions.map(&:to_h),
        decisions: @decisions.map(&:to_h),
        errors: @errors.map(&:to_h)
      )
    end

    # Override from_h to restore workflow-specific attributes
    def self.from_h(hash)
      raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
      raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
      raise ArgumentError, "Missing required keys" unless hash.key?(:workflow_id) && hash.key?(:current_state)

      context = allocate
      context.instance_variable_set(:@workflow_name, hash[:workflow_name])
      context.instance_variable_set(:@workflow_id, hash[:workflow_id])
      context.instance_variable_set(:@current_state, hash[:current_state]&.to_sym || :pending)
      context.instance_variable_set(:@entries, [])
      context.instance_variable_set(:@topic_index, Hash.new { |h, k| h[k] = Set.new })
      context.instance_variable_set(:@sub_contexts, {})

      # Restore started_at
      started_at = hash[:started_at] ? Time.parse(hash[:started_at]) : Time.now.utc
      context.instance_variable_set(:@started_at, started_at)

      # Reconstruct workflow entity objects
      transitions = (hash[:transitions] || []).map { |t| Workflow::StateTransition.from_h(t) }
      decisions = (hash[:decisions] || []).map { |d| Workflow::Decision.from_h(d) }
      errors = (hash[:errors] || []).map { |e| Workflow::WorkflowError.from_h(e) }

      context.instance_variable_set(:@transitions, transitions)
      context.instance_variable_set(:@decisions, decisions)
      context.instance_variable_set(:@errors, errors)

      # Restore entries and sub-contexts
      load_entries_from_h(context, hash)
      load_sub_contexts_from_h(context, hash)

      context
    end

    
    def summarize_data(data)
      return data.to_s if data.is_a?(String)
      return "#{data.size} items" if data.is_a?(Array)
      return "#{data.keys.size} keys" if data.is_a?(Hash)

      data.to_s.truncate(100)
    end
  end
end

