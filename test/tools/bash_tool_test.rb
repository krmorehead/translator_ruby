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

  # LLM Integration Test via prompt
  test "LLM can request bash tool to list files" do
    File.write(File.join(@sandbox_path, "llm_test_file.txt"), "LLM test content")

    tools = ToolCallService.available_tools
    detector = ActionDetectionPrompt.new(tools: tools)

    actions = detector.execute(
      prompt: "List all files in the directory #{@sandbox_path} using the bash tool.",
      context: { scene: "tool smoke test" }
    )

    assert_kind_of Array, actions
    bash_action = actions.find { |a| a["tool_name"] == "bash" }
    assert bash_action, "LLM should propose bash action"

    arguments = (bash_action["arguments"] || {}).transform_keys(&:to_sym)
    arguments[:command] ||= "ls #{@sandbox_path}"

    service = ToolCallService.new(sandbox_path: @sandbox_path)
    result = service.execute(tool_name: "bash", arguments: arguments)

    assert_equal true, result[:success], "Bash command should succeed"
    assert_includes result[:result], "llm_test_file.txt", "Result should include the test file"
  end
end

