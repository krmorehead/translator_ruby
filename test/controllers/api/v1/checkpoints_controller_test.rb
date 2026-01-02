# frozen_string_literal: true

require "test_helper"

class Api::V1::CheckpointsControllerTest < ActionDispatch::IntegrationTest
  let(:temp_repo) { create_temp_git_repo }

  def teardown
    FileUtils.rm_rf(temp_repo) if temp_repo && File.exist?(temp_repo)
  end

  speed_profile :fast
  test "POST /api/v1/checkpoints requires path parameter" do
    post "/api/v1/checkpoints", params: {
      message: "Test checkpoint"
    }, as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)
    
    assert_not json["success"]
    assert_match(/path parameter is required/, json["error"])
  end

  speed_profile :fast
  test "POST /api/v1/checkpoints requires message parameter" do
    post "/api/v1/checkpoints", params: {
      path: temp_repo
    }, as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)
    
    assert_not json["success"]
  end

  speed_profile :fast
  test "POST /api/v1/checkpoints validates path exists" do
    post "/api/v1/checkpoints", params: {
      path: "/nonexistent/path",
      message: "Test"
    }, as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)
    
    assert_not json["success"]
    assert_match(/path does not exist/, json["error"])
  end

  speed_profile :fast
  test "GET /api/v1/checkpoints requires path parameter" do
    get "/api/v1/checkpoints"

    assert_response :bad_request
    json = JSON.parse(response.body)
    
    assert_not json["success"]
    assert_match(/path parameter is required/, json["error"])
  end

  speed_profile :fast
  test "GET /api/v1/checkpoints/current returns current checkpoint ID" do
    get "/api/v1/checkpoints/current", params: { path: temp_repo }

    assert_response :success
    json = JSON.parse(response.body)
    
    assert json["success"]
    assert json["checkpoint_id"]
    assert json["checkpoint_id"].is_a?(String)
  end

  speed_profile :fast
  test "POST /api/v1/checkpoints creates a checkpoint" do
    # Make a change in the temp repo so there's something to commit
    File.write(File.join(temp_repo, "test.txt"), "test content")
    Dir.chdir(temp_repo) do
      system("git add test.txt", out: File::NULL, err: File::NULL)
    end
    
    post "/api/v1/checkpoints", params: {
      path: temp_repo,
      message: "Test checkpoint from API"
    }, as: :json

    assert_response :created
    json = JSON.parse(response.body)
    
    assert json["success"]
    assert json["checkpoint"]
    assert_equal "Sisyphus: Test checkpoint from API", json["checkpoint"]["message"]
    assert json["checkpoint"]["id"]
    assert json["checkpoint"]["created_at"]
  end
end
