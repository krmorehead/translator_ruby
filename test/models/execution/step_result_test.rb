# frozen_string_literal: true

require "test_helper"

module Execution
  class StepResultTest < ActiveSupport::TestCase
    # ===== Initialization Tests =====

    test "initializes with required parameters" do
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: [],
        files_changed: ["app/models/user.rb"],
        diffs: { "app/models/user.rb" => "+class User\n+end" }
      )

      assert_equal "1.1", result.step_id
      assert result.success
      assert_equal [], result.actions_taken
      assert_equal ["app/models/user.rb"], result.files_changed
      assert_equal({ "app/models/user.rb" => "+class User\n+end" }, result.diffs)
    end

    test "initializes with optional parameters" do
      evaluation = { passed: true, confidence: 0.95 }
      
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: [],
        files_changed: [],
        diffs: {},
        tool_outputs: { test: "output" },
        error_message: nil,
        duration: 1.5,
        executed_at: "2025-01-01T00:00:00Z",
        evaluation_result: evaluation,
        validation_warnings: ["Warning 1"]
      )

      assert_equal({ test: "output" }, result.tool_outputs)
      assert_nil result.error_message
      assert_equal 1.5, result.duration
      assert_equal "2025-01-01T00:00:00Z", result.executed_at
      assert_equal evaluation, result.evaluation_result
      assert_equal ["Warning 1"], result.validation_warnings
    end

    test "sets executed_at to current time if not provided" do
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: [],
        files_changed: [],
        diffs: {}
      )

      assert_not_nil result.executed_at
      assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, result.executed_at)
    end

    # ===== Validation Tests =====

    test "validates step_id is a String" do
      error = assert_raises(ArgumentError) do
        StepResult.new(
          step_id: 123,
          success: true,
          actions_taken: [],
          files_changed: [],
          diffs: {}
        )
      end

      assert_match(/step_id must be a String/, error.message)
    end

    test "validates step_id is not empty" do
      error = assert_raises(ArgumentError) do
        StepResult.new(
          step_id: "  ",
          success: true,
          actions_taken: [],
          files_changed: [],
          diffs: {}
        )
      end

      assert_match(/step_id cannot be empty/, error.message)
    end

    test "validates success is a Boolean" do
      error = assert_raises(ArgumentError) do
        StepResult.new(
          step_id: "1.1",
          success: "true",
          actions_taken: [],
          files_changed: [],
          diffs: {}
        )
      end

      assert_match(/success must be a Boolean/, error.message)
    end

    test "validates actions_taken is an Array" do
      error = assert_raises(ArgumentError) do
        StepResult.new(
          step_id: "1.1",
          success: true,
          actions_taken: "not an array",
          files_changed: [],
          diffs: {}
        )
      end

      assert_match(/actions_taken must be an Array/, error.message)
    end

    test "validates files_changed is an Array" do
      error = assert_raises(ArgumentError) do
        StepResult.new(
          step_id: "1.1",
          success: true,
          actions_taken: [],
          files_changed: "not an array",
          diffs: {}
        )
      end

      assert_match(/files_changed must be an Array/, error.message)
    end

    test "validates files_changed contains only Strings" do
      error = assert_raises(TypeError) do
        StepResult.new(
          step_id: "1.1",
          success: true,
          actions_taken: [],
          files_changed: ["valid.rb", 123],
          diffs: {}
        )
      end

      assert_match(/all files_changed must be Strings/, error.message)
    end

    test "validates diffs is a Hash" do
      error = assert_raises(ArgumentError) do
        StepResult.new(
          step_id: "1.1",
          success: true,
          actions_taken: [],
          files_changed: [],
          diffs: []
        )
      end

      assert_match(/diffs must be a Hash/, error.message)
    end

    test "validates diffs keys are Strings" do
      error = assert_raises(TypeError) do
        StepResult.new(
          step_id: "1.1",
          success: true,
          actions_taken: [],
          files_changed: [],
          diffs: { 123 => "diff content" }
        )
      end

      assert_match(/all diff keys must be Strings/, error.message)
    end

    test "validates diffs values are Strings" do
      error = assert_raises(TypeError) do
        StepResult.new(
          step_id: "1.1",
          success: true,
          actions_taken: [],
          files_changed: [],
          diffs: { "file.rb" => 123 }
        )
      end

      assert_match(/all diff values must be Strings/, error.message)
    end

    test "validates tool_outputs is a Hash" do
      error = assert_raises(ArgumentError) do
        StepResult.new(
          step_id: "1.1",
          success: true,
          actions_taken: [],
          files_changed: [],
          diffs: {},
          tool_outputs: []
        )
      end

      assert_match(/tool_outputs must be a Hash/, error.message)
    end

    test "validates validation_warnings is an Array" do
      error = assert_raises(ArgumentError) do
        StepResult.new(
          step_id: "1.1",
          success: true,
          actions_taken: [],
          files_changed: [],
          diffs: {},
          validation_warnings: "not an array"
        )
      end

      assert_match(/validation_warnings must be an Array/, error.message)
    end

    # ===== Query Methods Tests =====

    test "successful? returns true when success is true" do
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: [],
        files_changed: [],
        diffs: {}
      )

      assert result.successful?
    end

    test "successful? returns false when success is false" do
      result = StepResult.new(
        step_id: "1.1",
        success: false,
        actions_taken: [],
        files_changed: [],
        diffs: {}
      )

      refute result.successful?
    end

    test "failed? returns true when success is false" do
      result = StepResult.new(
        step_id: "1.1",
        success: false,
        actions_taken: [],
        files_changed: [],
        diffs: {}
      )

      assert result.failed?
    end

    test "failed? returns false when success is true" do
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: [],
        files_changed: [],
        diffs: {}
      )

      refute result.failed?
    end

    test "file_count returns number of files changed" do
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: [],
        files_changed: ["file1.rb", "file2.rb", "file3.rb"],
        diffs: {}
      )

      assert_equal 3, result.file_count
    end

    test "action_count returns number of actions taken" do
      actions = [
        { tool: "write_file", params: {} },
        { tool: "bash", params: {} }
      ]
      
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: actions,
        files_changed: [],
        diffs: {}
      )

      assert_equal 2, result.action_count
    end

    test "has_diffs? returns true when diffs present" do
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: [],
        files_changed: [],
        diffs: { "file.rb" => "+content" }
      )

      assert result.has_diffs?
    end

    test "has_diffs? returns false when no diffs" do
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: [],
        files_changed: [],
        diffs: {}
      )

      refute result.has_diffs?
    end

    test "diff_for returns diff for specific file" do
      diffs = {
        "file1.rb" => "+content1",
        "file2.rb" => "+content2"
      }
      
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: [],
        files_changed: [],
        diffs: diffs
      )

      assert_equal "+content1", result.diff_for("file1.rb")
      assert_equal "+content2", result.diff_for("file2.rb")
    end

    test "diff_for returns nil for non-existent file" do
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: [],
        files_changed: [],
        diffs: {}
      )

      assert_nil result.diff_for("nonexistent.rb")
    end

    # ===== Formatted Summary Tests =====

    test "formatted_summary shows success status" do
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: [{ tool: "write_file" }],
        files_changed: ["file.rb"],
        diffs: {},
        duration: 1.5
      )

      summary = result.formatted_summary

      assert_includes summary, "Step 1.1: SUCCESS"
      assert_includes summary, "Actions: 1"
      assert_includes summary, "Files changed: 1"
      assert_includes summary, "Duration: 1.5s"
    end

    test "formatted_summary shows failure status" do
      result = StepResult.new(
        step_id: "1.1",
        success: false,
        actions_taken: [],
        files_changed: [],
        diffs: {},
        error_message: "File write failed"
      )

      summary = result.formatted_summary

      assert_includes summary, "Step 1.1: FAILED"
      assert_includes summary, "Error: File write failed"
    end

    test "formatted_summary includes evaluation result" do
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: [],
        files_changed: [],
        diffs: {},
        evaluation_result: { passed: true, confidence: 0.95 }
      )

      summary = result.formatted_summary

      assert_includes summary, "Evaluation: PASSED"
      assert_includes summary, "Confidence: 0.95"
    end

    test "formatted_summary includes validation warnings" do
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: [],
        files_changed: [],
        diffs: {},
        validation_warnings: ["Warning 1", "Warning 2"]
      )

      summary = result.formatted_summary

      assert_includes summary, "Warnings: 2"
    end

    # ===== Serialization Tests =====

    test "to_h serializes all attributes" do
      actions = [{ tool: "write_file", params: {} }]
      evaluation = { passed: true, confidence: 0.95 }
      
      result = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: actions,
        files_changed: ["file.rb"],
        diffs: { "file.rb" => "+content" },
        tool_outputs: { test: "output" },
        error_message: nil,
        duration: 1.5,
        executed_at: "2025-01-01T00:00:00Z",
        evaluation_result: evaluation,
        validation_warnings: ["Warning"]
      )

      hash = result.to_h

      assert_equal "1.1", hash[:step_id]
      assert_equal true, hash[:success]
      assert_equal actions, hash[:actions_taken]
      assert_equal ["file.rb"], hash[:files_changed]
      assert_equal({ "file.rb" => "+content" }, hash[:diffs])
      assert_equal({ test: "output" }, hash[:tool_outputs])
      assert_nil hash[:error_message]
      assert_equal 1.5, hash[:duration]
      assert_equal "2025-01-01T00:00:00Z", hash[:executed_at]
      assert_equal evaluation, hash[:evaluation_result]
      assert_equal ["Warning"], hash[:validation_warnings]
    end

    test "from_h reconstructs StepResult from hash" do
      hash = {
        step_id: "1.1",
        success: true,
        actions_taken: [{ tool: "write_file" }],
        files_changed: ["file.rb"],
        diffs: { "file.rb" => "+content" },
        tool_outputs: { test: "output" },
        error_message: nil,
        duration: 1.5,
        executed_at: "2025-01-01T00:00:00Z",
        evaluation_result: { passed: true },
        validation_warnings: ["Warning"]
      }

      result = StepResult.from_h(hash)

      assert_equal "1.1", result.step_id
      assert result.success
      assert_equal [{ tool: "write_file" }], result.actions_taken
      assert_equal ["file.rb"], result.files_changed
      assert_equal({ "file.rb" => "+content" }, result.diffs)
      assert_equal({ test: "output" }, result.tool_outputs)
      assert_nil result.error_message
      assert_equal 1.5, result.duration
      assert_equal "2025-01-01T00:00:00Z", result.executed_at
      assert_equal({ passed: true }, result.evaluation_result)
      assert_equal ["Warning"], result.validation_warnings
    end

    test "from_h handles string keys" do
      hash = {
        "step_id" => "1.1",
        "success" => true,
        "actions_taken" => [],
        "files_changed" => [],
        "diffs" => {}
      }

      result = StepResult.from_h(hash)

      assert_equal "1.1", result.step_id
      assert result.success
    end

    test "from_h validates hash parameter" do
      error = assert_raises(ArgumentError) do
        StepResult.from_h("not a hash")
      end

      assert_match(/hash must be a Hash/, error.message)
    end

    test "serialization round-trip preserves data" do
      original = StepResult.new(
        step_id: "1.1",
        success: true,
        actions_taken: [{ tool: "write_file" }],
        files_changed: ["file.rb"],
        diffs: { "file.rb" => "+content" },
        tool_outputs: { test: "output" },
        duration: 1.5,
        evaluation_result: { passed: true },
        validation_warnings: ["Warning"]
      )

      hash = original.to_h
      reconstructed = StepResult.from_h(hash)

      assert_equal original.step_id, reconstructed.step_id
      assert_equal original.success, reconstructed.success
      assert_equal original.actions_taken, reconstructed.actions_taken
      assert_equal original.files_changed, reconstructed.files_changed
      assert_equal original.diffs, reconstructed.diffs
      assert_equal original.tool_outputs, reconstructed.tool_outputs
      assert_equal original.duration, reconstructed.duration
      assert_equal original.evaluation_result, reconstructed.evaluation_result
      assert_equal original.validation_warnings, reconstructed.validation_warnings
    end
  end
end

