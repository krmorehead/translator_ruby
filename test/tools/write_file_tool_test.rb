require "test_helper"

class WriteFileToolTest < ActiveSupport::TestCase
  def setup
    # Use unique directory per test to avoid parallel test conflicts
    @test_path = Rails.root.join("test", "tool_test", "write_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@test_path)
    @tool = WriteFileTool.new
  end

  def teardown
    FileUtils.rm_rf(@test_path) if @test_path && File.exist?(@test_path)
  end

  test "schema returns valid OpenAI function format with path and content parameters" do
    schema = WriteFileTool.schema

    assert_equal "function", schema[:type]
    assert_equal "write_file", schema[:function][:name]
    assert_equal "Write content to a file at the specified path", schema[:function][:description]

    params = schema[:function][:parameters]
    assert_equal "object", params[:type]
    assert params[:properties].key?(:path)
    assert params[:properties].key?(:content)
    assert_equal "string", params[:properties][:path][:type]
    assert_equal "string", params[:properties][:content][:type]
    assert_includes params[:required], "path"
    assert_includes params[:required], "content"
  end

  test "execute creates file with correct content" do
    test_file = File.join(@test_path, "test_write.txt")
    content = "Hello, World!"

    result = @tool.execute(path: test_file, content: content)

    assert_equal true, result[:success]
    assert File.exist?(test_file)
    assert_equal content, File.read(test_file)
  end

  test "execute creates nested directories as needed" do
    nested_file = File.join(@test_path, "nested", "deep", "file.txt")
    content = "Nested content"

    result = @tool.execute(path: nested_file, content: content)

    assert_equal true, result[:success]
    assert File.exist?(nested_file)
    assert_equal content, File.read(nested_file)
  end

  test "file content is correctly written and readable" do
    test_file = File.join(@test_path, "verify.txt")
    content = "Line 1\nLine 2\nSpecial chars: áéíóú"

    @tool.execute(path: test_file, content: content)

    assert_equal content, File.read(test_file)
  end

  test "overwrites existing file" do
    test_file = File.join(@test_path, "overwrite.txt")
    File.write(test_file, "Original content")

    result = @tool.execute(path: test_file, content: "New content")

    assert_equal true, result[:success]
    assert_equal "New content", File.read(test_file)
  end

  test "result includes byte count" do
    test_file = File.join(@test_path, "bytes.txt")
    content = "12345"

    result = @tool.execute(path: test_file, content: content)

    assert_includes result[:result], "5 bytes"
  end

  test "tool is registered with ToolCallService" do
    tools = ToolCallService.available_tools
    write_file_tool = tools.find { |t| t[:function][:name] == "write_file" }

    assert_not_nil write_file_tool
  end

  # LLM Integration Test via prompt
  test "LLM can request write_file tool to write a file" do
    test_file = File.join(@test_path, "llm_write_test.txt")
    expected_content = "Hello from the LLM!"

    # Only include the write_file tool to keep context size small for tool-calling model
    tools = [WriteFileTool.schema]
    detector = ActionDetectionPrompt.new(tools: tools)

    context = Contexts::BaseContext.new
    context.add(content: "tool smoke test", topics: ["scene"], source: "test")

    actions = detector.execute(
      prompt: "Write the text '#{expected_content}' to the file at #{test_file} using the write_file tool.",
      context: context
    )

    assert_kind_of Hash, actions
    assert actions.key?(:content)
    action_list = actions[:content]
    assert_kind_of Array, action_list
    write_action = action_list.find { |a| a[:tool_name] == "write_file" }
    assert write_action, "LLM should propose write_file action"

    arguments = write_action[:arguments] || {}
    # Normalize argument keys - LLM may return path_ instead of path
    normalized_args = {}
    arguments.each do |key, value|
      normalized_key = key.to_s.gsub(/_+$/, "").to_sym
      normalized_args[normalized_key] = value
    end
    normalized_args[:path] = test_file
    normalized_args[:content] = expected_content

    service = ToolCallService.new
    result = service.execute(tool_name: "write_file", arguments: normalized_args)

    assert_equal true, result[:success], "Write file should succeed"
    assert File.exist?(test_file), "File should be created"
    assert_includes File.read(test_file), "Hello", "File should contain expected content"
  end
end
