# frozen_string_literal: true

require "test_helper"

module Execution
  class ExecutionStateTest < ActiveSupport::TestCase
    def setup
      @valid_params = {
        execution_id: "test-exec-123",
        plan_path: "/path/to/plan.md",
        project_path: "/path/to/project",
        status: ExecutionState::PENDING,
        started_at: Time.now.utc.iso8601
      }
    end

    speed_profile :fast
    test "initializes with valid parameters" do
      state = ExecutionState.new(**@valid_params)

      assert_equal "test-exec-123", state.execution_id
      assert_equal "/path/to/plan.md", state.plan_path
      assert_equal "/path/to/project", state.project_path
      assert_equal :pending, state.status
    end

    speed_profile :fast
    test "has default values for optional parameters" do
      state = ExecutionState.new(**@valid_params)

      assert_nil state.current_milestone
      assert_nil state.current_step
      assert_equal 0.0, state.progress_percentage
      assert_empty state.files_changed
      assert_empty state.checkpoint_ids
      assert_nil state.completed_at
      assert_nil state.error
    end

    speed_profile :fast
    test "validates execution_id must be a String" do
      error = assert_raises(ArgumentError) do
        ExecutionState.new(**@valid_params.merge(execution_id: 123))
      end
      assert_match(/execution_id must be a String/, error.message)
    end

    speed_profile :fast
    test "validates execution_id cannot be empty" do
      error = assert_raises(ArgumentError) do
        ExecutionState.new(**@valid_params.merge(execution_id: "  "))
      end
      assert_match(/execution_id cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates plan_path must be a String" do
      error = assert_raises(ArgumentError) do
        ExecutionState.new(**@valid_params.merge(plan_path: 123))
      end
      assert_match(/plan_path must be a String/, error.message)
    end

    speed_profile :fast
    test "validates project_path must be a String" do
      error = assert_raises(ArgumentError) do
        ExecutionState.new(**@valid_params.merge(project_path: nil))
      end
      assert_match(/project_path must be a String/, error.message)
    end

    speed_profile :fast
    test "validates status must be a Symbol" do
      error = assert_raises(ArgumentError) do
        ExecutionState.new(**@valid_params.merge(status: "pending"))
      end
      assert_match(/status must be a Symbol/, error.message)
    end

    speed_profile :fast
    test "validates status must be valid" do
      error = assert_raises(ArgumentError) do
        ExecutionState.new(**@valid_params.merge(status: :invalid_status))
      end
      assert_match(/Invalid status/, error.message)
    end

    speed_profile :fast
    test "validates progress_percentage must be Numeric" do
      error = assert_raises(ArgumentError) do
        ExecutionState.new(**@valid_params.merge(progress_percentage: "50"))
      end
      assert_match(/progress_percentage must be Numeric/, error.message)
    end

    speed_profile :fast
    test "validates progress_percentage must be between 0 and 100" do
      error = assert_raises(ArgumentError) do
        ExecutionState.new(**@valid_params.merge(progress_percentage: 150))
      end
      assert_match(/progress_percentage must be between 0 and 100/, error.message)
    end

    speed_profile :fast
    test "validates files_changed must be an Array" do
      error = assert_raises(ArgumentError) do
        ExecutionState.new(**@valid_params.merge(files_changed: "file.rb"))
      end
      assert_match(/files_changed must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates checkpoint_ids must be an Array" do
      error = assert_raises(ArgumentError) do
        ExecutionState.new(**@valid_params.merge(checkpoint_ids: "checkpoint1"))
      end
      assert_match(/checkpoint_ids must be an Array/, error.message)
    end

    speed_profile :fast
    test "running? returns true for running status" do
      state = ExecutionState.new(**@valid_params.merge(status: ExecutionState::RUNNING))

      assert state.running?
      refute state.complete?
      refute state.failed?
      refute state.pending?
    end

    speed_profile :fast
    test "complete? returns true for complete status" do
      state = ExecutionState.new(**@valid_params.merge(status: ExecutionState::COMPLETE))

      assert state.complete?
      refute state.running?
      refute state.failed?
      refute state.pending?
    end

    speed_profile :fast
    test "failed? returns true for failed status" do
      state = ExecutionState.new(**@valid_params.merge(status: ExecutionState::FAILED))

      assert state.failed?
      refute state.running?
      refute state.complete?
      refute state.pending?
    end

    speed_profile :fast
    test "pending? returns true for pending status" do
      state = ExecutionState.new(**@valid_params)

      assert state.pending?
      refute state.running?
      refute state.complete?
      refute state.failed?
    end

    speed_profile :fast
    test "to_h serializes all attributes" do
      state = ExecutionState.new(
        **@valid_params.merge(
          current_milestone: "Milestone 1",
          current_step: "Step 1",
          progress_percentage: 45.5,
          files_changed: ["file1.rb", "file2.rb"],
          checkpoint_ids: ["checkpoint1"],
          completed_at: Time.now.utc.iso8601,
          error: "Test error"
        )
      )

      hash = state.to_h

      assert_equal "test-exec-123", hash[:execution_id]
      assert_equal "/path/to/plan.md", hash[:plan_path]
      assert_equal "/path/to/project", hash[:project_path]
      assert_equal :pending, hash[:status]
      assert_equal "Milestone 1", hash[:current_milestone]
      assert_equal "Step 1", hash[:current_step]
      assert_equal 45.5, hash[:progress_percentage]
      assert_equal ["file1.rb", "file2.rb"], hash[:files_changed]
      assert_equal ["checkpoint1"], hash[:checkpoint_ids]
      assert hash[:completed_at]
      assert_equal "Test error", hash[:error]
    end

    speed_profile :fast
    test "from_h deserializes from hash" do
      hash = {
        execution_id: "test-123",
        plan_path: "/plan.md",
        project_path: "/project",
        status: :running,
        current_milestone: "M1",
        current_step: "S1",
        progress_percentage: 50.0,
        files_changed: ["f1.rb"],
        checkpoint_ids: ["c1"],
        started_at: Time.now.utc.iso8601,
        completed_at: nil,
        error: nil
      }

      state = ExecutionState.from_h(hash)

      assert_equal "test-123", state.execution_id
      assert_equal "/plan.md", state.plan_path
      assert_equal :running, state.status
      assert_equal 50.0, state.progress_percentage
    end

    speed_profile :fast
    test "from_h handles string keys and string status" do
      hash = {
        "execution_id" => "test-123",
        "plan_path" => "/plan.md",
        "project_path" => "/project",
        "status" => "running",
        "started_at" => Time.now.utc.iso8601
      }

      state = ExecutionState.from_h(hash)

      assert_equal :running, state.status
    end

    speed_profile :fast
    test "from_h validates hash parameter" do
      error = assert_raises(ArgumentError) do
        ExecutionState.from_h("not a hash")
      end
      assert_match(/hash must be a Hash/, error.message)
    end

    speed_profile :fast
    test "round-trip serialization preserves data" do
      original = ExecutionState.new(
        **@valid_params.merge(
          current_milestone: "Test Milestone",
          progress_percentage: 75.3,
          files_changed: ["test.rb"]
        )
      )

      hash = original.to_h
      restored = ExecutionState.from_h(hash)

      assert_equal original.execution_id, restored.execution_id
      assert_equal original.plan_path, restored.plan_path
      assert_equal original.status, restored.status
      assert_equal original.current_milestone, restored.current_milestone
      assert_equal original.progress_percentage, restored.progress_percentage
      assert_equal original.files_changed, restored.files_changed
    end
  end
end








