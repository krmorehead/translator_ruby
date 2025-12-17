require "test_helper"

class Api::V1::ResearchControllerTest < ActionDispatch::IntegrationTest
  FIXTURE_PATH = Rails.root.join("test", "fixtures", "example_codebase").to_s

  def setup
    @output_path = Rails.root.join("tmp", "research_controller_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@output_path)

    @original_output_path = ENV["RESEARCH_OUTPUT_PATH"]
    @original_state_path = ENV["AGENT_STATE_PATH"]
    ENV["RESEARCH_OUTPUT_PATH"] = @output_path
    ENV["AGENT_STATE_PATH"] = @output_path
  end

  def teardown
    FileUtils.rm_rf(@output_path) if @output_path && File.exist?(@output_path)

    if @original_output_path
      ENV["RESEARCH_OUTPUT_PATH"] = @original_output_path
    else
      ENV.delete("RESEARCH_OUTPUT_PATH")
    end

    if @original_state_path
      ENV["AGENT_STATE_PATH"] = @original_state_path
    else
      ENV.delete("AGENT_STATE_PATH")
    end
  end

  test "validation error when goal is missing" do
    post "/api/v1/research", params: { path: FIXTURE_PATH }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "goal"
  end

  test "validation error when path is missing" do
    post "/api/v1/research", params: { goal: "Test research" }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "path"
  end

  test "invalid path rejection" do
    post "/api/v1/research", params: {
      goal: "Test research",
      path: "/nonexistent/path/#{SecureRandom.uuid}"
    }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "not readable"
  end

  test "response structure on success" do
    # This test makes real LLM calls and may take time
    post "/api/v1/research", params: {
      goal: "What is the Calculator class?",
      path: FIXTURE_PATH,
      options: { max_depth: 1 }
    }, as: :json

    assert_response :ok
    json = JSON.parse(response.body)

    assert json.key?("status")
    assert json.key?("findings")
    assert json.key?("output_files")
    assert json.key?("errors")
    assert_kind_of Array, json["findings"]
    assert_kind_of Array, json["output_files"]
    assert_kind_of Array, json["errors"]
  end

  test "returns owner_id in response" do
    post "/api/v1/research", params: {
      goal: "Simple test",
      path: FIXTURE_PATH,
      options: { max_depth: 1 }
    }, as: :json

    assert_response :ok
    json = JSON.parse(response.body)

    assert json.key?("owner_id")
    assert_match(/\A[0-9a-f-]+\z/, json["owner_id"])
  end
end

