require "test_helper"

class BashToolTest < ActiveSupport::TestCase
  def setup
    # Use unique directory per test to avoid parallel test conflicts
    @sandbox_path = Rails.root.join("test", "tool_test", "bash_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@sandbox_path)
    @tool = BashTool.new(sandbox_path: @sandbox_path)
  end

  def teardown
    FileUtils.rm_rf(@sandbox_path) if @sandbox_path && File.exist?(@sandbox_path)
  end

  def chat_with_retry(client, parameters, attempts: 5, delay: 2)
    last_error = nil
    attempts.times do |i|
      begin
        return client.chat(parameters: parameters)
      rescue Faraday::ServerError => e
        last_error = e
        sleep(delay) if i < attempts - 1
      end
    end
    raise last_error
  end

  test "schema returns valid OpenAI function format with command parameter" do
    schema = BashTool.schema

    assert_equal "function", schema[:type]
    assert_equal "bash", schema[:function][:name]
    assert_equal "Execute a bash command and return the output", schema[:function][:description]

    params = schema[:function][:parameters]
    assert_equal "object", params[:type]
    assert params[:properties].key?(:command)
    assert_equal "string", params[:properties][:command][:type]
    assert_includes params[:required], "command"
  end

  test "execute runs command and returns stdout" do
    result = @tool.execute(command: "echo 'Hello, World!'")

    assert_equal true, result[:success]
    assert_equal "Hello, World!\n", result[:result]
  end

  test "execute captures stderr on failure" do
    result = @tool.execute(command: "ls /nonexistent_directory_12345")

    assert_equal false, result[:success]
    assert_includes result[:error], "No such file or directory"
  end

  test "execute includes exit status on success" do
    result = @tool.execute(command: "true")

    assert_equal 0, result[:exit_status]
  end

  test "execute includes exit status on failure" do
    result = @tool.execute(command: "exit 42")

    assert_equal 42, result[:exit_status]
  end

  test "ls command on test/tool_test directory" do
    # Create some test files
    File.write(File.join(@sandbox_path, "file1.txt"), "content1")
    File.write(File.join(@sandbox_path, "file2.txt"), "content2")

    result = @tool.execute(command: "ls #{@sandbox_path}")

    assert_equal true, result[:success]
    assert_includes result[:result], "file1.txt"
    assert_includes result[:result], "file2.txt"
  end

  test "tool is registered with ToolCallService" do
    tools = ToolCallService.available_tools
    bash_tool = tools.find { |t| t[:function][:name] == "bash" }

    assert_not_nil bash_tool
  end

  test "handles commands with pipes" do
    result = @tool.execute(command: "echo 'line1\nline2\nline3' | wc -l")

    assert_equal true, result[:success]
    assert_match(/3/, result[:result])
  end

  test "handles commands with environment variables" do
    result = @tool.execute(command: "echo $HOME")

    assert_equal true, result[:success]
    assert_not_empty result[:result].strip
  end

  # LLM Integration Test
  test "LLM can request bash tool to list files" do
    # Create test files for the LLM to discover
    File.write(File.join(@sandbox_path, "llm_test_file.txt"), "LLM test content")

    # Set up the LLM client (similar to TranslationService)
    client = OpenAI::Client.new(
      access_token: ENV["API_KEY"],
      uri_base: ENV["LLM_URL"],
      request_timeout: 60
    )

    # Get available tools
    tools = ToolCallService.available_tools

    # Ask LLM to list files in the sandbox directory
    response = chat_with_retry(
      client,
      {
        model: ENV["LLM_MODEL"] || "qwen30b",
        messages: [
          {
            role: "system",
            content: "You are a helpful assistant with access to tools. Use the bash tool to complete tasks."
          },
          {
            role: "user",
            content: "List all files in the directory #{@sandbox_path} using the bash tool."
          }
        ],
        tools: tools,
        tool_choice: "auto"
      }
    )

    # Extract tool calls from response
    message = response.dig("choices", 0, "message")
    tool_calls = message["tool_calls"]

    assert_not_nil tool_calls, "LLM should request a tool call"
    assert tool_calls.length > 0, "LLM should request at least one tool call"

    # Find the bash tool call
    bash_call = tool_calls.find { |tc| tc["function"]["name"] == "bash" }
    assert_not_nil bash_call, "LLM should call the bash tool"

    # Execute the tool call
    arguments = JSON.parse(bash_call["function"]["arguments"])
    service = ToolCallService.new(sandbox_path: @sandbox_path)
    result = service.execute(tool_name: "bash", arguments: arguments)

    assert_equal true, result[:success], "Bash command should succeed"
    assert_includes result[:result], "llm_test_file.txt", "Result should include the test file"
  end
end

