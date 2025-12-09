require "test_helper"

class WriteFileToolTest < ActiveSupport::TestCase
  def setup
    # Use unique directory per test to avoid parallel test conflicts
    @sandbox_path = Rails.root.join("test", "tool_test", "write_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@sandbox_path)
    @tool = WriteFileTool.new(sandbox_path: @sandbox_path)
  end

  def teardown
    FileUtils.rm_rf(@sandbox_path) if @sandbox_path && File.exist?(@sandbox_path)
  end

  def chat_with_retry(client, parameters, attempts: 15, delay: 2)
    last_error = nil
    attempts.times do |i|
      begin
        return client.chat(parameters: parameters)
      rescue Faraday::ServerError, Faraday::TimeoutError, Faraday::ConnectionFailed => e
        last_error = e
        sleep(delay) if i < attempts - 1
      end
    end
    raise last_error
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
    test_file = File.join(@sandbox_path, "test_write.txt")
    content = "Hello, World!"

    result = @tool.execute(path: test_file, content: content)

    assert_equal true, result[:success]
    assert File.exist?(test_file)
    assert_equal content, File.read(test_file)
  end

  test "execute creates nested directories as needed" do
    nested_file = File.join(@sandbox_path, "nested", "deep", "file.txt")
    content = "Nested content"

    result = @tool.execute(path: nested_file, content: content)

    assert_equal true, result[:success]
    assert File.exist?(nested_file)
    assert_equal content, File.read(nested_file)
  end

  test "execute returns error when path escapes sandbox" do
    result = @tool.execute(path: "/tmp/outside_sandbox.txt", content: "test")

    assert_equal false, result[:success]
    assert_includes result[:error], "outside the sandbox"
    assert_not File.exist?("/tmp/outside_sandbox.txt")
  end

  test "execute returns error for relative path escape attempt" do
    escape_path = File.join(@sandbox_path, "..", "..", "tmp", "escape.txt")

    result = @tool.execute(path: escape_path, content: "test")

    assert_equal false, result[:success]
    assert_includes result[:error], "outside the sandbox"
  end

  test "file content is correctly written and readable" do
    test_file = File.join(@sandbox_path, "verify.txt")
    content = "Line 1\nLine 2\nSpecial chars: áéíóú"

    @tool.execute(path: test_file, content: content)

    assert_equal content, File.read(test_file)
  end

  test "overwrites existing file" do
    test_file = File.join(@sandbox_path, "overwrite.txt")
    File.write(test_file, "Original content")

    result = @tool.execute(path: test_file, content: "New content")

    assert_equal true, result[:success]
    assert_equal "New content", File.read(test_file)
  end

  test "result includes byte count" do
    test_file = File.join(@sandbox_path, "bytes.txt")
    content = "12345"

    result = @tool.execute(path: test_file, content: content)

    assert_includes result[:result], "5 bytes"
  end

  test "tool is registered with ToolCallService" do
    tools = ToolCallService.available_tools
    write_file_tool = tools.find { |t| t[:function][:name] == "write_file" }

    assert_not_nil write_file_tool
  end

  test "without sandbox allows writing to accessible locations" do
    tool_no_sandbox = WriteFileTool.new
    test_file = File.join(@sandbox_path, "no_sandbox.txt")

    result = tool_no_sandbox.execute(path: test_file, content: "test")

    assert_equal true, result[:success]
    assert File.exist?(test_file)
  end

  # LLM Integration Test
  test "LLM can request write_file tool to write a file" do
    test_file = File.join(@sandbox_path, "llm_write_test.txt")
    expected_content = "Hello from the LLM!"

    # Set up the LLM client
    client = OpenAI::Client.new(
      access_token: ENV["API_KEY"],
      uri_base: ENV["LLM_URL"],
      request_timeout: 60
    )

    # Get available tools
    tools = ToolCallService.available_tools

    # Ask LLM to write to the file
    response = chat_with_retry(
      client,
      {
        model: ENV["LLM_MODEL"] || "qwen30b",
        messages: [
          {
            role: "system",
            content: "You are a helpful assistant with access to tools. Use the write_file tool to write files."
          },
          {
            role: "user",
            content: "Write the text '#{expected_content}' to the file at #{test_file} using the write_file tool."
          }
        ],
        tools: ToolCallService.available_tools,
        tool_choice: BaseTool.tool_choice
      }
    )

    # Extract tool calls from response
    message = response.dig("choices", 0, "message")
    tool_calls = message["tool_calls"]

    assert_not_nil tool_calls, "LLM should request a tool call"
    assert tool_calls.length > 0, "LLM should request at least one tool call"

    # Find the write_file tool call
    write_file_call = tool_calls.find { |tc| tc["function"]["name"] == "write_file" }
    assert_not_nil write_file_call, "LLM should call the write_file tool"

    # Verify arguments contain path and content
    arguments = JSON.parse(write_file_call["function"]["arguments"])
    assert arguments.key?("path"), "Arguments should include path"
    assert arguments.key?("content"), "Arguments should include content"

    # Execute the tool call
    args_sym = arguments.transform_keys(&:to_sym)
    args_sym[:path] = test_file
    args_sym[:content] = expected_content
    service = ToolCallService.new(sandbox_path: @sandbox_path)
    result = service.execute(tool_name: "write_file", arguments: args_sym)

    assert_equal true, result[:success], "Write file should succeed"
    assert File.exist?(args_sym[:path]), "File should be created"
    assert_includes File.read(args_sym[:path]), "Hello", "File should contain expected content"
  end
end

