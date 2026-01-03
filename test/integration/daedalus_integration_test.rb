# frozen_string_literal: true

require "test_helper"

# Comprehensive integration test for Daedalus (Plan Agent Worker).
# Tests the full pipeline with real LLM calls (no mocking per @rules/no-llm-mocking.mdc).
#
# Following Cline pattern: codebase exploration happens DURING planning, not before.
#
# This test verifies:
# 1. Complete workflow execution (planning with embedded exploration → output)
# 2. Real LLM interaction with codebase exploration during planning
# 3. Proper file output creation
# 4. State machine transitions
# 5. Memory persistence
class DaedalusIntegrationTest < ActiveSupport::TestCase
  setup do
    @project_root = Rails.root.join("test/fixtures/example_codebase").to_s
    @test_id = SecureRandom.uuid
  end

  teardown do
    # Clean up any generated test files
    state_dir = Rails.root.join("tmp/state/workers/daedalus_worker/#{@test_id}")
    FileUtils.rm_rf(state_dir) if Dir.exist?(state_dir)
  end

  def integration_context
    context = Contexts::BaseContext.new
    context.add(
      content: "This is a Rails API project with translation services",
      topics: ["project_context"],
      source: "integration_test",
      metadata: { type: "hint" }
    )
    context
  end

  speed_profile :slow
  test "complete Daedalus workflow with real LLM integration" do
    worker = DaedalusWorker.new(
      goal: "Add comprehensive authentication system with password reset",
      path: @project_root,
      context: integration_context,
      owner_id: @test_id
    )

    # THIS HITS THE LLM FOR REAL - uses tools to explore during planning
    result = worker.execute

    # Verify worker reached completion
    assert worker.complete?, "Worker should reach complete state"

    # Verify result structure
    assert result.is_a?(Hash), "Result should be a hash"
    assert result[:success], "Execution should be successful"

    # Verify execution plan was generated
    assert result.key?(:execution_plan), "Result should contain execution_plan"
    execution_plan = result[:execution_plan]
    
    assert execution_plan.goal.include?("authentication"), "Plan goal should mention authentication"
    assert execution_plan.milestones.is_a?(Array), "Milestones should be an array"
    assert execution_plan.milestones.any?, "Should have at least one milestone"
    
    # Verify plan structure
    execution_plan.milestones.each do |milestone|
      assert milestone.title.present?, "Milestone should have a title"
      assert milestone.description.present?, "Milestone should have a description"
      assert milestone.steps.is_a?(Array), "Milestone should have steps"
      
      milestone.steps.each do |step|
        assert step.title.present?, "Step should have a title"
        assert step.intent.present?, "Step should have intent"
        assert step.details.is_a?(Array), "Step details should be an array"
        assert step.tests.is_a?(Array), "Step tests should be an array"
      end
    end

    # Verify output files were created
    assert result.key?(:output_paths), "Result should contain output_paths"
    paths = result[:output_paths]
    
    assert File.exist?(paths[:plan_path]), "Plan markdown file should exist"
    assert File.exist?(paths[:json_path]), "Plan JSON file should exist"
    assert File.exist?(paths[:metadata_path]), "Metadata JSON file should exist"

    # Verify metadata
    assert result.key?(:metadata), "Result should contain metadata"
    metadata = result[:metadata]
    assert_equal :complete, metadata[:final_state]
    assert metadata[:milestone_count] > 0
    assert metadata[:step_count] > 0

    Rails.logger.info("✅ Complete Daedalus workflow executed successfully")
    Rails.logger.info("   Final state: #{worker.current_state}")
    Rails.logger.info("   Milestones: #{execution_plan.milestone_count}")
    Rails.logger.info("   Steps: #{execution_plan.step_count}")
    Rails.logger.info("   Plan file: #{paths[:plan_path]}")
  end

  speed_profile :slow
  test "Daedalus handles plan generation workflow with real LLM and codebase exploration" do
    worker = DaedalusWorker.new(
      goal: "Refactor the translation service for better performance",
      path: @project_root,
      context: integration_context,
      owner_id: @test_id
    )

    # Execute worker initialization
    worker.trigger(:start)
    worker.initialize_worker

    workflow = PlanGenerationWorkflow.new(
      goal: worker.goal,
      path: worker.path,
      owner_id: worker.owner_id,
      parent_memory: worker.research_memory
    )

    # THIS HITS THE LLM FOR REAL - explores codebase during planning
    execution_plan = workflow.execute

    # Verify workflow completed successfully
    assert workflow.complete?

    # Verify execution plan structure
    assert_instance_of Planning::ExecutionPlan, execution_plan
    assert execution_plan.goal.include?("translation"), "Plan should mention translation"
    assert execution_plan.milestones.any?, "Should have at least one milestone"

    Rails.logger.info("✅ PlanGenerationWorkflow executed successfully with codebase exploration")
    Rails.logger.info("   Milestones: #{execution_plan.milestone_count}")
    Rails.logger.info("   Steps: #{execution_plan.step_count}")
  end

  speed_profile :fast
  test "Daedalus validates required parameters" do
    # Goal is required
    error = assert_raises(ArgumentError) do
      DaedalusWorker.new(
        goal: "",
        path: @project_root,
        context: integration_context
      )
    end
    assert_match(/goal/, error.message)

    # Path is required
    error = assert_raises(ArgumentError) do
      DaedalusWorker.new(
        goal: "Test goal",
        path: "",
        context: integration_context
      )
    end
    assert_match(/path/, error.message)
  end

  speed_profile :fast
  test "Daedalus initializes with correct state" do
    worker = DaedalusWorker.new(
      goal: "Test goal",
      path: @project_root,
      context: integration_context,
      owner_id: @test_id
    )

    assert worker.pending?, "Worker should start in pending state"
    assert_equal "Test goal", worker.goal
    assert_equal @project_root, worker.path
  end
end
