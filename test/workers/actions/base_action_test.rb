# frozen_string_literal: true

require "test_helper"
require "ostruct"

class BaseActionTest < ActiveSupport::TestCase
  def setup
    @test_path = File.expand_path("../../../fixtures/example_codebase", __FILE__)
    @agent = OpenStruct.new(goal: "Test goal", path: @test_path)
    @memory_store = build(:memory_store)
  end
  speed_profile :fast
  test "success_result returns proper structure" do
    action = create_action

    result = action.send(:success_result, data: "test", count: 5)

    assert result[:success]
    assert_equal "test", result[:data]
    assert_equal 5, result[:count]
    assert result[:timestamp]
  end

  speed_profile :fast
  test "error_result returns proper structure" do
    action = create_action

    result = action.send(:error_result, "Something went wrong")

    refute result[:success]
    assert_equal "Something went wrong", result[:error]
    assert_includes result[:summary], "Error: Something went wrong"
  end

  speed_profile :fast
  test "read_file reads existing files" do
    action = create_action

    content = action.send(:read_file, "lib/calculator.rb")

    assert content
    assert_includes content, "class Calculator"
  end

  speed_profile :fast
  test "read_file returns empty string for non-existent files" do
    action = create_action

    content = action.send(:read_file, "nonexistent.rb")

    assert_equal "", content
  end

  speed_profile :fast
  test "list_files returns files in directory" do
    action = create_action

    files = action.send(:list_files, nil, pattern: "**/*.rb")

    assert files.any?
    assert files.any? { |f| f.include?("calculator.rb") }
  end

  speed_profile :fast
  test "grep_files finds pattern matches" do
    action = create_action

    matches = action.send(:grep_files, "class Calculator")

    assert matches.any?
    assert matches.any? { |m| m[:content].include?("class Calculator") }
  end

  
  def create_action
    Actions::BaseAction.new(
      agent: @agent,
      memory_store: @memory_store,
      goal: "Test goal"
    )
  end
end

