# frozen_string_literal: true

require "test_helper"

class SisyphusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @test_dir = Rails.root.join("test", "tmp", "sisyphus_controller_test_#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(@test_dir)
    @test_project = File.join(@test_dir, "test_project")
    FileUtils.mkdir_p(@test_project)
    @test_plan = File.join(@test_dir, "test_plan.md")
    File.write(@test_plan, "# Test Plan\n\n## Milestone 1\n- Step 1\n")
    
    # Create approval store instance
    @approval_store = ApprovalRequestStore.new
  end

  teardown do
    FileUtils.rm_rf(@test_dir) if @test_dir && File.exist?(@test_dir)
  end

  # Execution Management Tests

  speed_profile :medium
  test "create_execution with valid params returns success" do
    post "/api/sisyphus/executions", params: {
      plan_path: @test_plan,
      project_path: @test_project,
      options: { dry_run: false, approval_mode: "autonomous" }
    }, as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert body["success"]
    assert body["execution_id"]
    assert body["state"]
    assert_equal "pending", body["state"]["status"]
  end

  speed_profile :fast
  test "create_execution with missing plan_path returns bad request" do
    post "/api/sisyphus/executions", params: {
      project_path: @test_project
    }, as: :json

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert body["error"]
  end

  speed_profile :fast
  test "create_execution with nonexistent plan_path returns bad request" do
    post "/api/sisyphus/executions", params: {
      plan_path: "/nonexistent/plan.md",
      project_path: @test_project
    }, as: :json

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert body["error"]
    assert_match(/not found/i, body["error"])
  end

  speed_profile :fast
  test "create_execution with nonexistent project_path returns bad request" do
    post "/api/sisyphus/executions", params: {
      plan_path: @test_plan,
      project_path: "/nonexistent/project"
    }, as: :json

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert body["error"]
    assert_match(/not found/i, body["error"])
  end

  speed_profile :fast
  test "show_execution returns execution state" do
    # Create a test execution state
    state = Execution::ExecutionState.new(
      execution_id: "test-123",
      plan_path: @test_plan,
      project_path: @test_project,
      status: :running,
      started_at: Time.now.utc.iso8601
    )
    state_store = ExecutionStateStore.new
    state_store.save(state)

    get "/api/sisyphus/executions/test-123"

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert body["state"]
    assert_equal "test-123", body["state"]["execution_id"]
  end

  speed_profile :fast
  test "show_execution with nonexistent id returns not found" do
    get "/api/sisyphus/executions/nonexistent-id"

    assert_response :not_found
    body = JSON.parse(response.body)
    assert body["error"]
    assert_match(/not found/i, body["error"])
  end

  speed_profile :fast
  test "list_executions returns array of executions" do
    get "/api/sisyphus/executions"

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert body["executions"].is_a?(Array)
    assert body["count"].is_a?(Integer)
  end

  speed_profile :fast
  test "list_executions respects limit parameter" do
    get "/api/sisyphus/executions", params: { limit: 10 }

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert body["executions"].is_a?(Array)
  end

  speed_profile :fast
  test "cancel_execution marks execution as failed" do
    # Create a running execution
    state = Execution::ExecutionState.new(
      execution_id: "test-cancel-123",
      plan_path: @test_plan,
      project_path: @test_project,
      status: :running,
      started_at: Time.now.utc.iso8601
    )
    state_store = ExecutionStateStore.new
    state_store.save(state)

    delete "/api/sisyphus/executions/test-cancel-123"

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert_equal "failed", body["state"]["status"]
    assert_match(/cancelled/i, body["state"]["error"])
  end

  speed_profile :fast
  test "cancel_execution returns error for nonexistent execution" do
    delete "/api/sisyphus/executions/nonexistent-id"

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert body["error"]
  end

  # Approval Endpoint Tests

  speed_profile :fast
  test "pending_approvals returns pending approval for execution" do
    # Use factory to create real instance with auto-generated UUIDs (OOP pattern)
    approval = build(:approval_request, :step, :pending)
    @approval_store.save(approval)

    get "/api/sisyphus/approvals/pending", params: { execution_id: approval.execution_id }

    assert_response :success
    body = JSON.parse(response.body)
    assert body["approval"]
    assert_equal approval.id, body["approval"]["id"]
    assert_equal "step", body["approval"]["type"]
    assert_equal "pending", body["approval"]["status"]
  end

  speed_profile :fast
  test "pending_approvals without execution_id returns bad request" do
    get "/api/sisyphus/approvals/pending"

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert body["error"]
    assert_match(/execution_id.*required/i, body["error"])
  end

  speed_profile :fast
  test "pending_approvals returns nil when no pending approvals" do
    get "/api/sisyphus/approvals/pending", params: { execution_id: "no-approvals" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_nil body["approval"]
  end

  speed_profile :fast
  test "show_approval returns approval request" do
    # Use factory - new() generates UUID automatically (OOP pattern)
    approval = build(:approval_request, :milestone)
    @approval_store.save(approval)

    get "/api/sisyphus/approvals/#{approval.id}"

    assert_response :success
    body = JSON.parse(response.body)
    assert body["approval"]
    assert_equal approval.id, body["approval"]["id"]
    assert_equal "milestone", body["approval"]["type"]
  end

  speed_profile :fast
  test "show_approval with nonexistent id returns not found" do
    get "/api/sisyphus/approvals/nonexistent"

    assert_response :not_found
    body = JSON.parse(response.body)
    assert body["error"]
    assert_match(/not found/i, body["error"])
  end

  speed_profile :fast
  test "approve_request approves pending request" do
    # Use factory - new() generates UUID automatically (OOP pattern)
    approval = build(:approval_request, :step)
    @approval_store.save(approval)

    post "/api/sisyphus/approvals/#{approval.id}/approve", params: {
      resolved_by: "test_user"
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert_equal "approved", body["approval"]["status"]
    assert_equal "test_user", body["approval"]["resolved_by"]
    assert body["approval"]["resolved_at"]
  end

  speed_profile :fast
  test "approve_request with nonexistent id returns not found" do
    post "/api/sisyphus/approvals/nonexistent/approve", as: :json

    assert_response :not_found
    body = JSON.parse(response.body)
    assert body["error"]
  end

  speed_profile :fast
  test "reject_request rejects pending request" do
    # Use factory - new() generates UUID automatically (OOP pattern)
    approval = build(:approval_request, :step)
    @approval_store.save(approval)

    post "/api/sisyphus/approvals/#{approval.id}/reject", params: {
      resolved_by: "test_user"
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert_equal "rejected", body["approval"]["status"]
    assert_equal "test_user", body["approval"]["resolved_by"]
    assert body["approval"]["resolved_at"]
  end

  speed_profile :fast
  test "reject_request with nonexistent id returns not found" do
    post "/api/sisyphus/approvals/nonexistent/reject", as: :json

    assert_response :not_found
    body = JSON.parse(response.body)
    assert body["error"]
  end

  # Filesystem Endpoint Tests

  speed_profile :fast
  test "file_tree returns directory contents" do
    get "/api/sisyphus/filesystem/tree", params: { path: @test_project }

    assert_response :success
    body = JSON.parse(response.body)
    assert body["data"]
  end

  speed_profile :fast
  test "file_tree with nonexistent path returns error" do
    get "/api/sisyphus/filesystem/tree", params: { path: "/nonexistent/path" }

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert body["error"]
  end

  speed_profile :fast
  test "read_file returns file contents" do
    test_file = File.join(@test_project, "test.txt")
    File.write(test_file, "test content")

    get "/api/sisyphus/filesystem/read", params: { path: test_file }

    assert_response :success
    body = JSON.parse(response.body)
    assert body["data"]
  end

  speed_profile :fast
  test "read_file with nonexistent path returns error" do
    get "/api/sisyphus/filesystem/read", params: { path: "/nonexistent/file.txt" }

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert body["error"]
  end

  speed_profile :fast
  test "search_files returns search results" do
    # Create a file to search
    test_file = File.join(@test_project, "searchable.txt")
    File.write(test_file, "searchable content")

    get "/api/sisyphus/filesystem/search", params: {
      pattern: "searchable",
      path: @test_project
    }

    assert_response :success
    body = JSON.parse(response.body)
    assert body["data"]
  end

  # Configuration Endpoint Tests

  speed_profile :fast
  test "show_config returns configuration" do
    get "/api/sisyphus/config"

    assert_response :success
    body = JSON.parse(response.body)
    assert body.key?("capabilities")
    assert body.key?("environment")
  end

  speed_profile :fast
  test "validate_config accepts capability params" do
    post "/api/sisyphus/config/validate", params: {
      name: "test_capability",
      model_name: "test_model",
      port: 8080
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    # Response structure depends on ConfigurationService implementation
    assert body.is_a?(Hash)
  end

  speed_profile :fast
  test "test_connection accepts capability name" do
    post "/api/sisyphus/config/test", params: {
      capability_name: "planning"
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body.is_a?(Hash)
  end

  speed_profile :fast
  test "test_connection without capability_name returns error" do
    post "/api/sisyphus/config/test", as: :json

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert body["error"]
  end
end

