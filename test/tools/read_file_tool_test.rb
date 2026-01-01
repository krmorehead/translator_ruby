require "test_helper"

class ReadFileToolTest < ActiveSupport::TestCase
  def setup
    # Use unique directory per test to avoid parallel test conflicts
    @test_path = Rails.root.join("test", "tool_test", "read_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@test_path)
    @tool = ReadFileTool.new
  end

  def teardown
    FileUtils.rm_rf(@test_path) if @test_path && File.exist?(@test_path)
  end
  speed_profile :medium
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

  speed_profile :medium
  test "execute reads file content successfully" do
    test_file = File.join(@test_path, "test_read.txt")
    File.write(test_file, "Hello, World!")

    result = @tool.execute(path: test_file)

    assert_equal true, result[:success]
    assert_equal "Hello, World!", result[:result]
    assert_nil result[:error]
  end

  speed_profile :medium
  test "execute returns error for non-existent file" do
    result = @tool.execute(path: File.join(@test_path, "nonexistent.txt"))

    assert_equal false, result[:success]
    assert_nil result[:result]
    assert_includes result[:error], "File not found"
  end

  speed_profile :medium
  test "reads files with various content types" do
    test_file = File.join(@test_path, "multiline.txt")
    content = "Line 1\nLine 2\nLine 3"
    File.write(test_file, content)

    result = @tool.execute(path: test_file)

    assert_equal true, result[:success]
    assert_equal content, result[:result]
  end

  speed_profile :medium
  test "tool is registered with ToolCallService" do
    tools = ToolCallService.available_tools
    read_file_tool = tools.find { |t| t[:function][:name] == "read_file" }

    assert_not_nil read_file_tool
  end

  speed_profile :medium
  test "can read any accessible file" do
    # Read a file we know exists
    gemfile_path = Rails.root.join("Gemfile").to_s

    result = @tool.execute(path: gemfile_path)

    assert_equal true, result[:success]
    assert_includes result[:result], "source"
  end

  # LLM Integration Test via prompt
  speed_profile :medium
  test "LLM can request read_file tool to read a file" do
    test_file = File.join(@test_path, "llm_read_test.txt")
    test_content = "This is secret content that only the LLM should read."
    File.write(test_file, test_content)

    # Only include the read_file tool to keep context size small for tool-calling model
    tools = [ReadFileTool.schema]
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

    arguments = read_action[:arguments] || {}
    # Normalize argument keys - LLM may return path_ instead of path
    normalized_args = {}
    arguments.each do |key, value|
      normalized_key = key.to_s.gsub(/_+$/, "").to_sym
      normalized_args[normalized_key] = value
    end
    normalized_args[:path] ||= test_file

    service = ToolCallService.new
    result = service.execute(tool_name: "read_file", arguments: normalized_args)

    assert_equal true, result[:success], "Read file should succeed"
    assert_equal test_content, result[:result], "Result should contain the file content"
  end
end
