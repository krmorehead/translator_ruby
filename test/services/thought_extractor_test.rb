# frozen_string_literal: true

require "test_helper"

class ThoughtExtractorTest < ActiveSupport::TestCase
  speed_profile :fast
  test "extract_and_filter extracts single think block" do
    content = "<think>This is my reasoning</think>The actual response"
    result = ThoughtExtractor.extract_and_filter(content)

    assert_equal "The actual response", result[:content]
    assert_equal "This is my reasoning", result[:thoughts]
  end

  speed_profile :fast
  test "extract_and_filter extracts multiple think blocks" do
    content = "<think>First thought</think>Some text<think>Second thought</think>More text"
    result = ThoughtExtractor.extract_and_filter(content)

    assert_equal "Some textMore text", result[:content]
    assert_equal "First thought\n\nSecond thought", result[:thoughts]
  end

  speed_profile :fast
  test "extract_and_filter handles multi-line think content" do
    content = <<~TEXT
      <think>
      This is a multi-line
      reasoning block
      </think>
      The final answer
    TEXT

    result = ThoughtExtractor.extract_and_filter(content)

    assert_equal "The final answer", result[:content]
    assert_includes result[:thoughts], "This is a multi-line"
    assert_includes result[:thoughts], "reasoning block"
  end

  speed_profile :fast
  test "extract_and_filter returns nil thoughts when no think tags present" do
    content = "Just a regular response with no think tags"
    result = ThoughtExtractor.extract_and_filter(content)

    assert_equal content, result[:content]
    assert_nil result[:thoughts]
  end

  speed_profile :fast
  test "extract_and_filter handles nil input" do
    result = ThoughtExtractor.extract_and_filter(nil)

    assert_equal "", result[:content]
    assert_nil result[:thoughts]
  end

  speed_profile :fast
  test "extract_and_filter handles empty input" do
    result = ThoughtExtractor.extract_and_filter("")

    assert_equal "", result[:content]
    assert_nil result[:thoughts]
  end

  speed_profile :fast
  test "extract_and_filter preserves non-think content exactly" do
    content = "Important content <think>reasoning</think> more important content"
    result = ThoughtExtractor.extract_and_filter(content)

    assert_equal "Important content  more important content", result[:content]
  end

  speed_profile :fast
  test "extract_and_filter preserves JSON structure" do
    content = '<think>Let me structure this</think>{"key": "value", "number": 42}'
    result = ThoughtExtractor.extract_and_filter(content)

    assert_equal '{"key": "value", "number": 42}', result[:content]
    assert_nothing_raised do
      JSON.parse(result[:content])
    end
  end

  speed_profile :fast
  test "extract_and_filter handles malformed tags gracefully" do
    content = "<think>Unclosed tag or <think>nested</think> content"
    result = ThoughtExtractor.extract_and_filter(content)

    # Should still extract what it can
    assert result[:content].is_a?(String)
    assert_not_nil result[:thoughts]
  end

  speed_profile :fast
  test "extract_and_filter with real vllm-style response" do
    content = <<~RESPONSE
      <think>
      The user wants to check their inventory. I should use the read_inventory tool.
      No arguments are needed for this tool.
      </think>
      {
        "tool": "read_inventory",
        "arguments": {}
      }
    RESPONSE

    result = ThoughtExtractor.extract_and_filter(content)

    # Content should be clean JSON
    assert_includes result[:content], '"tool"'
    assert_includes result[:content], '"read_inventory"'
    assert_not_includes result[:content], "<think>"

    # Thoughts should contain reasoning
    assert_includes result[:thoughts], "check their inventory"
    assert_includes result[:thoughts], "read_inventory tool"
  end

  speed_profile :fast
  test "extract_and_filter trims whitespace from filtered content" do
    content = "  <think>reasoning</think>  \n  response text  \n  "
    result = ThoughtExtractor.extract_and_filter(content)

    assert_equal "response text", result[:content]
  end

  speed_profile :fast
  test "extract_and_filter with only think tags" do
    content = "<think>Only reasoning, no output</think>"
    result = ThoughtExtractor.extract_and_filter(content)

    assert_equal "", result[:content]
    assert_equal "Only reasoning, no output", result[:thoughts]
  end

  speed_profile :fast
  test "extract_and_filter handles complex nested-like content" do
    # Not truly nested tags, but content that looks nested
    content = "<think>First</think>Middle<think>Second with <think> inside text</think>End"
    result = ThoughtExtractor.extract_and_filter(content)

    assert_equal "MiddleEnd", result[:content]
    assert_includes result[:thoughts], "First"
    assert_includes result[:thoughts], "Second"
  end
end

