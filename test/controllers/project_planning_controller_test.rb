# frozen_string_literal: true

require "test_helper"

class ProjectPlanningControllerTest < ActionDispatch::IntegrationTest
  include ResearchTestFactory

  # Shared execution result - runs once per test process
  class << self
    attr_accessor :shared_response, :shared_json, :shared_computed
  end

  def shared_create_request
    return [self.class.shared_response, self.class.shared_json] if self.class.shared_computed

    post "/project_planning/create", params: {
      goal: "Add logging to Calculator",
      path: FIXTURE_PATH,
      project_name: "calculator_logging"
    }, as: :json

    self.class.shared_response = response
    self.class.shared_json = response.body.present? ? JSON.parse(response.body) : {}
    self.class.shared_computed = true
    [response, self.class.shared_json]
  end

  # ============================================================================
  # Validation Tests - No LLM calls
  # ============================================================================
  speed_profile :fast
  test "create returns 422 with missing goal" do
    post "/project_planning/create", params: {
      path: FIXTURE_PATH,
      project_name: "test_project"
    }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_includes json["error"], "goal"
  end

  speed_profile :fast
  test "create returns 422 with missing path" do
    post "/project_planning/create", params: {
      goal: "Test goal",
      project_name: "test_project"
    }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_includes json["error"], "path"
  end

  speed_profile :fast
  test "create returns 422 with missing project_name" do
    post "/project_planning/create", params: {
      goal: "Test goal",
      path: FIXTURE_PATH
    }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_includes json["error"], "project_name"
  end

  speed_profile :fast
  test "create returns 422 with invalid path" do
    post "/project_planning/create", params: {
      goal: "Test goal",
      path: "/nonexistent/path/to/nowhere",
      project_name: "test_project"
    }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_includes json["error"], "path"
  end

  # ============================================================================
  # Shared Execution Tests - All use same LLM call
  # OOP: These tests share a single LLM call result via shared_create_request,
  #      but the first test to run will make the actual call, which can take >60s.
  #      Mark all as :slow to allow 120s SLA.
  # ============================================================================

  speed_profile :slow
  test "shared: create returns 200 with valid params" do
    resp, json = shared_create_request
    assert_equal true, json["success"], "Planning should succeed: #{json['error']}"
    assert_equal 200, resp.status
  end

  speed_profile :slow
  test "shared: response includes success boolean" do
    _resp, json = shared_create_request
    assert_equal true, json["success"], "Planning should succeed: #{json['error']}"
    assert json.key?("success")
  end

  speed_profile :slow
  test "shared: response includes file paths" do
    _resp, json = shared_create_request
    assert_equal true, json["success"], "Planning should succeed: #{json['error']}"

    assert json.key?("project_path")
    assert json.key?("file_references_path")
    assert json.key?("project_plan_path")
  end

  speed_profile :slow
  test "shared: response includes milestones" do
    _resp, json = shared_create_request
    assert_equal true, json["success"], "Planning should succeed: #{json['error']}"

    assert json.key?("milestones")
    assert_kind_of Array, json["milestones"]
  end

  speed_profile :slow
  test "shared: response includes research_summary" do
    _resp, json = shared_create_request
    assert_equal true, json["success"], "Planning should succeed: #{json['error']}"

    assert json.key?("research_summary")
  end

  speed_profile :slow
  test "shared: response includes existing and planned files" do
    _resp, json = shared_create_request
    assert_equal true, json["success"], "Planning should succeed: #{json['error']}"

    assert json.key?("existing_files")
    assert json.key?("planned_files")
  end
end
