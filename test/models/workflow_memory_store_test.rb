# frozen_string_literal: true

require "test_helper"

class WorkflowMemoryStoreTest < ActiveSupport::TestCase
  let(:temp_dir) do
    dir = Rails.root.join("tmp", "workflow_memory_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(dir)
    dir
  end

  let(:owner_id) { SecureRandom.uuid }
  let(:workflow_id) { SecureRandom.uuid }
  let(:workflow_name) { "test_workflow" }

  let(:store) do
    path = File.join(temp_dir, owner_id, "workflows", "#{workflow_name}_#{workflow_id}.json")
    WorkflowMemoryStore.new(
      owner_id: owner_id,
      workflow_id: workflow_id,
      workflow_name: workflow_name,
      path: path
    )
  end

  def teardown
    FileUtils.rm_rf(temp_dir) if temp_dir && File.exist?(temp_dir)
  end
  speed_profile :fast
  test "requires owner_id" do
    assert_raises(ArgumentError) do
      WorkflowMemoryStore.new(
        owner_id: nil,
        workflow_id: workflow_id,
        workflow_name: workflow_name
      )
    end
  end

  speed_profile :fast
  test "requires workflow_id" do
    assert_raises(ArgumentError) do
      WorkflowMemoryStore.new(
        owner_id: owner_id,
        workflow_id: nil,
        workflow_name: workflow_name
      )
    end
  end

  speed_profile :fast
  test "initializes with default sections" do
    assert_equal [], store.get_section(:state_transitions)
    assert_equal [], store.get_section(:workflow_context)
    assert_equal [], store.get_section(:decisions)
    assert_equal [], store.get_section(:errors)
    assert_equal [], store.get_section(:outputs)
  end

  speed_profile :fast
  test "records state transitions" do
    entry = store.record_state_transition(
      from: :pending,
      to: :running,
      event: :start,
      payload: { reason: "test" }
    )

    assert_equal :pending, entry.from
    assert_equal :running, entry.to
    assert_equal :start, entry.event
    assert_equal({ reason: "test" }, entry.payload)
    assert entry.timestamp.present?
  end

  speed_profile :fast
  test "state_history returns all transitions" do
    store.record_state_transition(from: :pending, to: :running, event: :start)
    store.record_state_transition(from: :running, to: :complete, event: :finish)

    history = store.state_history
    assert_equal 2, history.size
    assert_equal :pending, history.first.from
    assert_equal :complete, history.last.to
  end

  speed_profile :fast
  test "current_state reflects latest transition" do
    assert_equal :pending, store.current_state

    store.record_state_transition(from: :pending, to: :running, event: :start)
    assert_equal :running, store.current_state

    store.record_state_transition(from: :running, to: :complete, event: :finish)
    assert_equal :complete, store.current_state
  end

  speed_profile :fast
  test "records decisions" do
    entry = store.record_decision(
      decision: "Use parallel analysis",
      rationale: "More thorough coverage",
      context: { file_count: 10 }
    )

    assert_equal "Use parallel analysis", entry.decision
    assert_equal "More thorough coverage", entry.rationale
    assert_equal({ file_count: 10 }, entry.context)
  end

  speed_profile :fast
  test "records errors" do
    error = StandardError.new("Test error")
    entry = store.record_error(error, state: :running)

    assert_instance_of WorkflowMemories::Error, entry
    assert_equal "Test error", entry.error_message
    assert_equal "StandardError", entry.error_class
    assert_equal :running, entry.state
  end

  speed_profile :fast
  test "records outputs" do
    entry = store.record_output({ findings: ["A", "B"], success: true })

    assert_instance_of WorkflowMemories::Output, entry
    assert_equal ["A", "B"], entry.output_data[:findings]
    assert entry.output_data[:success]
  end

  speed_profile :fast
  test "summarize returns workflow metadata" do
    store.record_state_transition(from: :pending, to: :running, event: :start)
    store.record_decision(decision: "test", rationale: "test")

    summary = store.summarize
    assert_equal workflow_name, summary[:workflow_name]
    assert_equal workflow_id, summary[:workflow_id]
    assert_equal owner_id, summary[:owner_id]
    assert_equal 1, summary[:transition_count]
    assert_equal 1, summary[:decision_count]
    assert_equal 0, summary[:error_count]
  end

  speed_profile :fast
  test "to_h serializes all data" do
    store.record_state_transition(from: :pending, to: :running, event: :start)

    hash = store.to_h
    assert_equal owner_id, hash[:owner_id]
    assert_equal workflow_id, hash[:workflow_id]
    assert hash[:sections][:state_transitions].any?
  end

  speed_profile :fast
  test "persists and reloads state" do
    store.record_state_transition(from: :pending, to: :running, event: :start)
    store.record_decision(decision: "test", rationale: "rationale")

    # Create new store with same path
    reloaded = WorkflowMemoryStore.new(
      owner_id: owner_id,
      workflow_id: workflow_id,
      workflow_name: workflow_name,
      path: store.path
    )

    # JSON doesn't preserve symbols, so compare as strings
    assert_equal "running", reloaded.current_state.to_s
    assert_equal 1, reloaded.get_section(:decisions).size
  end

  # Parent memory query tests
  class MockParentMemory
    def initialize(sections = {})
      @sections = sections
    end

    def get_section(name)
      @sections[name.to_sym]
    end
  end

  speed_profile :fast
  test "query_parent returns empty hash without parent" do
    result = store.query_parent(:research_goal, :findings)
    assert_equal({}, result)
  end

  speed_profile :fast
  test "query_parent retrieves sections from parent" do
    parent = MockParentMemory.new(
      research_goal: [{ text: "Test Goal" }],
      findings: [{ text: "Finding 1" }]
    )

    store_with_parent = WorkflowMemoryStore.new(
      owner_id: owner_id,
      workflow_id: workflow_id,
      workflow_name: workflow_name,
      parent_memory: parent,
      path: File.join(temp_dir, "with_parent.json")
    )

    result = store_with_parent.query_parent(:research_goal, :findings)
    assert_equal [{ text: "Test Goal" }], result[:research_goal]
    assert_equal [{ text: "Finding 1" }], result[:findings]
  end

  speed_profile :fast
  test "query_parent_context gets compressed context" do
    parent = MockParentMemory.new(
      research_goal: [{ text: "Main Goal" }],
      context_chain: [{ key_insights: "insight 1" }]
    )

    store_with_parent = WorkflowMemoryStore.new(
      owner_id: owner_id,
      workflow_id: workflow_id,
      workflow_name: workflow_name,
      parent_memory: parent,
      path: File.join(temp_dir, "context.json")
    )

    result = store_with_parent.query_parent_context
    assert result[:research_goal].present?
  end

  # Merge tests
  class MockUpdatableParent
    attr_reader :sections

    def initialize
      @sections = Hash.new { |h, k| h[k] = [] }
    end

    def get_section(name)
      @sections[name.to_sym]
    end

    def update_section(name:, content:, append: false)
      if append
        @sections[name.to_sym] << content
      else
        @sections[name.to_sym] = [content]
      end
    end
  end

  speed_profile :fast
  test "merge_to_parent copies outputs to parent workflow_outputs section" do
    parent = MockUpdatableParent.new

    store_with_parent = WorkflowMemoryStore.new(
      owner_id: owner_id,
      workflow_id: workflow_id,
      workflow_name: workflow_name,
      parent_memory: parent,
      path: File.join(temp_dir, "merge.json")
    )

    store_with_parent.record_output({ result: "success" })
    store_with_parent.merge_to_parent(:outputs)

    # :outputs maps to :workflow_outputs in parent
    merged = parent.sections[:workflow_outputs]
    assert_equal 1, merged.size
    # Output data is nested under :output_data
    assert_equal "success", merged.first[:output_data][:result]
    assert_equal workflow_name, merged.first[:source_workflow]
  end

  # Isolation tests
  speed_profile :fast
  test "multiple workflow stores are isolated" do
    store1 = WorkflowMemoryStore.new(
      owner_id: owner_id,
      workflow_id: SecureRandom.uuid,
      workflow_name: "workflow_1",
      path: File.join(temp_dir, "store1.json")
    )

    store2 = WorkflowMemoryStore.new(
      owner_id: owner_id,
      workflow_id: SecureRandom.uuid,
      workflow_name: "workflow_2",
      path: File.join(temp_dir, "store2.json")
    )

    store1.record_state_transition(from: :pending, to: :running, event: :start)
    store2.record_state_transition(from: :pending, to: :failed, event: :fail)

    assert_equal :running, store1.current_state
    assert_equal :failed, store2.current_state
  end
end

