# frozen_string_literal: true

require "test_helper"

class ProjectPlannerIntegrationTest < ActiveSupport::TestCase
  include ResearchTestFactory

  # Shared execution result - runs once per test process
  class << self
    attr_accessor :shared_result, :shared_worker, :shared_computed
  end

  def shared_execution
    return [self.class.shared_worker, self.class.shared_result] if self.class.shared_computed

    worker = ProjectPlannerWorker.new(
      goal: "Add logging to Calculator",
      path: FIXTURE_PATH,
      project_name: "calculator_logging",
      max_research_depth: 1
    )
    result = worker.execute

    self.class.shared_worker = worker
    self.class.shared_result = result
    self.class.shared_computed = true

    [worker, result]
  end

  def teardown
    # Clean up generated project directory after tests
    if self.class.shared_computed && self.class.shared_result
      project_path = self.class.shared_result[:project_path]
      if project_path && File.exist?(project_path)
        FileUtils.rm_rf(project_path)
      end
    end
  end

  # Helper to get milestones with proper key handling (symbols or strings)
  def get_milestones(result)
    result[:milestones] || result["milestones"] || []
  end

  # Helper to get value from hash regardless of key type
  def get_val(hash, key)
    hash[key.to_s] || hash[key.to_sym]
  end

  # ============================================================================
  # Full Pipeline Tests - All use same LLM call
  # ============================================================================
  speed_profile :slow
  test "shared: full planning flow produces valid output" do
    _worker, result = shared_execution

    assert result[:success], "Planning should succeed: #{result[:error]}"
    assert_not_nil result[:project_path]
    assert_not_nil result[:file_references_path]
    assert_not_nil result[:project_plan_path]
  end

  speed_profile :slow
  test "shared: output files are created" do
    _worker, result = shared_execution
    assert result[:success], "Planning should succeed: #{result[:error]}"

    assert File.exist?(result[:project_path])
    assert File.exist?(result[:file_references_path])
    assert File.exist?(result[:project_plan_path])
  end

  speed_profile :slow
  test "shared: file_references.md has expected structure" do
    _worker, result = shared_execution
    assert result[:success], "Planning should succeed: #{result[:error]}"

    content = File.read(result[:file_references_path])

    # Should have markdown headers
    assert_includes content, "# File References"
    assert_includes content, "## Existing Files"
    assert_includes content, "## Planned Files"
  end

  speed_profile :slow
  test "shared: project_plan.md has correct milestone structure" do
    _worker, result = shared_execution
    assert result[:success], "Planning should succeed: #{result[:error]}"

    content = File.read(result[:project_plan_path])

    # Should have project plan headers and milestone structure
    assert_includes content, "# Project Plan"
    assert_match(/## Milestone \d+/, content)
  end

  speed_profile :slow
  test "shared: milestones have steps" do
    _worker, result = shared_execution
    assert result[:success], "Planning should succeed: #{result[:error]}"

    milestones = get_milestones(result)
    assert milestones.any?, "Should have at least one milestone"

    first_milestone = milestones.first
    steps = get_val(first_milestone, :steps) || []
    assert steps.any?, "Milestone should have steps"
  end

  speed_profile :slow
  test "shared: steps have required fields" do
    _worker, result = shared_execution
    assert result[:success], "Planning should succeed: #{result[:error]}"

    milestones = get_milestones(result)
    assert milestones.any?, "Should have milestones"

    steps = get_val(milestones.first, :steps) || []
    assert steps.any?, "Should have steps"

    first_step = steps.first
    assert get_val(first_step, :number).present?, "Step should have number"
    assert get_val(first_step, :title).present?, "Step should have title"
    assert get_val(first_step, :intent).present?, "Step should have intent"

    details = get_val(first_step, :details) || []
    tests = get_val(first_step, :tests) || []
    assert details.any?, "Step should have details"
    assert tests.any?, "Step should have tests"
  end

  speed_profile :slow
  test "shared: existing_files are detected" do
    _worker, result = shared_execution
    assert result[:success], "Planning should succeed: #{result[:error]}"

    existing_files = result[:existing_files] || result["existing_files"] || []
    assert existing_files.any?, "Should detect existing files"

    # Should include calculator.rb from fixtures
    paths = existing_files.map { |f| get_val(f, :path) }
    has_calculator = paths.any? { |p| p&.include?("calculator") }
    assert has_calculator, "Should include calculator.rb"
  end

  speed_profile :slow
  test "shared: project directory follows naming convention" do
    _worker, result = shared_execution
    assert result[:success], "Planning should succeed: #{result[:error]}"

    project_dir = File.basename(result[:project_path])
    # Should match pattern: MM-DD-YYYY_project_name
    assert_match(/\d{2}-\d{2}-\d{4}_calculator_logging/, project_dir)
  end

  speed_profile :slow
  test "shared: metadata includes workflow results" do
    _worker, result = shared_execution
    assert result[:success], "Planning should succeed: #{result[:error]}"

    assert_not_nil result[:metadata]
    assert_equal :complete, result[:metadata][:final_state]
  end

  speed_profile :slow
  test "shared: worker ends in complete state" do
    worker, result = shared_execution
    assert result[:success], "Planning should succeed: #{result[:error]}"

    assert worker.complete?
    assert_equal :complete, worker.current_state
  end

  speed_profile :slow
  test "shared: research summary is populated" do
    _worker, result = shared_execution
    assert result[:success], "Planning should succeed: #{result[:error]}"

    assert_not_nil result[:research_summary]
  end
end
