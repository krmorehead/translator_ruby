require "test_helper"

class ReadFileToolTest < ActiveSupport::TestCase
  def setup
    # Use unique directory per test to avoid parallel test conflicts
    @sandbox_path = Rails.root.join("test", "tool_test", "read_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@sandbox_path)
    @tool = ReadFileTool.new(sandbox_path: @sandbox_path)
  end

  def teardown
    FileUtils.rm_rf(@sandbox_path) if @sandbox_path && File.exist?(@sandbox_path)
  end

  test "schema returns valid OpenAI function format with path parameter" do
    schema = ReadFileTool.schema

    assert_equal "function", schema[:type]
    assert_equal "read_file", schema[:function][:name]
    assert_equal "Read the contents of a file at the specified path", schema[:function][:description]

    params = schema[:function][:parameters]
    assert_equal "object", params[:type]
    assert params[:properties].key?(:path)
    assert_equal "string", params[:properties][:path][:type]
    assert_includes params[:required], "path"
  end

  test "execute reads file content successfully" do
    test_file = File.join(@sandbox_path, "test_read.txt")
    File.write(test_file, "Hello, World!")

    result = @tool.execute(path: test_file)

    assert_equal true, result[:success]
    assert_equal "Hello, World!", result[:result]
    assert_nil result[:error]
  end

  test "execute returns error for non-existent file" do
    result = @tool.execute(path: File.join(@sandbox_path, "nonexistent.txt"))

    assert_equal false, result[:success]
    assert_nil result[:result]
    assert_includes result[:error], "File not found"
  end

  test "execute returns error when path escapes sandbox" do
    result = @tool.execute(path: "/etc/passwd")

    assert_equal false, result[:success]
    assert_nil result[:result]
    assert_includes result[:error], "outside the sandbox"
  end

  test "execute returns error for relative path escape attempt" do
    result = @tool.execute(path: File.join(@sandbox_path, "..", "..", "etc", "passwd"))

    assert_equal false, result[:success]
    assert_includes result[:error], "outside the sandbox"
  end

  test "works with test/tool_test sandbox directory" do
    test_file = File.join(@sandbox_path, "sandbox_test.txt")
    File.write(test_file, "Sandbox content")

    result = @tool.execute(path: test_file)

    assert_equal true, result[:success]
    assert_equal "Sandbox content", result[:result]
  end

  test "reads files with various content types" do
    test_file = File.join(@sandbox_path, "multiline.txt")
    content = "Line 1\nLine 2\nLine 3"
    File.write(test_file, content)

    result = @tool.execute(path: test_file)

    assert_equal true, result[:success]
    assert_equal content, result[:result]
  end

  test "tool is registered with ToolCallService" do
    tools = ToolCallService.available_tools
    read_file_tool = tools.find { |t| t[:function][:name] == "read_file" }

    assert_not_nil read_file_tool
  end

  test "without sandbox allows reading any accessible file" do
    tool_no_sandbox = ReadFileTool.new
    # Read a file we know exists
    gemfile_path = Rails.root.join("Gemfile").to_s

    result = tool_no_sandbox.execute(path: gemfile_path)

    assert_equal true, result[:success]
    assert_includes result[:result], "source"
  end

  # LLM Integration Test via prompt
  test "LLM can request read_file tool to read a file" do
    test_file = File.join(@sandbox_path, "llm_read_test.txt")
    test_content = "This is secret content that only the LLM should read."
    File.write(test_file, test_content)

    tools = ToolCallService.available_tools
    detector = ActionDetectionPrompt.new(tools: tools)

    context = Contexts::BaseContext.new
    context.add(content: "tool smoke test", topics: ["scene"], source: "test")

    actions = detector.execute(
      prompt: "Read the contents of the file at #{test_file} using the read_file tool.",
      context: context
    )

    assert_kind_of Hash, actions
    assert actions.key?(:content)
    action_list = actions[:content]
    assert_kind_of Array, action_list
    read_action = action_list.find { |a| a[:tool_name] == "read_file" }
    assert read_action, "LLM should propose read_file action"

    args = read_action[:arguments] || {}
    args[:path] ||= test_file

    service = ToolCallService.new(sandbox_path: @sandbox_path)
    result = service.execute(tool_name: "read_file", arguments: args)

    assert_equal true, result[:success], "Read file should succeed"
    assert_equal test_content, result[:result], "Result should contain the file content"
  end
end
