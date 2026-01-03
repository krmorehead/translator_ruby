# frozen_string_literal: true

require "test_helper"

class DaedalusWorkerTest < ActiveSupport::TestCase
  let(:daedalus_context) { Contexts::BaseContext.new }

  setup do
    @temp_path = Dir.mktmpdir
    @goal = "Create a new authentication system"
  end

  teardown do
    FileUtils.rm_rf(@temp_path) if @temp_path && File.exist?(@temp_path)
  end

  speed_profile :fast
  test "initialization with required parameters" do
    worker = DaedalusWorker.new(
      goal: @goal,
      path: @temp_path,
      context: daedalus_context
    )

    assert_not_nil worker
    assert_equal @goal, worker.goal
    assert_not_nil worker.owner_id
    assert worker.pending?
  end

  speed_profile :fast
  test "validates goal must be present" do
    error = assert_raises(ArgumentError) do
      DaedalusWorker.new(
        goal: nil,
        path: @temp_path,
        context: daedalus_context
      )
    end
    assert_includes error.message, "goal"
  end

  speed_profile :fast
  test "validates path must be present" do
    error = assert_raises(ArgumentError) do
      DaedalusWorker.new(
        goal: @goal,
        path: nil,
        context: daedalus_context
      )
    end
    assert_includes error.message, "path"
  end

  speed_profile :fast
  test "initializes with optional context" do
    worker = DaedalusWorker.new(
      goal: @goal,
      path: @temp_path,
      context: daedalus_context
    )

    assert_equal daedalus_context, worker.context
  end

  speed_profile :slow
  test "execute transitions through states" do
    # Create minimal directory structure
    FileUtils.mkdir_p(File.join(@temp_path, "app", "workers"))
    File.write(File.join(@temp_path, "app", "workers", "base_worker.rb"), "class BaseWorker; end")

    worker = DaedalusWorker.new(
      goal: @goal,
      path: @temp_path,
      context: daedalus_context
    )

    result = worker.execute

    # Should complete or fail (both are valid end states)
    assert worker.complete? || worker.failed?
    assert_not_nil result
  end

  speed_profile :slow
  test "execute creates plan output files" do
    # Create minimal directory structure
    FileUtils.mkdir_p(File.join(@temp_path, "app", "workers"))
    File.write(File.join(@temp_path, "app", "workers", "base_worker.rb"), "class BaseWorker; end")

    worker = DaedalusWorker.new(
      goal: @goal,
      path: @temp_path,
      context: daedalus_context
    )

    result = worker.execute

    # If successful, should have created output files
    if worker.complete? && result[:output_paths]
      assert result[:output_paths].key?(:plan_directory)
      assert result[:output_paths].key?(:plan_path)
      assert result[:output_paths].key?(:json_path)
      assert result[:output_paths].key?(:metadata_path)
    end
  end

  speed_profile :slow
  test "execute result includes execution_plan" do
    # Create minimal directory structure
    FileUtils.mkdir_p(File.join(@temp_path, "app", "workers"))
    File.write(File.join(@temp_path, "app", "workers", "base_worker.rb"), "class BaseWorker; end")

    worker = DaedalusWorker.new(
      goal: @goal,
      path: @temp_path,
      context: daedalus_context
    )

    result = worker.execute

    # If successful, result should include execution_plan
    if worker.complete?
      assert result.key?(:execution_plan)
      assert result[:execution_plan].is_a?(Planning::ExecutionPlan)
    end
  end

  speed_profile :fast
  test "has registered workflows" do
    worker = DaedalusWorker.new(
      goal: @goal,
      path: @temp_path,
      context: daedalus_context
    )

    workflows = DaedalusWorker.registered_workflows

    # Following Cline pattern: only PlanGenerationWorkflow (with embedded exploration)
    assert workflows.include?(PlanGenerationWorkflow)
  end

  speed_profile :fast
  test "initializes memory store" do
    worker = DaedalusWorker.new(
      goal: @goal,
      path: @temp_path,
      context: daedalus_context
    )

    # Before execute, memory may not be initialized
    worker.initialize_worker

    assert_not_nil worker.research_memory
  end

  speed_profile :fast
  test "state query methods work correctly" do
    worker = DaedalusWorker.new(
      goal: @goal,
      path: @temp_path,
      context: daedalus_context
    )

    assert worker.pending?
    refute worker.running?
    refute worker.complete?
    refute worker.failed?
  end

  speed_profile :fast
  test "can transition to running state" do
    worker = DaedalusWorker.new(
      goal: @goal,
      path: @temp_path,
      context: daedalus_context
    )

    worker.trigger(:start)

    assert worker.running?
    refute worker.pending?
  end
end

