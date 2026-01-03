# frozen_string_literal: true

require "test_helper"

class PlanOutputServiceTest < ActiveSupport::TestCase
  setup do
    @temp_base_path = Dir.mktmpdir
    @goal = "Create a PlanAgentWorker"
  end

  teardown do
    FileUtils.rm_rf(@temp_base_path) if @temp_base_path && File.exist?(@temp_base_path)
  end

  speed_profile :fast
  test "initialization with required parameters" do
    step = Planning::PlanStep.new(
      title: "Step 1",
      intent: "Intent",
      details: ["detail"],
      tests: ["test"]
    )
    milestone = Planning::PlanMilestone.new(
      title: "Milestone 1",
      description: "Description",
      steps: [step]
    )
    execution_plan = Planning::ExecutionPlan.new(
      goal: @goal,
      milestones: [milestone]
    )

    service = PlanOutputService.new(
      execution_plan: execution_plan,
      base_path: @temp_base_path
    )

    assert_not_nil service
    assert_equal execution_plan, service.execution_plan
    assert_equal @temp_base_path, service.base_path
  end

  speed_profile :fast
  test "validates execution_plan must be an ExecutionPlan" do
    error = assert_raises(ArgumentError) do
      PlanOutputService.new(
        execution_plan: "not a plan",
        base_path: @temp_base_path
      )
    end
    assert_match(/execution_plan must be an ExecutionPlan/, error.message)
  end

  speed_profile :fast
  test "validates base_path must be a String" do
    step = Planning::PlanStep.new(
      title: "Step 1",
      intent: "Intent",
      details: ["detail"],
      tests: ["test"]
    )
    milestone = Planning::PlanMilestone.new(
      title: "Milestone 1",
      description: "Description",
      steps: [step]
    )
    execution_plan = Planning::ExecutionPlan.new(
      goal: @goal,
      milestones: [milestone]
    )

    error = assert_raises(ArgumentError) do
      PlanOutputService.new(
        execution_plan: execution_plan,
        base_path: 123
      )
    end
    assert_match(/base_path must be a String/, error.message)
  end

  speed_profile :fast
  test "write creates output directory" do
    step = Planning::PlanStep.new(
      title: "Step 1",
      intent: "Intent",
      details: ["detail"],
      tests: ["test"]
    )
    milestone = Planning::PlanMilestone.new(
      title: "Milestone 1",
      description: "Description",
      steps: [step]
    )
    execution_plan = Planning::ExecutionPlan.new(
      goal: @goal,
      milestones: [milestone]
    )

    service = PlanOutputService.new(
      execution_plan: execution_plan,
      base_path: @temp_base_path
    )

    result = service.write

    assert Dir.exist?(result[:plan_directory])
    assert result[:plan_directory].start_with?(@temp_base_path)
  end

  speed_profile :fast
  test "write creates plan.md file" do
    step = Planning::PlanStep.new(
      title: "Step 1",
      intent: "Intent",
      details: ["detail"],
      tests: ["test"]
    )
    milestone = Planning::PlanMilestone.new(
      title: "Milestone 1",
      description: "Description",
      steps: [step]
    )
    execution_plan = Planning::ExecutionPlan.new(
      goal: @goal,
      milestones: [milestone]
    )

    service = PlanOutputService.new(
      execution_plan: execution_plan,
      base_path: @temp_base_path
    )

    result = service.write

    assert File.exist?(result[:plan_path])
    content = File.read(result[:plan_path])
    assert_includes content, @goal
    assert_includes content, "Milestone 1"
    assert_includes content, "Step 1"
  end

  speed_profile :fast
  test "write creates plan.json file" do
    step = Planning::PlanStep.new(
      title: "Step 1",
      intent: "Intent",
      details: ["detail"],
      tests: ["test"]
    )
    milestone = Planning::PlanMilestone.new(
      title: "Milestone 1",
      description: "Description",
      steps: [step]
    )
    execution_plan = Planning::ExecutionPlan.new(
      goal: @goal,
      milestones: [milestone]
    )

    service = PlanOutputService.new(
      execution_plan: execution_plan,
      base_path: @temp_base_path
    )

    result = service.write

    assert File.exist?(result[:json_path])
    content = File.read(result[:json_path])
    json = JSON.parse(content, symbolize_names: true)
    assert_equal @goal, json[:goal]
    assert_equal 1, json[:milestones].size
  end

  speed_profile :fast
  test "write creates metadata.json file" do
    step = Planning::PlanStep.new(
      title: "Step 1",
      intent: "Intent",
      details: ["detail"],
      tests: ["test"]
    )
    milestone = Planning::PlanMilestone.new(
      title: "Milestone 1",
      description: "Description",
      steps: [step]
    )
    execution_plan = Planning::ExecutionPlan.new(
      goal: @goal,
      milestones: [milestone]
    )

    service = PlanOutputService.new(
      execution_plan: execution_plan,
      base_path: @temp_base_path
    )

    result = service.write

    assert File.exist?(result[:metadata_path])
    content = File.read(result[:metadata_path])
    json = JSON.parse(content, symbolize_names: true)
    assert_equal @goal, json[:goal]
    assert_not_nil json[:created_at]
  end

  speed_profile :fast
  test "plan.md has proper markdown formatting" do
    step = Planning::PlanStep.new(
      title: "Create Worker Class",
      intent: "Build the main worker",
      details: ["Extend BaseWorker", "Add state machine"],
      tests: ["Test initialization", "Test state transitions"]
    )
    milestone = Planning::PlanMilestone.new(
      title: "Core Infrastructure",
      description: "Build foundational classes",
      steps: [step]
    )
    execution_plan = Planning::ExecutionPlan.new(
      goal: @goal,
      milestones: [milestone]
    )

    service = PlanOutputService.new(
      execution_plan: execution_plan,
      base_path: @temp_base_path
    )

    result = service.write
    content = File.read(result[:plan_path])

    # Check for proper markdown headers
    assert_includes content, "# Execution Plan"
    assert_includes content, "## Goal"
    assert_includes content, "## Milestone 1: Core Infrastructure"
    assert_includes content, "### 1.1 - Create Worker Class"
    
    # Check for details and tests sections
    assert_includes content, "**Details**:"
    assert_includes content, "**Tests**:"
    assert_includes content, "- Extend BaseWorker"
    assert_includes content, "- Test initialization"
  end

  speed_profile :fast
  test "directory name includes timestamp and sanitized goal" do
    step = Planning::PlanStep.new(
      title: "Step 1",
      intent: "Intent",
      details: ["detail"],
      tests: ["test"]
    )
    milestone = Planning::PlanMilestone.new(
      title: "Milestone 1",
      description: "Description",
      steps: [step]
    )
    execution_plan = Planning::ExecutionPlan.new(
      goal: "Create a PlanAgentWorker!",
      milestones: [milestone]
    )

    service = PlanOutputService.new(
      execution_plan: execution_plan,
      base_path: @temp_base_path
    )

    result = service.write

    directory_name = File.basename(result[:plan_directory])
    
    # Should start with timestamp
    assert_match(/^\d{2}-\d{2}-\d{4}_/, directory_name)
    
    # Should include sanitized goal (no special chars)
    assert_includes directory_name, "create_a_planagentworker"
  end

  speed_profile :fast
  test "returns hash with all file paths" do
    step = Planning::PlanStep.new(
      title: "Step 1",
      intent: "Intent",
      details: ["detail"],
      tests: ["test"]
    )
    milestone = Planning::PlanMilestone.new(
      title: "Milestone 1",
      description: "Description",
      steps: [step]
    )
    execution_plan = Planning::ExecutionPlan.new(
      goal: @goal,
      milestones: [milestone]
    )

    service = PlanOutputService.new(
      execution_plan: execution_plan,
      base_path: @temp_base_path
    )

    result = service.write

    assert result.key?(:plan_directory)
    assert result.key?(:plan_path)
    assert result.key?(:json_path)
    assert result.key?(:metadata_path)
  end

  speed_profile :fast
  test "handles existing directories" do
    step = Planning::PlanStep.new(
      title: "Step 1",
      intent: "Intent",
      details: ["detail"],
      tests: ["test"]
    )
    milestone = Planning::PlanMilestone.new(
      title: "Milestone 1",
      description: "Description",
      steps: [step]
    )
    execution_plan = Planning::ExecutionPlan.new(
      goal: @goal,
      milestones: [milestone]
    )

    service = PlanOutputService.new(
      execution_plan: execution_plan,
      base_path: @temp_base_path
    )

    # Write once
    result1 = service.write
    
    # Write again (should not error)
    result2 = service.write

    assert File.exist?(result2[:plan_path])
    assert File.exist?(result2[:json_path])
    assert File.exist?(result2[:metadata_path])
  end

  speed_profile :fast
  test "plan includes constraints assumptions and risks when present" do
    step = Planning::PlanStep.new(
      title: "Step 1",
      intent: "Intent",
      details: ["detail"],
      tests: ["test"]
    )
    milestone = Planning::PlanMilestone.new(
      title: "Milestone 1",
      description: "Description",
      steps: [step]
    )
    execution_plan = Planning::ExecutionPlan.new(
      goal: @goal,
      milestones: [milestone],
      constraints: ["Follow OOP patterns"],
      assumptions: ["Rails available"],
      risks: ["May take time"]
    )

    service = PlanOutputService.new(
      execution_plan: execution_plan,
      base_path: @temp_base_path
    )

    result = service.write
    content = File.read(result[:plan_path])

    assert_includes content, "## Constraints"
    assert_includes content, "Follow OOP patterns"
    assert_includes content, "## Assumptions"
    assert_includes content, "Rails available"
    assert_includes content, "## Risks"
    assert_includes content, "May take time"
  end
end








