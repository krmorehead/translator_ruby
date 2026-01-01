# frozen_string_literal: true

require "test_helper"

# Tests for the new smaller planning prompts
class PlanningPromptsTest < ActiveSupport::TestCase
  # Shared milestone result - runs once per test process
  class << self
    attr_accessor :milestone_result, :milestone_computed
    attr_accessor :step_result, :step_computed
    attr_accessor :detail_result, :detail_computed
  end

  def shared_milestone_execution
    return self.class.milestone_result if self.class.milestone_computed

    prompt = Planning::MilestoneConsensusPrompt.new
    result = prompt.generate(
      goal: "Add logging to Calculator",
      research_summary: "Calculator class has add/subtract methods"
    )

    self.class.milestone_result = result
    self.class.milestone_computed = true
    result
  end

  def shared_step_execution
    return self.class.step_result if self.class.step_computed

    prompt = Planning::StepBreakdownPrompt.new
    result = prompt.generate(
      milestone_title: "Add logging infrastructure",
      milestone_description: "Set up logging system",
      goal: "Add logging to Calculator"
    )

    self.class.step_result = result
    self.class.step_computed = true
    result
  end

  def shared_detail_execution
    return self.class.detail_result if self.class.detail_computed

    prompt = Planning::StepDetailPrompt.new
    result = prompt.generate(
      step_title: "Create logger configuration",
      step_intent: "Set up logging to capture operations",
      milestone_title: "Add logging infrastructure",
      goal: "Add logging to Calculator"
    )

    self.class.detail_result = result
    self.class.detail_computed = true
    result
  end

  # Helper to get value from hash regardless of key type
  def get_val(hash, key)
    return nil unless hash
    hash[key.to_s] || hash[key.to_sym]
  end

  # ============================================================================
  # MilestoneConsensusPrompt Tests
  # ============================================================================
  speed_profile :fast
  test "MilestoneConsensusPrompt inherits from BasePlanningPrompt" do
    assert Planning::MilestoneConsensusPrompt < Planning::BasePlanningPrompt
  end

  speed_profile :fast
  test "MilestoneConsensusPrompt has system_prompt" do
    prompt = Planning::MilestoneConsensusPrompt.new
    assert prompt.system_prompt.present?
  end

  speed_profile :medium
  test "MilestoneConsensusPrompt returns milestones" do
    result = shared_milestone_execution
    content = get_val(result, :content)
    assert content.present?, "Should have content: #{result.inspect}"

    milestones = get_val(content, :milestones)
    assert milestones.present?, "Should have milestones"
    assert_kind_of Array, milestones
    assert milestones.any?, "Should have at least one milestone"
  end

  speed_profile :medium
  test "MilestoneConsensusPrompt milestones have title and description" do
    result = shared_milestone_execution
    content = get_val(result, :content)
    milestones = get_val(content, :milestones)
    assert milestones.any?, "Should have milestones"

    milestone = milestones.first
    assert get_val(milestone, :title).present?, "Should have title"
    assert get_val(milestone, :description).present?, "Should have description"
  end

  # ============================================================================
  # StepBreakdownPrompt Tests
  # ============================================================================

  speed_profile :fast
  test "StepBreakdownPrompt inherits from BasePlanningPrompt" do
    assert Planning::StepBreakdownPrompt < Planning::BasePlanningPrompt
  end

  speed_profile :medium
  test "StepBreakdownPrompt returns steps" do
    result = shared_step_execution
    content = get_val(result, :content)
    assert content.present?, "Should have content: #{result.inspect}"

    steps = get_val(content, :steps)
    assert steps.present?, "Should have steps"
    assert_kind_of Array, steps
  end

  speed_profile :medium
  test "StepBreakdownPrompt steps have title and intent" do
    result = shared_step_execution
    content = get_val(result, :content)
    steps = get_val(content, :steps)
    assert steps.any?, "Should have steps"

    step = steps.first
    assert get_val(step, :title).present?, "Should have title"
    assert get_val(step, :intent).present?, "Should have intent"
  end

  # ============================================================================
  # StepDetailPrompt Tests
  # ============================================================================

  speed_profile :fast
  test "StepDetailPrompt inherits from BasePlanningPrompt" do
    assert Planning::StepDetailPrompt < Planning::BasePlanningPrompt
  end

  speed_profile :medium
  test "StepDetailPrompt returns details and tests" do
    result = shared_detail_execution
    content = get_val(result, :content)
    assert content.present?, "Should have content: #{result.inspect}"

    details = get_val(content, :details)
    tests = get_val(content, :tests)
    assert_kind_of Array, details
    assert_kind_of Array, tests
  end
end
