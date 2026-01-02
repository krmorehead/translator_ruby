# frozen_string_literal: true

class DaedalusControllerTest < ActionDispatch::IntegrationTest
  speed_profile :fast
  test "should validate goal is present" do
    post "/daedalus/create", params: { path: "/tmp" }, as: :json
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_match(/goal is required/i, json["error"])
  end

  speed_profile :fast
  test "should validate path is present" do
    post "/daedalus/create", params: { goal: "test goal" }, as: :json
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_match(/path is required/i, json["error"])
  end

  speed_profile :fast
  test "should validate path exists" do
    post "/daedalus/create", params: { goal: "test goal", path: "/nonexistent/path" }, as: :json
    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_match(/path does not exist or is not readable/i, json["error"])
  end

  # Full integration test with LLM is in test/integration/daedalus_integration_test.rb
end

