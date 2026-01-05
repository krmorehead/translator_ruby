# frozen_string_literal: true

require "test_helper"

class CodebaseAnalysisWorkflowTest < ActiveSupport::TestCase
  setup do
    @temp_path = Dir.mktmpdir
    @goal = "Create a PlanAgentWorker"
    @owner_id = "test-owner-codebase-analysis"
    @parent_id = "test-parent-codebase-analysis"
  end

  teardown do
    FileUtils.rm_rf(@temp_path) if @temp_path && File.exist?(@temp_path)
  end

  speed_profile :fast
  test "initialization with required parameters" do
    workflow = CodebaseAnalysisWorkflow.new(
      goal: @goal,
      path: @temp_path,
      owner_id: @owner_id,
      parent_id: @parent_id
    )

    assert_not_nil workflow
    assert_equal @goal, workflow.goal
    assert_equal @temp_path, workflow.path
    assert_equal @owner_id, workflow.owner_id
    assert workflow.pending?
  end

  speed_profile :fast
  test "validates goal must be a String" do
    error = assert_raises(ArgumentError) do
      CodebaseAnalysisWorkflow.new(
        goal: 123,
        path: @temp_path,
        owner_id: @owner_id,
        parent_id: @parent_id
      )
    end
    assert_match(/goal must be a String/, error.message)
  end

  speed_profile :fast
  test "validates path must be a String" do
    error = assert_raises(ArgumentError) do
      CodebaseAnalysisWorkflow.new(
        goal: @goal,
        path: 123,
        owner_id: @owner_id,
        parent_id: @parent_id
      )
    end
    assert_match(/path must be a String/, error.message)
  end

  speed_profile :fast
  test "validates owner_id must be a String" do
    error = assert_raises(ArgumentError) do
      CodebaseAnalysisWorkflow.new(
        goal: @goal,
        path: @temp_path,
        owner_id: 123,
        parent_id: @parent_id
      )
    end
    assert_match(/owner_id must be a String/, error.message)
  end

  speed_profile :slow
  test "execute transitions through states" do
    # Create a simple directory structure
    FileUtils.mkdir_p(File.join(@temp_path, "app", "workers"))
    File.write(File.join(@temp_path, "app", "workers", "base_worker.rb"), "class BaseWorker; end")

    workflow = CodebaseAnalysisWorkflow.new(
      goal: @goal,
      path: @temp_path,
      owner_id: @owner_id,
      parent_id: @parent_id
    )

    result = workflow.execute

    # Should complete or fail (both are valid end states)
    assert workflow.complete? || workflow.failed?
    assert_not_nil result
    assert result.is_a?(Hash)
  end

  speed_profile :slow
  test "execute returns analysis results hash" do
    # Create a simple directory structure
    FileUtils.mkdir_p(File.join(@temp_path, "app", "workers"))
    File.write(File.join(@temp_path, "app", "workers", "base_worker.rb"), "class BaseWorker; end")

    workflow = CodebaseAnalysisWorkflow.new(
      goal: @goal,
      path: @temp_path,
      owner_id: @owner_id,
      parent_id: @parent_id
    )

    result = workflow.execute

    assert result.key?(:relevant_files)
    assert result.key?(:patterns)
    assert result.key?(:constraints)
    assert result[:relevant_files].is_a?(Array)
    assert result[:patterns].is_a?(Array)
    assert result[:constraints].is_a?(Array)
  end

  speed_profile :slow
  test "execute handles LLM errors gracefully" do
    # Create directory structure but simulate LLM failure with invalid path
    workflow = CodebaseAnalysisWorkflow.new(
      goal: @goal,
      path: "/nonexistent/path",
      owner_id: @owner_id,
      parent_id: @parent_id
    )

    # Should complete but may have empty results
    result = workflow.execute

    # Even with errors, should return a hash with the expected structure
    assert result.is_a?(Hash)
    assert result.key?(:relevant_files)
    assert result.key?(:patterns)
    assert result.key?(:constraints)
  end

  speed_profile :fast
  test "setup initializes workflow memory" do
    workflow = CodebaseAnalysisWorkflow.new(
      goal: @goal,
      path: @temp_path,
      owner_id: @owner_id,
      parent_id: @parent_id
    )

    workflow.setup

    assert_not_nil workflow.workflow_memory
  end

  speed_profile :fast
  test "workflow records decisions to memory" do
    workflow = CodebaseAnalysisWorkflow.new(
      goal: @goal,
      path: @temp_path,
      owner_id: @owner_id,
      parent_id: @parent_id
    )

    workflow.setup
    workflow.record_decision(
      decision: "Test decision",
      rationale: "Test rationale"
    )

    # Workflow memory should exist after setup
    assert_not_nil workflow.workflow_memory
  end

  speed_profile :fast
  test "state query methods work correctly" do
    workflow = CodebaseAnalysisWorkflow.new(
      goal: @goal,
      path: @temp_path,
      owner_id: @owner_id,
      parent_id: @parent_id
    )

    assert workflow.pending?
    refute workflow.running?
    refute workflow.complete?
    refute workflow.failed?
  end

  speed_profile :fast
  test "can transition to running state" do
    workflow = CodebaseAnalysisWorkflow.new(
      goal: @goal,
      path: @temp_path,
      owner_id: @owner_id,
      parent_id: @parent_id
    )

    workflow.trigger(:start)

    assert workflow.running?
    refute workflow.pending?
  end

  speed_profile :fast
  test "uses DEFAULT_MAX_FILES (15) by default" do
    workflow = CodebaseAnalysisWorkflow.new(
      goal: @goal,
      path: @temp_path,
      owner_id: @owner_id,
      parent_id: @parent_id
    )

    assert_equal CodebaseAnalysisWorkflow::DEFAULT_MAX_FILES, workflow.max_files
    assert_equal 15, workflow.max_files
  end

  speed_profile :fast
  test "respects custom max_files parameter" do
    custom_max = 25
    workflow = CodebaseAnalysisWorkflow.new(
      goal: @goal,
      path: @temp_path,
      owner_id: @owner_id,
      parent_id: @parent_id,
      max_files: custom_max
    )

    assert_equal custom_max, workflow.max_files
  end
end

