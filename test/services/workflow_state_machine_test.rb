# frozen_string_literal: true

require "test_helper"

class WorkflowStateMachineTest < ActiveSupport::TestCase
  class TestWorkflow < BaseWorkflow
    attr_reader :setup_called

    def setup(prompt: nil, conversation: nil)
      @setup_called = true
      super
    end

    def execute
      trigger(:start)
      # Simulate some work
      mark_complete({ result: "done" })
    end
  end

  class CustomStateWorkflow < BaseWorkflow
    initial_state :pending

    state :pending,    description: "Waiting"
    state :running,    phase: :work, description: "Working"
    state :validating, phase: :check, description: "Checking"
    state :complete,   description: "Done"
    state :failed,     description: "Error"

    transition from: :pending, to: :running, on: :start
    transition from: :running, to: :validating, on: :validated
    transition from: :validating, to: :complete, on: :finish
    transition from: [:running, :validating], to: :failed, on: :fail

    def execute
      trigger(:start)
      # Simulate validation
      trigger(:validated)
      mark_complete({ validated: true })
    end
  end

  let(:temp_dir) do
    dir = Rails.root.join("tmp", "workflow_state_test_#{Process.pid}").to_s
    FileUtils.mkdir_p(dir)
    dir
  end

  def teardown
    FileUtils.rm_rf(temp_dir) if temp_dir && File.exist?(temp_dir)
  end

  # Basic state machine inheritance tests
  speed_profile :fast
  test "workflow inherits base states from BaseWorkflow" do
    workflow = TestWorkflow.new
    assert workflow.pending?
    refute workflow.running?
    refute workflow.complete?
  end

  speed_profile :fast
  test "workflow can transition through states" do
    workflow = TestWorkflow.new
    workflow.setup()
    workflow.execute

    assert workflow.complete?
    assert_equal({ result: "done" }, workflow.result)
  end

  # Custom workflow with overridden states
  speed_profile :fast
  test "custom workflow overrides parent transitions" do
    workflow = CustomStateWorkflow.new
    workflow.setup()
    workflow.execute

    assert workflow.complete?
    assert_equal({ validated: true }, workflow.result)
  end

  speed_profile :fast
  test "custom workflow has correct phases" do
    workflow = CustomStateWorkflow.new

    assert_nil workflow.current_phase

    workflow.trigger(:start)
    assert_equal :work, workflow.current_phase

    workflow.trigger(:validated)
    assert_equal :check, workflow.current_phase
  end

  # Workflow memory tests
  speed_profile :fast
  test "workflow creates workflow_memory when setup is called with owner_id" do
    workflow = TestWorkflow.new(owner_id: SecureRandom.uuid)
    workflow.setup()

    assert_not_nil workflow.workflow_memory
    assert_instance_of WorkflowMemoryStore, workflow.workflow_memory
  end

  speed_profile :fast
  test "workflow memory records state transitions" do
    workflow = TestWorkflow.new(owner_id: SecureRandom.uuid)
    workflow.setup()
    workflow.execute

    history = workflow.workflow_memory.state_history
    assert history.any?
    assert history.all? { |h| h.is_a?(WorkflowMemories::StateTransition) }
    # Should have at least start and finish transitions
    events = history.map(&:event)
    assert_includes events, :start
    assert_includes events, :finish
  end

  # Parent memory query tests
  class MockParentMemory
    def initialize(data = {})
      @data = data
    end

    def get_section(name)
      @data[name.to_sym]
    end

    def summarize_findings
      { summary: "test summary" }
    end
  end

  speed_profile :fast
  test "workflow can query parent memory" do
    parent = MockParentMemory.new(
      research_goal: [{ text: "Main Goal" }],
      findings: [{ text: "Finding 1" }]
    )

    workflow = TestWorkflow.new(
      owner_id: SecureRandom.uuid,
      parent_memory: parent
    )
    workflow.setup()

    result = workflow.query_parent_memory(:research_goal, :findings)
    assert_equal [{ text: "Main Goal" }], result[:research_goal]
    assert_equal [{ text: "Finding 1" }], result[:findings]
  end

  speed_profile :fast
  test "workflow can get parent context summary" do
    parent = MockParentMemory.new
    workflow = TestWorkflow.new(
      owner_id: SecureRandom.uuid,
      parent_memory: parent
    )
    workflow.setup()

    context = workflow.parent_context
    assert_equal({ summary: "test summary" }, context)
  end

  # Decision recording tests
  speed_profile :fast
  test "workflow can record decisions to memory" do
    workflow = TestWorkflow.new(owner_id: SecureRandom.uuid)
    workflow.setup()

    workflow.record_decision(
      decision: "Use parallel processing",
      rationale: "More efficient",
      context: { file_count: 10 }
    )

    decisions = workflow.workflow_memory.get_section(:decisions)
    assert_equal 1, decisions.size
    assert_instance_of WorkflowMemories::Decision, decisions.first
    assert_equal "Use parallel processing", decisions.first.decision
  end

  # Memory summary tests
  speed_profile :fast
  test "memory_summary returns workflow metadata" do
    workflow = TestWorkflow.new(owner_id: SecureRandom.uuid)
    workflow.setup()
    workflow.execute

    summary = workflow.memory_summary
    assert_equal "test_workflow", summary[:workflow_name]
    assert_not_nil summary[:workflow_id]
    assert summary[:transition_count] > 0
  end

  # Error handling with state machine
  class FailingWorkflow < BaseWorkflow
    def execute
      trigger(:start)
      raise StandardError, "Something went wrong"
    rescue StandardError => e
      mark_failed(e.message)
    end
  end

  speed_profile :fast
  test "failing workflow transitions to failed state" do
    workflow = FailingWorkflow.new(owner_id: SecureRandom.uuid)
    workflow.setup()
    workflow.execute

    assert workflow.failed?
    assert_equal "Something went wrong", workflow.error
  end

  speed_profile :fast
  test "failing workflow records error to memory" do
    workflow = FailingWorkflow.new(owner_id: SecureRandom.uuid)
    workflow.setup()
    workflow.execute

    errors = workflow.workflow_memory.get_section(:errors)
    assert_equal 1, errors.size
    assert_instance_of WorkflowMemories::Error, errors.first
    assert_equal "Something went wrong", errors.first.error_message
  end
end

