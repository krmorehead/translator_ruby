# frozen_string_literal: true

require "test_helper"
require "ostruct"

class SearchFilesActionTest < ActiveSupport::TestCase
  def setup
    @test_path = File.expand_path("../../../fixtures/example_codebase", __FILE__)
    @agent = OpenStruct.new(goal: "Test goal", path: @test_path)
    @memory_store = create_mock_memory_store
  end
  speed_profile :fast
  test "searches by filename pattern" do
    action = create_action

    result = action.execute(pattern: "calculator", search_type: "filename")

    assert result[:success]
    assert result[:files].any?
    assert result[:files].any? { |f| f[:path].include?("calculator") }
  end

  speed_profile :fast
  test "searches by content" do
    action = create_action

    result = action.execute(pattern: "def add", search_type: "content")

    assert result[:success]
    assert result[:files].any?
    assert result[:files].any? { |f| f[:matches]&.any? { |m| m[:content].include?("def add") } }
  end

  speed_profile :fast
  test "respects file type filter" do
    action = create_action

    result = action.execute(pattern: "calculator", search_type: "filename", file_types: ["rb"])

    assert result[:success]
    result[:files].each do |file|
      assert file[:path].end_with?(".rb") || file[:path].include?("calculator")
    end
  end

  speed_profile :fast
  test "respects limit" do
    action = create_action

    result = action.execute(pattern: "*", search_type: "filename", limit: 3)

    assert result[:success]
    assert result[:files].size <= 3
  end

  speed_profile :fast
  test "returns empty for no matches" do
    action = create_action

    result = action.execute(pattern: "nonexistent_xyz_12345", search_type: "filename")

    assert result[:success]
    assert_equal 0, result[:count]
  end

  speed_profile :fast
  test "fails with empty pattern" do
    action = create_action

    result = action.execute(pattern: "", search_type: "filename")

    refute result[:success]
    assert result[:error]
  end

  
  def create_action
    Actions::SearchFilesAction.new(
      agent: @agent,
      memory_store: @memory_store,
      path: @test_path,
      goal: "Test goal"
    )
  end

  def create_mock_memory_store
    # Create a mock that properly handles keyword arguments
    mock = Object.new

    def mock.get_section(_name)
      []
    end

    def mock.update_section(name:, content:, append: true)
      # No-op for tests
    end

    def mock.set_section(_name, _data)
      # No-op for tests
    end

    def mock.respond_to?(method, *)
      [:get_section, :update_section, :set_section].include?(method) || super
    end

    mock
  end
end

