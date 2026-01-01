# frozen_string_literal: true

require "test_helper"

class WorkflowContextTest < ActiveSupport::TestCase
  def context
    @context ||= Contexts::WorkflowContext.new(
      workflow_name: "test_workflow",
      workflow_id: "wf-123"
    )
  end
  speed_profile :fast
  test "initializes with workflow metadata" do
    assert_equal "test_workflow", context.workflow_name
    assert_equal "wf-123", context.workflow_id
    assert_equal :pending, context.current_state
  end

  speed_profile :fast
  test "generates workflow_id if not provided" do
    ctx = Contexts::WorkflowContext.new
    assert_not_nil ctx.workflow_id
  end

  speed_profile :fast
  test "record_transition updates current_state" do
    context.record_transition(from: :pending, to: :running, event: :start)

    assert_equal :running, context.current_state
  end

  speed_profile :fast
  test "record_transition creates transition object and entry" do
    transition = context.record_transition(from: :pending, to: :running, event: :start, payload: { reason: "test" })

    # Check transition object
    assert_instance_of Contexts::Workflow::StateTransition, transition
    assert_equal :pending, transition.from_state
    assert_equal :running, transition.to_state
    assert_equal :start, transition.event
    assert_equal({ reason: "test" }, transition.payload)

    # Check entry was created
    assert_equal 1, context.size
    assert_equal 1, context.transitions.size
  end

  speed_profile :fast
  test "record_decision creates decision object and entry" do
    decision = context.record_decision(
      decision: "Use parallel processing",
      rationale: "Large file count",
      context: { file_count: 100 }
    )

    # Check decision object
    assert_instance_of Contexts::Workflow::Decision, decision
    assert_equal "Use parallel processing", decision.decision
    assert_equal "Large file count", decision.rationale
    assert_equal({ file_count: 100 }, decision.decision_context)
    assert_equal :pending, decision.state_at_decision

    # Check entry was created
    assert_equal 1, context.size
    assert_equal 1, context.decisions.size
  end

  speed_profile :fast
  test "record_error creates error object and entry" do
    error_obj = context.record_error("Connection timeout", recoverable: true)

    # Check error object
    assert_instance_of Contexts::Workflow::WorkflowError, error_obj
    assert_equal "Connection timeout", error_obj.error_message
    assert error_obj.recoverable?
    assert_not error_obj.fatal?
    assert_equal :pending, error_obj.state_at_error

    # Check entry was created
    assert_equal 1, context.size
    assert_equal 1, context.errors.size
  end

  speed_profile :fast
  test "record_error handles exceptions" do
    error = StandardError.new("Something went wrong")
    error_obj = context.record_error(error, recoverable: false)

    # Check error object
    assert_equal "Something went wrong", error_obj.error_message
    assert_equal "StandardError", error_obj.error_class
    assert_not error_obj.recoverable?
    assert error_obj.fatal?

    # Check entry was created
    entry = context.entries.first
    assert entry.content.include?("[ERROR]")
  end

  speed_profile :fast
  test "record_input creates input entry" do
    context.record_input(input: { file: "test.rb" }, input_type: "file")

    entry = context.entries.first
    assert_equal :input, entry.metadata[:entity_type]
  end

  speed_profile :fast
  test "record_output creates output entry" do
    context.record_output(output: { result: "success" }, output_type: "final")

    entry = context.entries.first
    assert_equal :output, entry.metadata[:entity_type]
  end

  speed_profile :fast
  test "transitions returns all transition objects" do
    context.record_transition(from: :pending, to: :running, event: :start)
    context.record_decision(decision: "test", rationale: "test")
    context.record_transition(from: :running, to: :complete, event: :finish)

    assert_equal 2, context.transitions.size
    assert context.transitions.all? { |t| t.is_a?(Contexts::Workflow::StateTransition) }
  end

  speed_profile :fast
  test "decisions returns all decision objects" do
    context.record_decision(decision: "A", rationale: "reason A")
    context.record_transition(from: :pending, to: :running, event: :start)
    context.record_decision(decision: "B", rationale: "reason B")

    assert_equal 2, context.decisions.size
    assert context.decisions.all? { |d| d.is_a?(Contexts::Workflow::Decision) }
  end

  speed_profile :fast
  test "errors returns error objects" do
    context.record_error("Error 1", recoverable: true)
    context.record_error("Error 2", recoverable: false)

    all_errors = context.errors
    assert_equal 2, all_errors.size
    assert all_errors.all? { |e| e.is_a?(Contexts::Workflow::WorkflowError) }

    fatal_only = context.fatal_errors
    assert_equal 1, fatal_only.size
    assert fatal_only.first.fatal?

    recoverable_only = context.recoverable_errors
    assert_equal 1, recoverable_only.size
    assert recoverable_only.first.recoverable?
  end

  speed_profile :fast
  test "states_visited returns ordered list of states" do
    context.record_transition(from: :pending, to: :running, event: :start)
    context.record_transition(from: :running, to: :processing, event: :process)
    context.record_transition(from: :processing, to: :complete, event: :finish)

    states = context.states_visited
    assert_equal [:running, :processing, :complete], states
  end

  speed_profile :fast
  test "duration returns time since start" do
    assert context.duration >= 0
  end

  speed_profile :fast
  test "format_timeline creates chronological view" do
    context.record_transition(from: :pending, to: :running, event: :start)
    context.record_decision(decision: "test", rationale: "testing")

    formatted = context.format_timeline

    assert formatted.include?("test_workflow")
    assert formatted.include?("Duration:")
  end

  speed_profile :fast
  test "format_summary creates brief summary" do
    context.record_transition(from: :pending, to: :running, event: :start)
    context.record_decision(decision: "Use cache", rationale: "performance")

    formatted = context.format_summary

    assert formatted.include?("test_workflow")
    assert formatted.include?("running")
    assert formatted.include?("Recent decisions")
  end

  speed_profile :fast
  test "format_for_prompt with :timeline format" do
    formatted = context.format_for_prompt("status", format: :timeline)
    assert formatted.include?("test_workflow")
  end

  speed_profile :fast
  test "format_for_prompt with :summary format" do
    formatted = context.format_for_prompt("status", format: :summary)
    assert formatted.include?("pending")
  end

  speed_profile :fast
  test "serializes with workflow metadata and entities" do
    context.record_transition(from: :pending, to: :running, event: :start)
    context.record_decision(decision: "test", rationale: "testing")

    hash = context.to_h
    assert_equal "test_workflow", hash[:workflow_name]
    assert_equal "wf-123", hash[:workflow_id]
    assert_equal :running, hash[:current_state]
    assert_equal 1, hash[:transitions].size
    assert_equal 1, hash[:decisions].size
  end

  speed_profile :fast
  test "deserializes with workflow metadata and entities" do
    context.record_transition(from: :pending, to: :running, event: :start)
    context.record_decision(decision: "test", rationale: "testing")
    context.record_error("test error", recoverable: true)

    hash = context.to_h
    restored = Contexts::WorkflowContext.from_h(hash)

    assert_equal "test_workflow", restored.workflow_name
    assert_equal "wf-123", restored.workflow_id
    assert_equal :running, restored.current_state
    assert_equal 1, restored.transitions.size
    assert_equal 1, restored.decisions.size
    assert_equal 1, restored.errors.size
    assert_equal 3, restored.size  # 3 entries
  end
end

