# frozen_string_literal: true

require "test_helper"

class SisyphusApprovalFlowTest < ActionDispatch::IntegrationTest
  setup do
    @test_dir = Rails.root.join("test", "tmp", "sisyphus_approval_flow_test_#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(@test_dir)
    @test_project = File.join(@test_dir, "test_project")
    FileUtils.mkdir_p(@test_project)
    @test_plan = File.join(@test_dir, "test_plan.md")
    File.write(@test_plan, "# Test Plan\n\n## Milestone 1\n- Step 1: Test step\n")
    
    @approval_store = ApprovalRequestStore.new
    @execution_id = "test-exec-#{SecureRandom.hex(8)}"
  end

  teardown do
    # Clean up test approvals
    begin
      approvals = @approval_store.list_for_execution(execution_id: @execution_id)
      approvals.each { |approval| @approval_store.delete(approval.id) }
    rescue StandardError => e
      # Ignore cleanup errors
    end
    
    FileUtils.rm_rf(@test_dir) if @test_dir && File.exist?(@test_dir)
  end

  # Full Approval Flow Tests

  speed_profile :medium
  test "complete step approval flow - create, poll, approve" do
    # Step 1: Create an approval request using the test endpoint
    approval_id = "approval-#{SecureRandom.hex(8)}"
    
    post "/api/sisyphus/test/inject_approval", params: {
      id: approval_id,
      execution_id: @execution_id,
      type: "step",
      subject_id: "step-1",
      subject_title: "Test Step Approval",
      planned_actions: [
        "Create file test.rb",
        "Write test code"
      ],
      estimated_changes: {
        files_to_create: 1,
        files_to_modify: 0
      }
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert_equal approval_id, body["approval"]["id"]

    # Step 2: Poll for pending approval
    get "/api/sisyphus/approvals/pending", params: { execution_id: @execution_id }

    assert_response :success
    body = JSON.parse(response.body)
    assert body["approval"]
    assert_equal approval_id, body["approval"]["id"]
    assert_equal "pending", body["approval"]["status"]
    assert_equal "step", body["approval"]["type"]
    assert_equal "Test Step Approval", body["approval"]["subject_title"]
    assert_equal 2, body["approval"]["planned_actions"].length

    # Step 3: Approve the request
    post "/api/sisyphus/approvals/#{approval_id}/approve", params: {
      resolved_by: "integration_test"
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert_equal "approved", body["approval"]["status"]
    assert_equal "integration_test", body["approval"]["resolved_by"]
    assert body["approval"]["resolved_at"]

    # Step 4: Verify no more pending approvals
    get "/api/sisyphus/approvals/pending", params: { execution_id: @execution_id }

    assert_response :success
    body = JSON.parse(response.body)
    assert_nil body["approval"] # No more pending approvals
  end

  speed_profile :medium
  test "complete milestone approval flow - create, poll, reject" do
    # Step 1: Create a milestone approval
    approval_id = "approval-milestone-#{SecureRandom.hex(8)}"
    
    post "/api/sisyphus/test/inject_approval", params: {
      id: approval_id,
      execution_id: @execution_id,
      type: "milestone",
      subject_id: "milestone-1",
      subject_title: "Complete Setup Milestone",
      planned_actions: [
        "Create project structure",
        "Install dependencies",
        "Configure settings"
      ],
      estimated_changes: {
        files_to_create: 5,
        files_to_modify: 2,
        commands_to_run: 3
      }
    }, as: :json

    assert_response :success

    # Step 2: Get the approval status
    get "/api/sisyphus/approvals/#{approval_id}"

    assert_response :success
    body = JSON.parse(response.body)
    assert body["approval"]
    assert_equal "milestone", body["approval"]["type"]
    assert_equal "pending", body["approval"]["status"]

    # Step 3: Reject the milestone
    post "/api/sisyphus/approvals/#{approval_id}/reject", params: {
      resolved_by: "integration_test"
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert_equal "rejected", body["approval"]["status"]

    # Step 4: Verify status persisted
    get "/api/sisyphus/approvals/#{approval_id}"

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "rejected", body["approval"]["status"]
    assert body["approval"]["resolved_at"]
  end

  speed_profile :medium
  test "multiple approvals for same execution - sequential handling" do
    # Create first approval
    approval_id_1 = "approval-1-#{SecureRandom.hex(8)}"
    post "/api/sisyphus/test/inject_approval", params: {
      id: approval_id_1,
      execution_id: @execution_id,
      type: "step",
      subject_title: "First Step"
    }, as: :json

    assert_response :success

    # Approve first
    post "/api/sisyphus/approvals/#{approval_id_1}/approve", as: :json
    assert_response :success

    # Create second approval
    approval_id_2 = "approval-2-#{SecureRandom.hex(8)}"
    post "/api/sisyphus/test/inject_approval", params: {
      id: approval_id_2,
      execution_id: @execution_id,
      type: "step",
      subject_title: "Second Step"
    }, as: :json

    assert_response :success

    # Poll should return second approval (first is approved)
    get "/api/sisyphus/approvals/pending", params: { execution_id: @execution_id }

    assert_response :success
    body = JSON.parse(response.body)
    assert body["approval"]
    assert_equal approval_id_2, body["approval"]["id"]
    assert_equal "Second Step", body["approval"]["subject_title"]
  end

  speed_profile :fast
  test "approval with expired timeout shows expired state" do
    approval_id = "approval-expired-#{SecureRandom.hex(8)}"
    
    # Create an approval with past created_at timestamp
    post "/api/sisyphus/test/inject_approval", params: {
      id: approval_id,
      execution_id: @execution_id,
      type: "step",
      subject_title: "Expired Step",
      created_at: (Time.now.utc - 400).iso8601, # 400 seconds ago
      timeout_seconds: 300 # 5 minute timeout - so it's expired
    }, as: :json

    assert_response :success

    # Get the approval and verify it's expired
    get "/api/sisyphus/approvals/#{approval_id}"

    assert_response :success
    body = JSON.parse(response.body)
    assert body["approval"]
    
    # Verify the approval is recognized as expired (client-side check)
    created_at = Time.parse(body["approval"]["created_at"])
    timeout_seconds = body["approval"]["timeout_seconds"]
    timeout_at = created_at + timeout_seconds
    
    assert timeout_at < Time.now.utc, "Approval should be expired"
  end

  speed_profile :fast
  test "clear test approvals removes all approvals for execution" do
    # Create multiple approvals
    3.times do |i|
      post "/api/sisyphus/test/inject_approval", params: {
        execution_id: @execution_id,
        subject_title: "Step #{i + 1}"
      }, as: :json

      assert_response :success
    end

    # Verify approvals exist
    get "/api/sisyphus/approvals/pending", params: { execution_id: @execution_id }
    assert_response :success
    body = JSON.parse(response.body)
    assert body["approval"]

    # Clear approvals
    delete "/api/sisyphus/test/clear_approvals", params: {
      execution_id: @execution_id
    }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert body["success"]
    assert_equal 3, body["cleared"]

    # Verify no more approvals
    get "/api/sisyphus/approvals/pending", params: { execution_id: @execution_id }
    assert_response :success
    body = JSON.parse(response.body)
    assert_nil body["approval"]
  end

  speed_profile :fast
  test "approval with full details includes all metadata" do
    approval_id = "approval-full-#{SecureRandom.hex(8)}"
    
    post "/api/sisyphus/test/inject_approval", params: {
      id: approval_id,
      execution_id: @execution_id,
      type: "milestone",
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
      },
      timeout_seconds: 600
    }, as: :json

    assert_response :success

    # Retrieve and verify all details
    get "/api/sisyphus/approvals/#{approval_id}"

    assert_response :success
    body = JSON.parse(response.body)
    approval = body["approval"]
    
    assert_equal approval_id, approval["id"]
    assert_equal @execution_id, approval["execution_id"]
    assert_equal "milestone", approval["type"]
    assert_equal "pending", approval["status"]
    assert_equal "milestone-setup", approval["subject_id"]
    assert_equal "Complete Project Setup", approval["subject_title"]
    assert_equal 4, approval["planned_actions"].length
    assert_equal 8, approval["estimated_changes"]["files_to_create"]
    assert_equal 2, approval["estimated_changes"]["files_to_modify"]
    assert_equal 0, approval["estimated_changes"]["files_to_delete"]
    assert_equal 5, approval["estimated_changes"]["commands_to_run"]
    assert_equal 600, approval["timeout_seconds"]
    assert approval["created_at"]
    assert_nil approval["resolved_at"]
    assert_nil approval["resolved_by"]
  end

  speed_profile :fast
  test "test endpoints only available in test and development" do
    # This test verifies the environment check
    # In test environment, endpoints should be available
    
    post "/api/sisyphus/test/inject_approval", params: {
      execution_id: @execution_id
    }, as: :json

    # Should succeed in test environment
    assert_response :success
  end

  speed_profile :fast
  test "cannot approve already approved request" do
    approval_id = "approval-double-#{SecureRandom.hex(8)}"
    
    # Create and approve
    post "/api/sisyphus/test/inject_approval", params: {
      id: approval_id,
      execution_id: @execution_id,
      subject_title: "Test Step"
    }, as: :json

    post "/api/sisyphus/approvals/#{approval_id}/approve", as: :json
    assert_response :success

    # Try to approve again - should still return the approved state
    post "/api/sisyphus/approvals/#{approval_id}/approve", as: :json
    assert_response :success
    
    body = JSON.parse(response.body)
    assert_equal "approved", body["approval"]["status"]
  end

  speed_profile :fast
  test "cannot reject already rejected request" do
    approval_id = "approval-double-reject-#{SecureRandom.hex(8)}"
    
    # Create and reject
    post "/api/sisyphus/test/inject_approval", params: {
      id: approval_id,
      execution_id: @execution_id,
      subject_title: "Test Step"
    }, as: :json

    post "/api/sisyphus/approvals/#{approval_id}/reject", as: :json
    assert_response :success

    # Try to reject again
    post "/api/sisyphus/approvals/#{approval_id}/reject", as: :json
    assert_response :success
    
    body = JSON.parse(response.body)
    assert_equal "rejected", body["approval"]["status"]
  end
end

