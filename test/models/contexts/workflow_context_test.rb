# frozen_string_literal: true

require "test_helper"

class WorkflowContextTest < ActiveSupport::TestCase
  def context
    @context ||= Contexts::WorkflowContext.new(
      workflow_name: "test_workflow",
      workflow_id: "wf-123"
    )
  end

  test "initializes with workflow metadata" do
    assert_equal "test_workflow", context.workflow_name
    assert_equal "wf-123", context.workflow_id
    assert_equal :pending, context.current_state
  end

  test "generates workflow_id if not provided" do
    ctx = Contexts::WorkflowContext.new
    assert_not_nil ctx.workflow_id
  end

  test "record_transition updates current_state" do
    context.record_transition(from: :pending, to: :running, event: :start)

    assert_equal :running, context.current_state
  end

  test "record_transition creates entry" do
    context.record_transition(from: :pending, to: :running, event: :start, payload: { reason: "test" })

    assert_equal 1, context.size
    entry = context.entries.first
    assert_equal :transition, entry.metadata[:entity_type]
    assert_equal :running, entry.metadata[:to]
  end

  test "record_decision creates decision entry" do
    context.record_decision(
      decision: "Use parallel processing",
      rationale: "Large file count",
      context: { file_count: 100 }
    )

    entry = context.entries.first
    assert_equal :decision, entry.metadata[:entity_type]
    assert entry.content.include?("Use parallel processing")
  end

  test "record_error creates error entry" do
    context.record_error("Connection timeout", recoverable: true)

    entry = context.entries.first
    assert_equal :error, entry.metadata[:entity_type]
    assert entry.metadata[:recoverable]
    assert entry.content.include?("[WARN]")
  end

  test "record_error handles exceptions" do
    error = StandardError.new("Something went wrong")
    context.record_error(error, recoverable: false)

    entry = context.entries.first
    assert_equal "StandardError", entry.metadata[:error_class]
    assert entry.content.include?("[ERROR]")
  end

  test "record_input creates input entry" do
    context.record_input(input: { file: "test.rb" }, input_type: "file")

    entry = context.entries.first
    assert_equal :input, entry.metadata[:entity_type]
  end

  test "record_output creates output entry" do
    context.record_output(output: { result: "success" }, output_type: "final")

    entry = context.entries.first
    assert_equal :output, entry.metadata[:entity_type]
  end

  test "transitions returns all transition entries" do
    context.record_transition(from: :pending, to: :running, event: :start)
    context.record_decision(decision: "test", rationale: "test")
    context.record_transition(from: :running, to: :complete, event: :finish)

    assert_equal 2, context.transitions.size
  end

  test "decisions returns all decision entries" do
    context.record_decision(decision: "A", rationale: "reason A")
    context.record_transition(from: :pending, to: :running, event: :start)
    context.record_decision(decision: "B", rationale: "reason B")

    assert_equal 2, context.decisions.size
  end

  test "errors returns error entries" do
    context.record_error("Error 1", recoverable: true)
    context.record_error("Error 2", recoverable: false)

    all_errors = context.errors
    assert_equal 2, all_errors.size

    fatal_only = context.errors(include_recovered: false)
    assert_equal 1, fatal_only.size
  end

  test "states_visited returns ordered list of states" do
    context.record_transition(from: :pending, to: :running, event: :start)
    context.record_transition(from: :running, to: :processing, event: :process)
    context.record_transition(from: :processing, to: :complete, event: :finish)

    states = context.states_visited
    assert_equal [:running, :processing, :complete], states
  end

  test "duration returns time since start" do
    assert context.duration >= 0
  end

  test "format_timeline creates chronological view" do
    context.record_transition(from: :pending, to: :running, event: :start)
    context.record_decision(decision: "test", rationale: "testing")

    formatted = context.format_timeline

    assert formatted.include?("test_workflow")
    assert formatted.include?("Duration:")
  end

  test "format_summary creates brief summary" do
    context.record_transition(from: :pending, to: :running, event: :start)
    context.record_decision(decision: "Use cache", rationale: "performance")

    formatted = context.format_summary

    assert formatted.include?("test_workflow")
    assert formatted.include?("running")
    assert formatted.include?("Recent decisions")
  end

  test "format_for_prompt with :timeline format" do
    formatted = context.format_for_prompt("status", format: :timeline)
    assert formatted.include?("test_workflow")
  end

  test "format_for_prompt with :summary format" do
    formatted = context.format_for_prompt("status", format: :summary)
    assert formatted.include?("pending")
  end

  test "serializes with workflow metadata" do
    context.record_transition(from: :pending, to: :running, event: :start)

    hash = context.to_h
    assert_equal "test_workflow", hash[:workflow_name]
    assert_equal "wf-123", hash[:workflow_id]
    assert_equal :running, hash[:current_state]
  end

  test "deserializes with workflow metadata" do
    context.record_transition(from: :pending, to: :running, event: :start)

    hash = context.to_h
    restored = Contexts::WorkflowContext.from_h(hash)

    assert_equal "test_workflow", restored.workflow_name
    assert_equal "wf-123", restored.workflow_id
    assert_equal :running, restored.current_state
    assert_equal 1, restored.size
  end
end

