# frozen_string_literal: true

module Contexts
  # Generic workflow state/history context.
  # Tracks workflow execution, decisions, and state transitions.
  #
  # Key features:
  # - Tracks state transitions with timestamps
  # - Records decisions and their rationale
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

    def initialize(workflow_name: nil, workflow_id: nil)
      super()
      @workflow_name = workflow_name
      @workflow_id = workflow_id || SecureRandom.uuid
      @current_state = :pending
      @started_at = Time.now.utc
    end

    # Record a state transition
    # @param from [Symbol] Previous state
    # @param to [Symbol] New state
    # @param event [Symbol] Event that triggered the transition
    # @param payload [Hash] Additional data about the transition
    # @return [Entry]
    def record_transition(from:, to:, event:, payload: {})
      @current_state = to

      add(
        content: "#{from} → #{to} (#{event})",
        topics: [
          "#{TOPIC_PREFIXES[:state]}#{to}",
          "#{TOPIC_PREFIXES[:state]}transition"
        ],
        source: "state_machine",
        metadata: {
          entity_type: :transition,
          from: from,
          to: to,
          event: event,
          payload: payload
        }
      )
    end

    # Record a decision made during workflow execution
    # @param decision [String] What was decided
    # @param rationale [String] Why this decision was made
    # @param context [Hash] Context that informed the decision
    # @return [Entry]
    def record_decision(decision:, rationale:, context: {})
      add(
        content: "#{decision}: #{rationale}",
        topics: ["#{TOPIC_PREFIXES[:decision]}#{@current_state}"],
        source: "decisions",
        metadata: {
          entity_type: :decision,
          decision: decision,
          rationale: rationale,
          decision_context: context,
          state_at_decision: @current_state
        }
      )
    end

    # Record an error that occurred
    # @param error [String, StandardError] Error message or exception
    # @param recoverable [Boolean] Whether the error was recoverable
    # @return [Entry]
    def record_error(error, recoverable: true)
      error_msg = error.is_a?(StandardError) ? error.message : error.to_s
      error_class = error.is_a?(StandardError) ? error.class.name : nil

      add(
        content: "[#{recoverable ? 'WARN' : 'ERROR'}] #{error_msg}",
        topics: [
          "#{TOPIC_PREFIXES[:error]}#{@current_state}",
          "#{TOPIC_PREFIXES[:error]}#{recoverable ? 'recoverable' : 'fatal'}"
        ],
        source: "errors",
        metadata: {
          entity_type: :error,
          error_message: error_msg,
          error_class: error_class,
          recoverable: recoverable,
          state_at_error: @current_state
        }
      )
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

    # Get all state transitions
    # @return [Array<Entry>] Transition entries in order
    def transitions
      @entries.select { |e| e.metadata[:entity_type] == :transition }
    end

    # Get all decisions
    # @return [Array<Entry>] Decision entries
    def decisions
      @entries.select { |e| e.metadata[:entity_type] == :decision }
    end

    # Get all errors
    # @param include_recovered [Boolean] Whether to include recoverable errors
    # @return [Array<Entry>] Error entries
    def errors(include_recovered: true)
      @entries.select do |e|
        e.metadata[:entity_type] == :error &&
          (include_recovered || !e.metadata[:recoverable])
      end
    end

    # Get states visited in order
    # @return [Array<Symbol>] States visited
    def states_visited
      transitions.map { |t| t.metadata[:to] }
    end

    # Calculate workflow duration
    # @return [Float] Duration in seconds
    def duration
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
      parts << "States visited: #{states_visited.uniq.join(' → ')}" if transitions.any?

      recent_decisions = decisions.last(3)
      if recent_decisions.any?
        parts << "Recent decisions:"
        recent_decisions.each { |d| parts << "  - #{d.content}" }
      end

      error_list = errors(include_recovered: false)
      parts << "Errors: #{error_list.size}" if error_list.any?

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
        started_at: @started_at.iso8601
      )
    end

    # Override from_h to restore workflow-specific attributes
    def self.from_h(data, context_registry: nil)
      context = new(
        workflow_name: data[:workflow_name] || data["workflow_name"],
        workflow_id: data[:workflow_id] || data["workflow_id"]
      )
      context.current_state = (data[:current_state] || data["current_state"])&.to_sym || :pending

      started_at = data[:started_at] || data["started_at"]
      context.instance_variable_set(:@started_at, Time.parse(started_at)) if started_at

      load_entries_from_h(context, data)
      load_sub_contexts_from_h(context, data, context_registry)
      context
    end

    private

    def summarize_data(data)
      return data.to_s if data.is_a?(String)
      return "#{data.size} items" if data.is_a?(Array)
      return "#{data.keys.size} keys" if data.is_a?(Hash)

      data.to_s.truncate(100)
    end
  end
end

