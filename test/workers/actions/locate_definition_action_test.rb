# frozen_string_literal: true

require "test_helper"
require "ostruct"

class LocateDefinitionActionTest < ActiveSupport::TestCase
  def setup
    @test_path = File.expand_path("../../../fixtures/example_codebase", __FILE__)
    @agent = OpenStruct.new(goal: "Test goal", path: @test_path)
    @memory_store = create_mock_memory_store
  end
  speed_profile :slow
  test "locates class definitions" do
    action = create_action

    result = action.execute(symbol: "Calculator", type: "class")

    assert result[:success]
    assert result[:definitions].any?
    assert result[:definitions].any? { |d| d[:type] == :class }
  end

  speed_profile :slow
  test "locates method definitions" do
    action = create_action

    result = action.execute(symbol: "add", type: "method")

    assert result[:success]
    assert result[:definitions].any?
    assert result[:definitions].any? { |d| d[:type] == :method }
  end

  speed_profile :slow
  test "locates any definition type when type is 'any'" do
    action = create_action

    result = action.execute(symbol: "Calculator", type: "any")

    assert result[:success]
    assert result[:definitions].any?
  end

  speed_profile :slow
  test "returns empty for non-existent symbol" do
    action = create_action

    result = action.execute(symbol: "NonExistentClass12345", type: "class")

    assert result[:success]
    assert_equal 0, result[:count]
  end

  speed_profile :slow
  test "fails with empty symbol" do
    action = create_action

    result = action.execute(symbol: "", type: "class")

    refute result[:success]
    assert result[:error]
  end

  speed_profile :slow
  test "definitions include file path and line number" do
    action = create_action

    result = action.execute(symbol: "Calculator", type: "class")

    assert result[:success]
    if result[:definitions].any?
      defn = result[:definitions].first
      assert defn[:file]
      assert defn[:line]
      assert defn[:content]
    end
  end

  
  def create_action
    Actions::LocateDefinitionAction.new(
      agent: @agent,
      memory_store: @memory_store,
      path: @test_path,
      goal: "Test goal"
    )
  end

  def create_mock_memory_store
    # Create a mock that properly handles keyword arguments
    mock = Object.new
    findings = []
    discovered_files = []

    mock.define_singleton_method(:get_section) do |name|
      case name.to_sym
      when :findings then findings
      when :discovered_files then discovered_files
      else []
      end
    end

    mock.define_singleton_method(:update_section) do |name:, content:, append: true|
      case name.to_sym
      when :findings then findings << content
      when :discovered_files then discovered_files << content
      end
    end

    mock.define_singleton_method(:set_section) do |_name, _data|
      # No-op for tests
    end

    mock
  end
end

