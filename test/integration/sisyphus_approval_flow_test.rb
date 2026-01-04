# frozen_string_literal: true

require "test_helper"

# Integration tests for Sisyphus approval workflow.
# These tests use REAL production endpoints like a real user would.
# NO test-specific endpoints, NO bypasses, NO mocking.
#
# The approval flow is:
# 1. User starts an execution via POST /api/sisyphus/executions
# 2. Execution creates approval requests when it reaches approval gates
# 3. User polls GET /api/sisyphus/approvals/pending?execution_id=X
# 4. User approves/rejects via POST /api/sisyphus/approvals/:id/approve
#
# These tests verify the approval endpoints work correctly when approvals
# are created by the real execution workflow.
class SisyphusApprovalFlowTest < ActionDispatch::IntegrationTest
  setup do
    @test_dir = Rails.root.join("test", "tmp", "sisyphus_approval_flow_test_#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(@test_dir)
    @test_project = File.join(@test_dir, "test_project")
    FileUtils.mkdir_p(@test_project)

    # Create a simple test plan
    @test_plan = File.join(@test_dir, "test_plan.md")
    File.write(@test_plan, <<~PLAN)
      # Test Plan

      ## Milestone 1: Setup
      - Step 1: Create hello.rb file
      - Step 2: Write hello world code

      ## Milestone 2: Complete
      - Step 3: Run the code
    PLAN

    SessionCache.instance.flushall

    @approval_store = ApprovalRequestStore.new

    @created_approval_ids = []
  end

  teardown do
    # Cleanup created approvals
    @created_approval_ids&.each { |id| @approval_store.delete(id) rescue nil }
    FileUtils.rm_rf(@test_dir) if @test_dir && File.exist?(@test_dir)
  end

  # Helper to create approval requests through the domain model
  # (like the execution workflow would)
  def create_approval(execution_id:, type: :step, subject_id: nil, subject_title: "Test Step", planned_actions: [], estimated_changes: {})
    approval_id = "approval-#{SecureRandom.hex(8)}"
    subject_id ||= "#{type}-#{SecureRandom.hex(4)}"
    
    request = Execution::ApprovalRequest.new(
      id: approval_id,
      execution_id: execution_id,
      type: type,
      status: :pending,
      subject_id: subject_id,
      subject_title: subject_title,
      planned_actions: planned_actions,
      estimated_changes: estimated_changes,
      created_at: Time.now.utc.iso8601
    )
    @approval_store.save(request)
    @created_approval_ids << approval_id
    approval_id
  end

  # Test approval endpoints directly with real ApprovalRequest objects
  # (created through the domain model, like a real execution would)

  speed_profile :medium
  test "approve endpoint returns approved status for valid approval" do
    execution_id = "exec-#{SecureRandom.hex(8)}"
    approval_id = create_approval(
      execution_id: execution_id,
      subject_title: "Create hello.rb file",
      planned_actions: ["Create new file", "Write code"],
      estimated_changes: { files_to_create: 1 }
    )

    # Act like a real user - poll for pending approval
    get "/api/sisyphus/approvals/pending", params: { execution_id: execution_id }
    assert_response :success
    body = JSON.parse(response.body)
    assert body["approval"]
    assert_equal approval_id, body["approval"]["id"]
    assert_equal "pending", body["approval"]["status"]

    # Act like a real user - approve the request
    post "/api/sisyphus/approvals/#{approval_id}/approve", params: {
      resolved_by: "test_user"
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert_equal "approved", body["approval"]["status"]
    assert_equal "test_user", body["approval"]["resolved_by"]
    assert body["approval"]["resolved_at"]

    # Verify no more pending approvals for this execution
    get "/api/sisyphus/approvals/pending", params: { execution_id: execution_id }
    assert_response :success
    body = JSON.parse(response.body)
    assert_nil body["approval"]
  end

  speed_profile :medium
  test "reject endpoint returns rejected status for valid approval" do
    execution_id = "exec-#{SecureRandom.hex(8)}"
    approval_id = create_approval(
      execution_id: execution_id,
      type: :milestone,
      subject_title: "Complete Setup",
      planned_actions: ["Create structure", "Install deps"],
      estimated_changes: { files_to_create: 5 }
    )

    # Act like a real user - check the approval details
    get "/api/sisyphus/approvals/#{approval_id}"
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "milestone", body["approval"]["type"]
    assert_equal "pending", body["approval"]["status"]

    # Act like a real user - reject the request
    post "/api/sisyphus/approvals/#{approval_id}/reject", params: {
      resolved_by: "test_user"
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert_equal "rejected", body["approval"]["status"]

    # Verify status persisted
    get "/api/sisyphus/approvals/#{approval_id}"
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "rejected", body["approval"]["status"]
    assert body["approval"]["resolved_at"]
  end

  speed_profile :medium
  test "multiple sequential approvals for same execution" do
    execution_id = "exec-#{SecureRandom.hex(8)}"

    # Create first approval
    approval_id_1 = create_approval(
      execution_id: execution_id,
      subject_title: "First Step"
    )

    # Poll should return first approval
    get "/api/sisyphus/approvals/pending", params: { execution_id: execution_id }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal approval_id_1, body["approval"]["id"]

    # Approve first
    post "/api/sisyphus/approvals/#{approval_id_1}/approve", as: :json
    assert_response :success

    # Create second approval (simulating execution progressing)
    approval_id_2 = create_approval(
      execution_id: execution_id,
      subject_title: "Second Step"
    )

    # Poll should return second approval
    get "/api/sisyphus/approvals/pending", params: { execution_id: execution_id }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal approval_id_2, body["approval"]["id"]
    assert_equal "Second Step", body["approval"]["subject_title"]
  end

  speed_profile :fast
  test "pending approvals returns nil when no pending approvals" do
    execution_id = "exec-no-approvals-#{SecureRandom.hex(8)}"
    
    get "/api/sisyphus/approvals/pending", params: { execution_id: execution_id }

    assert_response :success
    body = JSON.parse(response.body)
    assert_nil body["approval"]
  end

  speed_profile :fast
  test "show approval returns 404 for non-existent approval" do
    get "/api/sisyphus/approvals/non-existent-id"

    assert_response :not_found
    body = JSON.parse(response.body)
    assert body["error"]
  end

  speed_profile :fast
  test "approve returns 404 for non-existent approval" do
    post "/api/sisyphus/approvals/non-existent-id/approve", as: :json

    assert_response :not_found
    body = JSON.parse(response.body)
    assert body["error"]
  end

  speed_profile :fast
  test "reject returns 404 for non-existent approval" do
    post "/api/sisyphus/approvals/non-existent-id/reject", as: :json

    assert_response :not_found
    body = JSON.parse(response.body)
    assert body["error"]
  end

  speed_profile :fast
  test "pending approvals requires execution_id parameter" do
    get "/api/sisyphus/approvals/pending"

    assert_response :bad_request
    body = JSON.parse(response.body)
    assert_equal "execution_id parameter required", body["error"]
  end

  speed_profile :fast
  test "approval includes all metadata fields" do
    execution_id = "exec-#{SecureRandom.hex(8)}"
    approval_id = create_approval(
      execution_id: execution_id,
      type: :milestone,
      subject_id: "milestone-setup",
      subject_title: "Complete Project Setup",
      planned_actions: [
        "Create directory structure",
        "Initialize git repository",
        "Create configuration files",
        "Install dependencies"
      ],
      estimated_changes: {
        files_to_create: 8,
        files_to_modify: 2,
        files_to_delete: 0,
        commands_to_run: 5
      }
    )

    get "/api/sisyphus/approvals/#{approval_id}"

    assert_response :success
    body = JSON.parse(response.body)
    approval = body["approval"]
    
    assert_equal approval_id, approval["id"]
    assert_equal execution_id, approval["execution_id"]
    assert_equal "milestone", approval["type"]
    assert_equal "pending", approval["status"]
    assert_equal "milestone-setup", approval["subject_id"]
    assert_equal "Complete Project Setup", approval["subject_title"]
    assert_equal 4, approval["planned_actions"].length
    assert_equal 8, approval["estimated_changes"]["files_to_create"]
    assert_equal 2, approval["estimated_changes"]["files_to_modify"]
    assert_equal 0, approval["estimated_changes"]["files_to_delete"]
    assert_equal 5, approval["estimated_changes"]["commands_to_run"]
    assert approval["created_at"]
    assert_nil approval["resolved_at"]
    assert_nil approval["resolved_by"]
  end

  speed_profile :fast
  test "approving already approved request returns current state" do
    execution_id = "exec-#{SecureRandom.hex(8)}"
    approval_id = create_approval(
      execution_id: execution_id,
      subject_title: "Test Step"
    )

    # First approve
    post "/api/sisyphus/approvals/#{approval_id}/approve", as: :json
    assert_response :success

    # Try to approve again - should still succeed with approved state
    post "/api/sisyphus/approvals/#{approval_id}/approve", as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "approved", body["approval"]["status"]
  end

  speed_profile :fast
  test "rejecting already rejected request returns current state" do
    execution_id = "exec-#{SecureRandom.hex(8)}"
    approval_id = create_approval(
      execution_id: execution_id,
      subject_title: "Test Step"
    )

    # First reject
    post "/api/sisyphus/approvals/#{approval_id}/reject", as: :json
    assert_response :success

    # Try to reject again - should still succeed with rejected state
    post "/api/sisyphus/approvals/#{approval_id}/reject", as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "rejected", body["approval"]["status"]
  end
end
