require "test_helper"

class FileTreeToolTest < ActiveSupport::TestCase
  def setup
    @sandbox_path = Rails.root.join("tmp", "file_tree_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@sandbox_path)
    @tool = FileTreeTool.new()

    # Create test directory structure
    FileUtils.mkdir_p(File.join(@sandbox_path, "lib"))
    FileUtils.mkdir_p(File.join(@sandbox_path, "app", "services"))
    File.write(File.join(@sandbox_path, "lib", "calculator.rb"), "class Calculator; end")
    File.write(File.join(@sandbox_path, "lib", "formatter.rb"), "class Formatter; end")
    File.write(File.join(@sandbox_path, "app", "services", "math_service.rb"), "class MathService; end")
    File.write(File.join(@sandbox_path, "README.md"), "# Test")
  end

  def teardown
    FileUtils.rm_rf(@sandbox_path) if @sandbox_path && File.exist?(@sandbox_path)
  end
  speed_profile :medium
  test "lists directory contents" do
    result = @tool.execute(path: @sandbox_path)

    assert result[:success]
    assert result[:result][:tree]
    assert result[:result][:formatted]
    assert_equal @sandbox_path, result[:result][:root]
  end

  speed_profile :medium
  test "counts files correctly" do
    result = @tool.execute(path: @sandbox_path)

    assert result[:success]
    assert_equal 4, result[:result][:file_count]  # 3 .rb files + README.md
  end

  speed_profile :medium
  test "counts directories correctly" do
    result = @tool.execute(path: @sandbox_path)

    assert result[:success]
    # Root + lib + app + services = 4 directories
    assert_equal 4, result[:result][:directory_count]
  end

  speed_profile :medium
  test "respects max_depth" do
    result = @tool.execute(path: @sandbox_path, max_depth: 1)

    assert result[:success]
    tree = result[:result][:tree]

    # Should have app and lib at depth 1, but not services at depth 2
    lib_dir = tree[:children].find { |c| c[:name] == "lib" }
    assert_not_nil lib_dir
    # lib's children should be empty or nil at depth 1
  end

  speed_profile :medium
  test "filters by extension" do
    result = @tool.execute(path: @sandbox_path, extensions: ["rb"])

    assert result[:success]
    assert_equal 3, result[:result][:file_count]  # Only .rb files
  end

  speed_profile :medium
  test "ignores .git directory" do
    FileUtils.mkdir_p(File.join(@sandbox_path, ".git", "objects"))
    File.write(File.join(@sandbox_path, ".git", "config"), "# git config")

    result = @tool.execute(path: @sandbox_path)

    assert result[:success]
    # .git should not appear in tree
    tree = result[:result][:tree]
    git_dir = tree[:children]&.find { |c| c[:name] == ".git" }
    assert_nil git_dir
  end

  speed_profile :medium
  test "handles non-existent path" do
    result = @tool.execute(path: File.join(@sandbox_path, "nonexistent"))

    assert_equal false, result[:success]
    assert_includes result[:error], "not found"
  end

  speed_profile :medium
  test "handles file path instead of directory" do
    file_path = File.join(@sandbox_path, "README.md")
    result = @tool.execute(path: file_path)

    assert_equal false, result[:success]
    assert_includes result[:error], "not a directory"
  end

  speed_profile :medium
  test "schema returns valid OpenAI function format" do
    schema = FileTreeTool.schema

    assert_equal "function", schema[:type]
    assert_equal "file_tree", schema[:function][:name]
    assert schema[:function][:parameters][:properties].key?(:path)
    assert_includes schema[:function][:parameters][:required], "path"
  end

  speed_profile :medium
  test "tool is registered with ToolCallService" do
    tools = ToolCallService.available_tools
    file_tree_tool = tools.find { |t| t[:function][:name] == "file_tree" }

    assert_not_nil file_tree_tool
  end

  speed_profile :medium
  test "formatted output is readable" do
    result = @tool.execute(path: @sandbox_path)

    assert result[:success]
    formatted = result[:result][:formatted]

    assert_includes formatted, "lib"
    assert_includes formatted, "calculator.rb"
    assert_includes formatted, "├──" # Tree characters
  end
end

