require "test_helper"

class GrepToolTest < ActiveSupport::TestCase
  def setup
    @sandbox_path = Rails.root.join("tmp", "grep_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@sandbox_path)
    @tool = GrepTool.new(sandbox_path: @sandbox_path)

    # Create test files
    File.write(File.join(@sandbox_path, "calculator.rb"), <<~RUBY)
      class Calculator
        def add(a, b)
          a + b
        end

        def subtract(a, b)
          a - b
        end
      end
    RUBY

    File.write(File.join(@sandbox_path, "formatter.rb"), <<~RUBY)
      class Formatter
        def initialize(calculator:)
          @calculator = calculator
        end
      end
    RUBY

    File.write(File.join(@sandbox_path, "readme.txt"), <<~TEXT)
      This is a README file.
      It describes the Calculator and Formatter classes.
    TEXT
  end

  def teardown
    FileUtils.rm_rf(@sandbox_path) if @sandbox_path && File.exist?(@sandbox_path)
  end

  test "finds pattern in files" do
    result = @tool.execute(pattern: "Calculator", path: @sandbox_path)

    assert result[:success]
    assert result[:result][:match_count] >= 2
    assert result[:result][:files_matched] >= 2
  end

  test "returns line numbers" do
    result = @tool.execute(pattern: "def add", path: @sandbox_path)

    assert result[:success]
    match = result[:result][:matches].first
    assert_not_nil match[:line_number]
    assert_equal 2, match[:line_number]
  end

  test "respects max_results" do
    result = @tool.execute(pattern: "def", path: @sandbox_path, max_results: 1)

    assert result[:success]
    assert_equal 1, result[:result][:matches].size
    assert result[:result][:truncated]
  end

  test "handles regex patterns" do
    result = @tool.execute(pattern: "def \\w+\\(", path: @sandbox_path)

    assert result[:success]
    assert result[:result][:match_count] >= 2
  end

  test "case_insensitive option works" do
    result = @tool.execute(pattern: "CALCULATOR", path: @sandbox_path, case_insensitive: true)

    assert result[:success]
    assert result[:result][:match_count] >= 1

    # Without case insensitive
    result2 = @tool.execute(pattern: "CALCULATOR", path: @sandbox_path, case_insensitive: false)
    assert result2[:success]
    assert_equal 0, result2[:result][:match_count]
  end

  test "whole_word option works" do
    result = @tool.execute(pattern: "add", path: @sandbox_path, whole_word: true)

    assert result[:success]
    # Should match "def add" but not if "add" appears in other words
  end

  test "filters by extension" do
    result = @tool.execute(pattern: "Calculator", path: @sandbox_path, extensions: ["rb"])

    assert result[:success]
    # Should not include readme.txt match
    result[:result][:matches].each do |match|
      assert match[:file].end_with?(".rb")
    end
  end

  test "handles non-existent path" do
    result = @tool.execute(pattern: "test", path: File.join(@sandbox_path, "nonexistent"))

    assert_equal false, result[:success]
    assert_includes result[:error], "not found"
  end

  test "handles invalid regex" do
    result = @tool.execute(pattern: "[invalid", path: @sandbox_path)

    assert_equal false, result[:success]
    assert_includes result[:error], "Invalid regex"
  end

  test "includes context lines when requested" do
    result = @tool.execute(pattern: "def add", path: @sandbox_path, context_lines: 2)

    assert result[:success]
    match = result[:result][:matches].first
    assert_not_nil match[:context_before]
    assert_not_nil match[:context_after]
  end

  test "schema returns valid OpenAI function format" do
    schema = GrepTool.schema

    assert_equal "function", schema[:type]
    assert_equal "grep", schema[:function][:name]
    assert schema[:function][:parameters][:properties].key?(:pattern)
    assert schema[:function][:parameters][:properties].key?(:path)
  end

  test "tool is registered with ToolCallService" do
    tools = ToolCallService.available_tools
    grep_tool = tools.find { |t| t[:function][:name] == "grep" }

    assert_not_nil grep_tool
  end
end

