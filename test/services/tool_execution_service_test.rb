# frozen_string_literal: true

require "test_helper"

class ToolExecutionServiceTest < ActiveSupport::TestCase
  def setup
    @service = ToolExecutionService.new
    @test_dir = Rails.root.join("test", "fixtures", "sample_project")
  end

  speed_profile :fast
  test "initializes successfully" do
    assert_instance_of ToolExecutionService, @service
  end

  # execute_tool tests
  speed_profile :medium
  test "execute_tool with file_tree calls FileTreeTool" do
    FileUtils.mkdir_p(@test_dir)
    
    result = @service.execute_tool(
      tool_name: :file_tree,
      params: { path: @test_dir.to_s, max_depth: 2 }
    )

    assert result[:success]
    assert result[:data]
    assert_nil result[:error]
  ensure
    FileUtils.rm_rf(@test_dir) if @test_dir.exist?
  end

  speed_profile :medium
  test "execute_tool with read_file calls ReadFileTool" do
    file_path = @test_dir.join("sample_file.rb")
    FileUtils.mkdir_p(@test_dir)
    File.write(file_path, "# Sample Ruby file\nputs 'hello'")

    result = @service.execute_tool(
      tool_name: :read_file,
      params: { path: file_path.to_s }
    )

    assert result[:success]
    assert_includes result[:data], "Sample Ruby file"
    assert_nil result[:error]
  ensure
    FileUtils.rm_rf(@test_dir) if @test_dir.exist?
  end

  speed_profile :medium
  test "execute_tool with grep calls GrepTool" do
    FileUtils.mkdir_p(@test_dir)
    File.write(@test_dir.join("test.rb"), "class TestClass\nend")

    result = @service.execute_tool(
      tool_name: :grep,
      params: { path: @test_dir.to_s, pattern: "class" }
    )

    assert result[:success]
    assert result[:data]
    assert_nil result[:error]
  ensure
    FileUtils.rm_rf(@test_dir) if @test_dir.exist?
  end

  speed_profile :fast
  test "execute_tool validates tool_name is a Symbol" do
    result = @service.execute_tool(tool_name: "file_tree", params: {})
    
    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/tool_name must be a Symbol/, result[:error])
  end

  speed_profile :fast
  test "execute_tool validates params is a Hash" do
    result = @service.execute_tool(tool_name: :file_tree, params: "invalid")
    
    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/params must be a Hash/, result[:error])
  end

  speed_profile :fast
  test "execute_tool returns error for unknown tool" do
    result = @service.execute_tool(
      tool_name: :unknown_tool,
      params: {}
    )

    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/Unknown tool/, result[:error])
  end

  speed_profile :medium
  test "execute_tool handles tool execution errors gracefully" do
    result = @service.execute_tool(
      tool_name: :read_file,
      params: { path: "/nonexistent/file.rb" }
    )

    assert_not result[:success]
    assert_nil result[:data]
    assert result[:error]
  end

  # list_directory tests
  speed_profile :medium
  test "list_directory wraps FileTreeTool" do
    FileUtils.mkdir_p(@test_dir)
    File.write(@test_dir.join("file1.rb"), "content")

    result = @service.list_directory(path: @test_dir.to_s)

    assert result[:success]
    assert result[:data]
    assert result[:data][:tree]
    assert_nil result[:error]
  ensure
    FileUtils.rm_rf(@test_dir) if @test_dir.exist?
  end

  speed_profile :medium
  test "list_directory accepts options" do
    FileUtils.mkdir_p(@test_dir)

    result = @service.list_directory(
      path: @test_dir.to_s,
      options: { max_depth: 1, extensions: ["rb"] }
    )

    assert result[:success]
  ensure
    FileUtils.rm_rf(@test_dir) if @test_dir.exist?
  end

  speed_profile :fast
  test "list_directory validates path is a String" do
    result = @service.list_directory(path: 123)
    
    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/path must be a String/, result[:error])
  end

  speed_profile :fast
  test "list_directory validates options is a Hash" do
    result = @service.list_directory(path: @test_dir.to_s, options: "invalid")
    
    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/options must be a Hash/, result[:error])
  end

  # read_file tests
  speed_profile :medium
  test "read_file wraps ReadFileTool" do
    FileUtils.mkdir_p(@test_dir)
    file_path = @test_dir.join("test.txt")
    File.write(file_path, "test content")

    result = @service.read_file(path: file_path.to_s)

    assert result[:success]
    assert_equal "test content", result[:data]
    assert_nil result[:error]
  ensure
    FileUtils.rm_rf(@test_dir) if @test_dir.exist?
  end

  speed_profile :fast
  test "read_file validates path is a String" do
    result = @service.read_file(path: nil)
    
    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/path must be a String/, result[:error])
  end

  speed_profile :medium
  test "read_file returns error for nonexistent file" do
    result = @service.read_file(path: "/nonexistent/file.txt")

    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/not found/i, result[:error])
  end

  # search_files tests
  speed_profile :medium
  test "search_files wraps GrepTool" do
    FileUtils.mkdir_p(@test_dir)
    File.write(@test_dir.join("test.rb"), "class MyClass\nend")

    result = @service.search_files(
      path: @test_dir.to_s,
      pattern: "MyClass"
    )

    assert result[:success]
    assert result[:data]
    assert_nil result[:error]
  ensure
    FileUtils.rm_rf(@test_dir) if @test_dir.exist?
  end

  speed_profile :medium
  test "search_files accepts options" do
    FileUtils.mkdir_p(@test_dir)
    File.write(@test_dir.join("test.rb"), "test")

    result = @service.search_files(
      path: @test_dir.to_s,
      pattern: "test",
      options: { max_results: 5, case_insensitive: true }
    )

    assert result[:success]
  ensure
    FileUtils.rm_rf(@test_dir) if @test_dir.exist?
  end

  speed_profile :fast
  test "search_files validates path is a String" do
    result = @service.search_files(path: 123, pattern: "test")
    
    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/path must be a String/, result[:error])
  end

  speed_profile :fast
  test "search_files validates pattern is a String" do
    result = @service.search_files(path: @test_dir.to_s, pattern: nil)
    
    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/pattern must be a String/, result[:error])
  end

  speed_profile :fast
  test "search_files validates options is a Hash" do
    result = @service.search_files(
      path: @test_dir.to_s,
      pattern: "test",
      options: "invalid"
    )
    
    assert_not result[:success]
    assert_nil result[:data]
    assert_match(/options must be a Hash/, result[:error])
  end

  # Response standardization tests
  speed_profile :medium
  test "standardizes successful tool responses" do
    FileUtils.mkdir_p(@test_dir)
    File.write(@test_dir.join("test.txt"), "content")

    result = @service.read_file(path: @test_dir.join("test.txt").to_s)

    assert result.key?(:success)
    assert result.key?(:data)
    assert result.key?(:error)
    assert result[:success]
    assert result[:data]
    assert_nil result[:error]
  ensure
    FileUtils.rm_rf(@test_dir) if @test_dir.exist?
  end

  speed_profile :medium
  test "standardizes error tool responses" do
    result = @service.read_file(path: "/nonexistent.txt")

    assert result.key?(:success)
    assert result.key?(:data)
    assert result.key?(:error)
    assert_not result[:success]
    assert_nil result[:data]
    assert result[:error]
  end
end
