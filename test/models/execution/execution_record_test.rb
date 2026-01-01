# frozen_string_literal: true

require "test_helper"

module Execution
  class ExecutionRecordTest < ActiveSupport::TestCase
    def setup
      @step_result1 = create_step_result("1.1", true)
      @step_result2 = create_step_result("1.2", true)
      @step_result3 = create_step_result("2.1", false)
    end

    def create_step_result(step_id, success)
      StepResult.new(
        step_id: step_id,
        success: success,
        actions_taken: [],
        files_changed: success ? ["file_#{step_id}.rb"] : [],
        diffs: success ? { "file_#{step_id}.rb" => "+content" } : {}
      )
    end

    # ===== Initialization Tests =====
    speed_profile :fast
    test "initializes with required parameters" do
      record = ExecutionRecord.new(
        plan_id: "test_plan",
        step_results: [@step_result1],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      assert_equal "test_plan", record.plan_id
      assert_equal 1, record.step_results.size
      assert_equal "2025-01-01T00:00:00Z", record.started_at
      assert_equal :running, record.status
    end

    speed_profile :fast
    test "initializes with optional parameters" do
      record = ExecutionRecord.new(
        plan_id: "test_plan",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :complete,
        checkpoint_ids: ["abc123"],
        completed_at: "2025-01-01T01:00:00Z",
        milestones_completed: ["milestone_1"],
        error: nil,
        metadata: { worker_id: "123" },
        progress_events: [{ event: "started" }]
      )

      assert_equal ["abc123"], record.checkpoint_ids
      assert_equal "2025-01-01T01:00:00Z", record.completed_at
      assert_equal ["milestone_1"], record.milestones_completed
      assert_nil record.error
      assert_equal({ worker_id: "123" }, record.metadata)
      assert_equal [{ event: "started" }], record.progress_events
    end

    # ===== Validation Tests =====

    speed_profile :fast
    test "validates plan_id is a String" do
      error = assert_raises(ArgumentError) do
        ExecutionRecord.new(
          plan_id: 123,
          step_results: [],
          started_at: "2025-01-01T00:00:00Z",
          status: :running
        )
      end

      assert_match(/plan_id must be a String/, error.message)
    end

    speed_profile :fast
    test "validates plan_id is not empty" do
      error = assert_raises(ArgumentError) do
        ExecutionRecord.new(
          plan_id: "  ",
          step_results: [],
          started_at: "2025-01-01T00:00:00Z",
          status: :running
        )
      end

      assert_match(/plan_id cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates step_results is an Array" do
      error = assert_raises(ArgumentError) do
        ExecutionRecord.new(
          plan_id: "test",
          step_results: "not an array",
          started_at: "2025-01-01T00:00:00Z",
          status: :running
        )
      end

      assert_match(/step_results must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates step_results contains only StepResult instances" do
      error = assert_raises(TypeError) do
        ExecutionRecord.new(
          plan_id: "test",
          step_results: [@step_result1, "not a step result"],
          started_at: "2025-01-01T00:00:00Z",
          status: :running
        )
      end

      assert_match(/all step_results must be Execution::StepResult instances/, error.message)
    end

    speed_profile :fast
    test "validates started_at is a String" do
      error = assert_raises(ArgumentError) do
        ExecutionRecord.new(
          plan_id: "test",
          step_results: [],
          started_at: Time.now,
          status: :running
        )
      end

      assert_match(/started_at must be a String/, error.message)
    end

    speed_profile :fast
    test "validates status is valid" do
      error = assert_raises(ArgumentError) do
        ExecutionRecord.new(
          plan_id: "test",
          step_results: [],
          started_at: "2025-01-01T00:00:00Z",
          status: :invalid
        )
      end

      assert_match(/Invalid status: invalid/, error.message)
      assert_match(/running, complete, failed, partial/, error.message)
    end

    speed_profile :fast
    test "validates checkpoint_ids is an Array" do
      error = assert_raises(ArgumentError) do
        ExecutionRecord.new(
          plan_id: "test",
          step_results: [],
          started_at: "2025-01-01T00:00:00Z",
          status: :running,
          checkpoint_ids: "not an array"
        )
      end

      assert_match(/checkpoint_ids must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates checkpoint_ids contains only Strings" do
      error = assert_raises(TypeError) do
        ExecutionRecord.new(
          plan_id: "test",
          step_results: [],
          started_at: "2025-01-01T00:00:00Z",
          status: :running,
          checkpoint_ids: ["valid", 123]
        )
      end

      assert_match(/all checkpoint_ids must be Strings/, error.message)
    end

    speed_profile :fast
    test "validates milestones_completed contains only Strings" do
      error = assert_raises(TypeError) do
        ExecutionRecord.new(
          plan_id: "test",
          step_results: [],
          started_at: "2025-01-01T00:00:00Z",
          status: :running,
          milestones_completed: ["valid", 123]
        )
      end

      assert_match(/all milestones_completed must be Strings/, error.message)
    end

    speed_profile :fast
    test "validates metadata is a Hash" do
      error = assert_raises(ArgumentError) do
        ExecutionRecord.new(
          plan_id: "test",
          step_results: [],
          started_at: "2025-01-01T00:00:00Z",
          status: :running,
          metadata: []
        )
      end

      assert_match(/metadata must be a Hash/, error.message)
    end

    speed_profile :fast
    test "validates progress_events is an Array" do
      error = assert_raises(ArgumentError) do
        ExecutionRecord.new(
          plan_id: "test",
          step_results: [],
          started_at: "2025-01-01T00:00:00Z",
          status: :running,
          progress_events: "not an array"
        )
      end

      assert_match(/progress_events must be an Array/, error.message)
    end

    # ===== Mutation Methods Tests =====

    speed_profile :fast
    test "add_step_result adds a step result" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      result = record.add_step_result(@step_result1)

      assert_equal @step_result1, result
      assert_equal 1, record.step_results.size
      assert_includes record.step_results, @step_result1
    end

    speed_profile :fast
    test "add_step_result validates type" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      error = assert_raises(TypeError) do
        record.add_step_result("not a step result")
      end

      assert_match(/step_result must be an Execution::StepResult/, error.message)
    end

    speed_profile :fast
    test "add_checkpoint adds a checkpoint ID" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      result = record.add_checkpoint("abc123")

      assert_equal "abc123", result
      assert_includes record.checkpoint_ids, "abc123"
    end

    speed_profile :fast
    test "add_checkpoint validates type" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      error = assert_raises(ArgumentError) do
        record.add_checkpoint(123)
      end

      assert_match(/checkpoint_id must be a String/, error.message)
    end

    speed_profile :fast
    test "add_progress_event adds an event" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      event = { type: "step_started", step_id: "1.1" }
      result = record.add_progress_event(event)

      assert_equal event, result
      assert_includes record.progress_events, event
    end

    speed_profile :fast
    test "mark_milestone_completed marks milestone" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      result = record.mark_milestone_completed("milestone_1")

      assert_equal "milestone_1", result
      assert_includes record.milestones_completed, "milestone_1"
    end

    speed_profile :fast
    test "mark_milestone_completed does not duplicate" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      record.mark_milestone_completed("milestone_1")
      record.mark_milestone_completed("milestone_1")

      assert_equal 1, record.milestones_completed.count("milestone_1")
    end

    speed_profile :fast
    test "update_status updates status" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      record.update_status(:complete, completed_at: "2025-01-01T01:00:00Z")

      assert_equal :complete, record.status
      assert_equal "2025-01-01T01:00:00Z", record.completed_at
    end

    speed_profile :fast
    test "update_status validates status" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      error = assert_raises(ArgumentError) do
        record.update_status(:invalid)
      end

      assert_match(/Invalid status/, error.message)
    end

    # ===== Query Methods Tests =====

    speed_profile :fast
    test "total_steps returns count of step results" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [@step_result1, @step_result2, @step_result3],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      assert_equal 3, record.total_steps
    end

    speed_profile :fast
    test "completed_steps returns count of successful steps" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [@step_result1, @step_result2, @step_result3],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      assert_equal 2, record.completed_steps
    end

    speed_profile :fast
    test "failed_steps returns count of failed steps" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [@step_result1, @step_result2, @step_result3],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      assert_equal 1, record.failed_steps
    end

    speed_profile :fast
    test "progress_percentage calculates correctly" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [@step_result1, @step_result2, @step_result3],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      # 2 successful out of 3 total = 66.67%
      assert_equal 66.67, record.progress_percentage
    end

    speed_profile :fast
    test "progress_percentage returns 0 for no steps" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      assert_equal 0.0, record.progress_percentage
    end

    speed_profile :fast
    test "milestone_progress returns completed milestones" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :running,
        milestones_completed: ["m1", "m2"]
      )

      progress = record.milestone_progress

      assert_equal :completed, progress["m1"]
      assert_equal :completed, progress["m2"]
    end

    speed_profile :fast
    test "total_files_changed counts unique files" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [@step_result1, @step_result2],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      # Each step changes one unique file
      assert_equal 2, record.total_files_changed
    end

    speed_profile :fast
    test "all_diffs aggregates diffs from all steps" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [@step_result1, @step_result2],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      diffs = record.all_diffs

      assert_equal 2, diffs.keys.size
      assert_includes diffs.keys, "file_1.1.rb"
      assert_includes diffs.keys, "file_1.2.rb"
      assert_equal ["+content"], diffs["file_1.1.rb"]
    end

    speed_profile :fast
    test "duration calculates execution time" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :complete,
        completed_at: "2025-01-01T01:30:00Z"
      )

      # 1.5 hours = 5400 seconds
      assert_equal 5400.0, record.duration
    end

    speed_profile :fast
    test "duration returns nil if not completed" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      assert_nil record.duration
    end

    # ===== Status Query Methods Tests =====

    speed_profile :fast
    test "running? returns true when status is running" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :running
      )

      assert record.running?
    end

    speed_profile :fast
    test "complete? returns true when status is complete" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :complete
      )

      assert record.complete?
    end

    speed_profile :fast
    test "failed? returns true when status is failed" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :failed
      )

      assert record.failed?
    end

    speed_profile :fast
    test "partial? returns true when status is partial" do
      record = ExecutionRecord.new(
        plan_id: "test",
        step_results: [],
        started_at: "2025-01-01T00:00:00Z",
        status: :partial
      )

      assert record.partial?
    end

    # ===== Serialization Tests =====

    speed_profile :fast
    test "to_h serializes all attributes" do
      record = ExecutionRecord.new(
        plan_id: "test_plan",
        step_results: [@step_result1],
        started_at: "2025-01-01T00:00:00Z",
        status: :complete,
        checkpoint_ids: ["abc123"],
        completed_at: "2025-01-01T01:00:00Z",
        milestones_completed: ["m1"],
        error: nil,
        metadata: { worker_id: "123" },
        progress_events: [{ event: "started" }]
      )

      hash = record.to_h

      assert_equal "test_plan", hash[:plan_id]
      assert_equal 1, hash[:step_results].size
      assert_equal "2025-01-01T00:00:00Z", hash[:started_at]
      assert_equal :complete, hash[:status]
      assert_equal ["abc123"], hash[:checkpoint_ids]
      assert_equal "2025-01-01T01:00:00Z", hash[:completed_at]
      assert_equal ["m1"], hash[:milestones_completed]
      assert_nil hash[:error]
      assert_equal({ worker_id: "123" }, hash[:metadata])
      assert_equal [{ event: "started" }], hash[:progress_events]
    end

    speed_profile :fast
    test "from_h reconstructs ExecutionRecord" do
      hash = {
        plan_id: "test_plan",
        step_results: [@step_result1.to_h],
        started_at: "2025-01-01T00:00:00Z",
        status: :complete,
        checkpoint_ids: ["abc123"],
        completed_at: "2025-01-01T01:00:00Z",
        milestones_completed: ["m1"],
        error: nil,
        metadata: { worker_id: "123" },
        progress_events: [{ event: "started" }]
      }

      record = ExecutionRecord.from_h(hash)

      assert_equal "test_plan", record.plan_id
      assert_equal 1, record.step_results.size
      assert_instance_of StepResult, record.step_results.first
      assert_equal "2025-01-01T00:00:00Z", record.started_at
      assert_equal :complete, record.status
      assert_equal ["abc123"], record.checkpoint_ids
    end

    speed_profile :fast
    test "from_h handles string keys" do
      hash = {
        "plan_id" => "test_plan",
        "step_results" => [],
        "started_at" => "2025-01-01T00:00:00Z",
        "status" => "running"
      }

      record = ExecutionRecord.from_h(hash)

      assert_equal "test_plan", record.plan_id
      assert_equal :running, record.status
    end

    speed_profile :fast
    test "serialization round-trip preserves data" do
      original = ExecutionRecord.new(
        plan_id: "test_plan",
        step_results: [@step_result1, @step_result2],
        started_at: "2025-01-01T00:00:00Z",
        status: :complete,
        checkpoint_ids: ["abc123"],
        milestones_completed: ["m1"],
        metadata: { worker_id: "123" }
      )

      hash = original.to_h
      reconstructed = ExecutionRecord.from_h(hash)

      assert_equal original.plan_id, reconstructed.plan_id
      assert_equal original.step_results.size, reconstructed.step_results.size
      assert_equal original.started_at, reconstructed.started_at
      assert_equal original.status, reconstructed.status
      assert_equal original.checkpoint_ids, reconstructed.checkpoint_ids
      assert_equal original.milestones_completed, reconstructed.milestones_completed
    end
  end
end

