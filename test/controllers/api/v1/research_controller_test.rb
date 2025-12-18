# frozen_string_literal: true

require "test_helper"

class Api::V1::ResearchControllerTest < ActionDispatch::IntegrationTest
  FIXTURE_PATH = Rails.root.join("test", "fixtures", "example_codebase").to_s

  # Store responses for tests that share the same request
  class << self
    attr_accessor :default_response, :report_response, :both_modes_response, :computed
  end

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

  # Shared request for default mode tests
  def default_mode_response
    unless self.class.default_response
      post "/api/v1/research", params: {
        goal: "What is the Calculator class?",
        path: FIXTURE_PATH,
        options: { max_depth: 1 }
      }, as: :json
      self.class.default_response = {
        status: response.status,
        body: JSON.parse(response.body)
      }
    end
    self.class.default_response
  end

  # Shared request for both modes test
  def both_modes_response
    unless self.class.both_modes_response
      post "/api/v1/research", params: {
        goal: "How does Calculator work?",
        path: FIXTURE_PATH,
        options: { max_depth: 1, output_modes: ["report", "documentation"] }
      }, as: :json
      self.class.both_modes_response = {
        status: response.status,
        body: JSON.parse(response.body)
      }
    end
    self.class.both_modes_response
  end

  # ============================================================================
  # Validation Tests - No LLM calls
  # ============================================================================

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

  test "invalid output_modes rejection" do
    post "/api/v1/research", params: {
      goal: "Test research",
      path: FIXTURE_PATH,
      options: { output_modes: ["invalid_mode"] }
    }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "output_modes"
  end

  # ============================================================================
  # Default Mode Tests - Share one LLM call
  # ============================================================================

  test "default: returns success status" do
    resp = default_mode_response
    assert_equal 200, resp[:status]
  end

  test "default: has expected keys in response" do
    resp = default_mode_response
    json = resp[:body]

    assert json.key?("status")
    assert json.key?("findings")
    assert json.key?("output_files")
    assert json.key?("errors")
  end

  test "default: findings is array" do
    resp = default_mode_response
    assert_kind_of Array, resp[:body]["findings"]
  end

  test "default: output_files is array" do
    resp = default_mode_response
    assert_kind_of Array, resp[:body]["output_files"]
  end

  test "default: returns owner_id" do
    resp = default_mode_response
    assert resp[:body].key?("owner_id")
    assert_match(/\A[0-9a-f-]+\z/, resp[:body]["owner_id"])
  end

  test "default: includes both output_modes" do
    resp = default_mode_response
    assert_includes resp[:body]["output_modes"], "report"
    assert_includes resp[:body]["output_modes"], "documentation"
  end

  # ============================================================================
  # Both Modes Tests - Share one LLM call
  # ============================================================================

  test "both_modes: generates synthesis_summary.md" do
    resp = both_modes_response
    output_files = resp[:body]["output_files"] || []

    assert output_files.any? { |f| f.include?("synthesis_summary.md") },
           "Should generate synthesis_summary.md"
  end

  test "both_modes: generates base_references.md" do
    resp = both_modes_response
    output_files = resp[:body]["output_files"] || []

    assert output_files.any? { |f| f.include?("base_references.md") },
           "Should generate base_references.md"
  end

  test "both_modes: includes both modes in response" do
    resp = both_modes_response

    assert_includes resp[:body]["output_modes"], "report"
    assert_includes resp[:body]["output_modes"], "documentation"
  end
end
