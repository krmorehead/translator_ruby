require "test_helper"

class BaseToolTest < ActiveSupport::TestCase
  # Test subclass for testing base functionality
  class TestTool < BaseTool
    def self.name_identifier
      "test_tool"
    end

    def self.description
      "A test tool for unit testing"
    end

    def self.parameters_schema
      {
        type: "object",
        properties: {
          test_param: { type: "string", description: "A test parameter" }
        },
        required: [ "test_param" ]
      }
    end

    def execute(test_param:)
      success_result("Executed with: #{test_param}")
    end
  end

  test "schema returns hash with required OpenAI function structure" do
    schema = TestTool.schema

    assert_equal "function", schema[:type]
    assert schema[:function].is_a?(Hash)
    assert_equal "test_tool", schema[:function][:name]
    assert_equal "A test tool for unit testing", schema[:function][:description]
    assert schema[:function][:parameters].is_a?(Hash)
  end

  test "name_identifier returns a string" do
    assert_equal "test_tool", TestTool.name_identifier
    assert TestTool.name_identifier.is_a?(String)
  end

  test "execute raises NotImplementedError on base class" do
    tool = BaseTool.new

    assert_raises(NotImplementedError) do
      tool.execute
    end
  end

  test "base class raises NotImplementedError for name_identifier" do
    assert_raises(NotImplementedError) do
      BaseTool.name_identifier
    end
  end

  test "base class raises NotImplementedError for description" do
    assert_raises(NotImplementedError) do
      BaseTool.description
    end
  end

  test "base class raises NotImplementedError for parameters_schema" do
    assert_raises(NotImplementedError) do
      BaseTool.parameters_schema
    end
  end

  test "result structure includes success, result, and error keys" do
    tool = TestTool.new
    result = tool.execute(test_param: "hello")

    assert result.key?(:success)
    assert result.key?(:result)
    assert result.key?(:error)
  end

  test "success_result returns correct structure" do
    tool = TestTool.new
    result = tool.execute(test_param: "test")

    assert_equal true, result[:success]
    assert_equal "Executed with: test", result[:result]
    assert_nil result[:error]
  end

  test "tool can be instantiated without arguments" do
    tool = TestTool.new
    assert_not_nil tool
  end
end

