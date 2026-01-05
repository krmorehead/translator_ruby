# frozen_string_literal: true

require "test_helper"

class GitToolTest < ActiveSupport::TestCase
  def setup
    @tool = GitTool.new
    @test_dir = Rails.root.join("tmp", "git_tool_test_#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(@test_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_dir) if @test_dir && File.exist?(@test_dir)
  end

  speed_profile :fast
  test "schema returns valid OpenAI function format" do
    schema = GitTool.schema

    assert_equal "function", schema[:type]
    assert_equal "git", schema[:function][:name]
    assert schema[:function][:description].is_a?(String)
    assert schema[:function][:parameters][:properties][:action]
  end

  speed_profile :fast
  test "execute validates params parameter" do
    error = assert_raises(ArgumentError) do
      @tool.execute("not a hash")
    end
    assert_match(/params must be a Hash/, error.message)
  end

  speed_profile :fast
  test "execute validates action is present" do
    error = assert_raises(ArgumentError) do
      @tool.execute(path: @test_dir.to_s)
    end
    assert_match(/action parameter is required/, error.message)
  end

  speed_profile :fast
  test "execute validates path is present" do
    error = assert_raises(ArgumentError) do
      @tool.execute(action: "init")
    end
    assert_match(/path parameter is required/, error.message)
  end

  speed_profile :fast
  test "execute validates action is valid" do
    result = @tool.execute(action: "invalid", path: @test_dir.to_s)
    
    refute result[:success]
    assert_match(/Invalid action/, result[:error])
  end

  speed_profile :fast
  test "action_init initializes git repository" do
    result = @tool.execute(action: "init", path: @test_dir.to_s)

    assert result[:success]
    assert result[:result][:message]
    assert File.exist?(File.join(@test_dir, ".git"))
  end

  speed_profile :fast
  test "action_config sets git configuration" do
    @tool.execute(action: "init", path: @test_dir.to_s)
    
    result = @tool.execute(
      action: "config",
      path: @test_dir.to_s,
      key: "user.name",
      value: "Test User"
    )

    assert result[:success]
    assert_match(/Set user.name/, result[:result][:message])
  end

  speed_profile :fast
  test "action_add stages files" do
    @tool.execute(action: "init", path: @test_dir.to_s)
    File.write(File.join(@test_dir, "test.txt"), "content")
    
    result = @tool.execute(
      action: "add",
      path: @test_dir.to_s,
      files: ["test.txt"]
    )

    assert result[:success]
    assert_equal ["test.txt"], result[:result][:files]
  end

  speed_profile :fast
  test "action_commit creates commit" do
    # Initialize and configure
    @tool.execute(action: "init", path: @test_dir.to_s)
    @tool.execute(action: "config", path: @test_dir.to_s, key: "user.name", value: "Test")
    @tool.execute(action: "config", path: @test_dir.to_s, key: "user.email", value: "test@test.com")
    
    # Create and add file
    File.write(File.join(@test_dir, "test.txt"), "content")
    @tool.execute(action: "add", path: @test_dir.to_s, files: ["test.txt"])
    
    # Commit
    result = @tool.execute(
      action: "commit",
      path: @test_dir.to_s,
      message: "Test commit"
    )

    assert result[:success]
    assert result[:result][:commit_sha]
    assert_equal 40, result[:result][:commit_sha].length
  end

  speed_profile :fast
  test "action_status returns repository status" do
    @tool.execute(action: "init", path: @test_dir.to_s)
    
    result = @tool.execute(action: "status", path: @test_dir.to_s)

    assert result[:success]
    assert result[:result].key?(:status)
    assert result[:result].key?(:clean)
  end

  speed_profile :fast
  test "action_log returns commit history" do
    # Setup repository with a commit
    @tool.execute(action: "init", path: @test_dir.to_s)
    @tool.execute(action: "config", path: @test_dir.to_s, key: "user.name", value: "Test")
    @tool.execute(action: "config", path: @test_dir.to_s, key: "user.email", value: "test@test.com")
    File.write(File.join(@test_dir, "test.txt"), "content")
    @tool.execute(action: "add", path: @test_dir.to_s, files: ["test.txt"])
    @tool.execute(action: "commit", path: @test_dir.to_s, message: "Initial commit")
    
    result = @tool.execute(action: "log", path: @test_dir.to_s, limit: 5)

    assert result[:success]
    assert result[:result][:commits].is_a?(Array)
    assert_equal 1, result[:result][:commits].length
    assert result[:result][:commits].first[:sha]
    assert result[:result][:commits].first[:message]
  end

  speed_profile :fast
  test "returns error result on git command failure" do
    # Try to commit without staging anything
    @tool.execute(action: "init", path: @test_dir.to_s)
    @tool.execute(action: "config", path: @test_dir.to_s, key: "user.name", value: "Test")
    @tool.execute(action: "config", path: @test_dir.to_s, key: "user.email", value: "test@test.com")
    
    result = @tool.execute(action: "commit", path: @test_dir.to_s, message: "Empty commit")

    refute result[:success]
    assert result[:error].is_a?(String)
    assert_match(/Git commit failed/, result[:error])
  end

  speed_profile :fast
  test "follows standard tool result format" do
    result = @tool.execute(action: "init", path: @test_dir.to_s)

    assert result.key?(:success)
    assert result.key?(:result)
    assert result.key?(:error)
    assert result[:success] == true || result[:success] == false
  end
end

