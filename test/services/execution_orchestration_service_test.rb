# frozen_string_literal: true

require "test_helper"

class ExecutionOrchestrationServiceTest < ActiveSupport::TestCase
  def setup
    @service = ExecutionOrchestrationService.new
    @test_dir = Rails.root.join("test", "tmp", "execution_orchestration_test")
    FileUtils.mkdir_p(@test_dir)
    @test_project = File.join(@test_dir, "test_project")
    Dir.mkdir(@test_project) unless Dir.exist?(@test_project)
    @test_plan = File.join(@test_dir, "test_plan.md")
    File.write(@test_plan, "# Test Plan\n\nTest content")
  end

  teardown do
    FileUtils.rm_rf(@test_dir)
  end

  speed_profile :fast
  test "initializes successfully" do
    assert_instance_of ExecutionOrchestrationService, @service
  end

  # start_execution tests
  speed_profile :medium
  test "start_execution returns success with execution_id and state" do
    result = @service.start_execution(
      plan_path: @test_plan,
      project_path: @test_project
    )

    assert result[:success]
    assert result[:execution_id]
    assert result[:state]
    assert_equal :pending, result[:state][:status]
  end

  speed_profile :fast
  test "start_execution validates plan_path is a String" do
    assert_raises(ArgumentError) do
      @service.start_execution(
        plan_path: 123,
        project_path: @test_project
      )
    end
  end

  speed_profile :fast
  test "start_execution validates plan_path exists" do
    assert_raises(ArgumentError) do
      @service.start_execution(
        plan_path: "/nonexistent/plan.md",
        project_path: @test_project
      )
    end
  end

  speed_profile :fast
  test "start_execution validates project_path is a String" do
    assert_raises(ArgumentError) do
      @service.start_execution(
        plan_path: @test_plan,
        project_path: nil
      )
    end
  end

  speed_profile :fast
  test "start_execution validates project_path exists" do
    assert_raises(ArgumentError) do
      @service.start_execution(
        plan_path: @test_plan,
        project_path: "/nonexistent/project"
      )
    end
  end

  # get_execution_state tests
  speed_profile :fast
  test "get_execution_state returns success with state" do
    result = @service.get_execution_state(execution_id: "test-123")

    assert result[:success]
    assert result[:state]
    assert result[:state][:execution_id]
  end

  speed_profile :fast
  test "get_execution_state validates execution_id is a String" do
    assert_raises(ArgumentError) do
      @service.get_execution_state(execution_id: 123)
    end
  end

  speed_profile :fast
  test "get_execution_state validates execution_id is not empty" do
    assert_raises(ArgumentError) do
      @service.get_execution_state(execution_id: "  ")
    end
  end

  # list_executions tests
  speed_profile :fast
  test "list_executions returns success with executions array" do
    result = @service.list_executions

    assert result[:success]
    assert result[:executions].is_a?(Array)
    assert result[:count].is_a?(Integer)
  end

  speed_profile :fast
  test "list_executions respects limit parameter" do
    result = @service.list_executions(limit: 10)

    assert result[:success]
  end

  # cancel_execution tests
  speed_profile :fast
  test "cancel_execution returns success" do
    result = @service.cancel_execution(execution_id: "test-123")

    assert result[:success]
    assert result[:message]
  end

  speed_profile :fast
  test "cancel_execution validates execution_id is a String" do
    assert_raises(ArgumentError) do
      @service.cancel_execution(execution_id: nil)
    end
  end

  speed_profile :fast
  test "cancel_execution validates execution_id is not empty" do
    assert_raises(ArgumentError) do
      @service.cancel_execution(execution_id: "")
    end
  end
end

