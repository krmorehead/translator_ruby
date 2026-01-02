# frozen_string_literal: true

require "test_helper"

class WorkflowMemoryStoreTest < ActiveSupport::TestCase
  let(:temp_dir) { create_temp_git_repo }
  
  let(:parent_memory) { build(:memory_store, base_dir: temp_dir) }
  
  let(:store) { build(:workflow_memory_store, base_dir: temp_dir, parent: parent_memory) }

  def teardown
    FileUtils.rm_rf(temp_dir) if temp_dir && File.exist?(temp_dir)
  end
  speed_profile :fast
  test "requires owner_id" do
    assert_raises(ArgumentError) do
      WorkflowMemoryStore.new(
        owner_id: nil,
        workflow_id: SecureRandom.uuid,
        workflow_name: "test",
        parent_id: parent_memory.id,
        path: File.join(temp_dir, "test.json")
      )
    end
  end

  speed_profile :fast
  test "requires workflow_id" do
    assert_raises(ArgumentError) do
      WorkflowMemoryStore.new(
        owner_id: parent_memory.owner_id,
        workflow_id: nil,
        workflow_name: "test",
        parent_id: parent_memory.id,
        path: File.join(temp_dir, "test.json")
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
    assert_equal store.workflow_name, summary[:workflow_name]
    assert_equal store.workflow_id, summary[:workflow_id]
    assert_equal store.owner_id, summary[:owner_id]
    assert_equal 1, summary[:transition_count]
    assert_equal 1, summary[:decision_count]
    assert_equal 0, summary[:error_count]
  end

  speed_profile :fast
  test "to_h serializes all data" do
    store.record_state_transition(from: :pending, to: :running, event: :start)

    hash = store.to_h
    assert_equal store.owner_id, hash[:owner_id]
    assert_equal store.workflow_id, hash[:workflow_id]
    assert hash[:sections][:state_transitions].any?
  end

  speed_profile :fast
  test "persists and reloads state" do
    store.record_state_transition(from: :pending, to: :running, event: :start)
    store.record_decision(decision: "test", rationale: "rationale")

    # Create new store with same path using existing parent_memory
    reloaded = WorkflowMemoryStore.new(
      owner_id: store.owner_id,
      workflow_id: store.workflow_id,
      workflow_name: store.workflow_name,
      parent_id: parent_memory.id,
      path: store.path
    )

    # JSON doesn't preserve symbols, so compare as strings
    assert_equal "running", reloaded.current_state.to_s
    assert_equal 1, reloaded.get_section(:decisions).size
  end

  # Context query tests
  speed_profile :fast
  test "query_context queries via graph service" do
    result = store.query_context(context_type: :goal, query_text: "test query")
    assert result.is_a?(Array)
  end

  # Merge tests
  speed_profile :fast
  test "merge_to_parent copies outputs to parent workflow_outputs section" do
    store.record_output({ result: "success" })
    store.merge_to_parent(:outputs)

    # :outputs maps to :workflow_outputs in parent
    merged = parent_memory.get_section(:workflow_outputs)
    assert_equal 1, merged.size
    # Output data is nested under :output_data
    assert_equal "success", merged.first[:output_data][:result]
    assert_equal store.workflow_name, merged.first[:source_workflow]
  end

  # Isolation tests
  speed_profile :fast
  test "multiple workflow stores are isolated" do
    parent1 = build(:memory_store, base_dir: temp_dir)
    parent2 = build(:memory_store, base_dir: temp_dir)
    
    store1 = build(:workflow_memory_store, base_dir: temp_dir, parent: parent1, workflow_name_value: "workflow_1")
    store2 = build(:workflow_memory_store, base_dir: temp_dir, parent: parent2, workflow_name_value: "workflow_2")

    store1.record_state_transition(from: :pending, to: :running, event: :start)
    store2.record_state_transition(from: :pending, to: :failed, event: :fail)

    assert_equal :running, store1.current_state
    assert_equal :failed, store2.current_state
  end
end

