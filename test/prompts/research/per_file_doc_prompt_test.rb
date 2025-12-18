# frozen_string_literal: true

require "test_helper"

class PerFileDocPromptTest < ActiveSupport::TestCase
  SAMPLE_CODE = <<~RUBY
    # Calculator class for basic math operations
    class Calculator
      def add(a, b)
        a + b
      end

      def subtract(a, b)
        a - b
      end

      def multiply(a, b)
        a * b
      end

      def divide(a, b)
        raise ArgumentError, "Cannot divide by zero" if b.zero?
        a.to_f / b
      end
    end
  RUBY

  # Shared analysis result
  class << self
    attr_accessor :shared_result, :computed
  end

  def prompt
    @prompt ||= Research::PerFileDocPrompt.new
  end

  def shared_analysis
    self.class.shared_result ||= prompt.analyze(
      content: SAMPLE_CODE,
      file_path: "lib/calculator.rb",
      goal_context: "How does the calculator work?",
      sub_questions: [
        "What methods does Calculator expose?",
        "How does authentication work?",
        "What operations can add perform?"
      ]
    )
  end

  # ============================================================================
  # Unit Tests - No LLM calls
  # ============================================================================

  test "has correct system prompt" do
    assert_includes prompt.system_prompt, "code documentation expert"
    assert_includes prompt.system_prompt, "Summary"
    assert_includes prompt.system_prompt, "Dependencies"
    assert_includes prompt.system_prompt, "Methods"
  end

  test "has valid response schema" do
    schema = prompt.response_schema

    assert_equal "object", schema[:type]
    assert_includes schema[:required], "summary"
    assert_includes schema[:required], "external_references"
    assert_includes schema[:required], "methods"
  end

  # ============================================================================
  # Shared Analysis Tests - Use one LLM call
  # ============================================================================

  test "shared: produces content" do
    result = shared_analysis
    assert result[:content].present?
  end

  test "shared: has summary" do
    result = shared_analysis
    assert result[:content][:summary].present?
  end

  test "shared: has external_references array" do
    result = shared_analysis
    assert result[:content][:external_references].is_a?(Array)
  end

  test "shared: has methods array" do
    result = shared_analysis
    assert result[:content][:methods].is_a?(Array)
  end

  test "shared: includes file_path" do
    result = shared_analysis
    assert_equal "lib/calculator.rb", result[:content][:file_path]
  end

  test "shared: extracts method names" do
    result = shared_analysis
    methods = result[:content][:methods]
    assert methods.any?

    method_names = methods.map { |m| m[:name] }
    assert(method_names.any? { |name| %w[add subtract multiply divide].include?(name) })
  end

  test "shared: identifies relevant sub-questions" do
    result = shared_analysis
    relevant = result[:content][:relevant_sub_questions]
    assert relevant.is_a?(Array)
  end

  # ============================================================================
  # Edge Case Test - Separate LLM call
  # ============================================================================

  test "handles file with no methods" do
    config_code = <<~RUBY
      # Configuration constants
      module Config
        DATABASE_URL = ENV["DATABASE_URL"]
        API_KEY = ENV["API_KEY"]
      end
    RUBY

    result = prompt.analyze(
      content: config_code,
      file_path: "config/constants.rb"
    )

    assert result[:content].present?
    assert result[:content][:summary].present?
  end
end
