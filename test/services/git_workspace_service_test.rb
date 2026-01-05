# frozen_string_literal: true

require "test_helper"

class GitWorkspaceServiceTest < ActiveSupport::TestCase
  def setup
    # OOP: Each test gets its own isolated base_path to prevent test interference
    @test_base_path = Rails.root.join("tmp", "test_git_workspaces_#{SecureRandom.hex(8)}")
    @service = GitWorkspaceService.new(base_path: @test_base_path)
    @workspace_id = "test-workspace-#{SecureRandom.hex(8)}"
  end

  def teardown
    # Clean up this test's base directory
    FileUtils.rm_rf(@test_base_path) if @test_base_path && File.exist?(@test_base_path)
  end

  speed_profile :fast
  test "initializes with default base path" do
    service = GitWorkspaceService.new
    assert_not_nil service
  end

  speed_profile :fast
  test "create_workspace initializes git repository" do
    path = @service.create_workspace(workspace_id: @workspace_id)

    assert File.exist?(path), "Workspace directory should exist"
    assert File.exist?(File.join(path, ".git")), "Git repository should be initialized"
    assert File.exist?(File.join(path, ".gitkeep")), "Initial file should exist"
  end

  speed_profile :fast
  test "create_workspace validates workspace_id parameter" do
    error = assert_raises(ArgumentError) do
      @service.create_workspace(workspace_id: "")
    end
    assert_match(/workspace_id must be a non-empty String/, error.message)

    error = assert_raises(ArgumentError) do
      @service.create_workspace(workspace_id: nil)
    end
    assert_match(/workspace_id must be a non-empty String/, error.message)
  end

  speed_profile :fast
  test "create_workspace fails if workspace already exists" do
    @service.create_workspace(workspace_id: @workspace_id)

    error = assert_raises(RuntimeError) do
      @service.create_workspace(workspace_id: @workspace_id)
    end
    assert_match(/Workspace already exists/, error.message)
  end

  speed_profile :fast
  test "workspace_path returns path to existing workspace" do
    created_path = @service.create_workspace(workspace_id: @workspace_id)
    retrieved_path = @service.workspace_path(workspace_id: @workspace_id)

    assert_equal created_path, retrieved_path
  end

  speed_profile :fast
  test "workspace_path fails for non-existent workspace" do
    error = assert_raises(RuntimeError) do
      @service.workspace_path(workspace_id: "nonexistent")
    end
    assert_match(/Workspace does not exist/, error.message)
  end

  speed_profile :fast
  test "workspace_exists? returns true for existing workspace" do
    @service.create_workspace(workspace_id: @workspace_id)
    assert @service.workspace_exists?(workspace_id: @workspace_id)
  end

  speed_profile :fast
  test "workspace_exists? returns false for non-existent workspace" do
    refute @service.workspace_exists?(workspace_id: "nonexistent")
  end

  speed_profile :fast
  test "cleanup_workspace removes workspace directory" do
    @service.create_workspace(workspace_id: @workspace_id)
    assert @service.workspace_exists?(workspace_id: @workspace_id)

    result = @service.cleanup_workspace(workspace_id: @workspace_id)
    
    assert result, "cleanup_workspace should return true"
    refute @service.workspace_exists?(workspace_id: @workspace_id), "Workspace should be removed"
  end

  speed_profile :fast
  test "cleanup_workspace returns false for non-existent workspace" do
    result = @service.cleanup_workspace(workspace_id: "nonexistent")
    refute result
  end

  speed_profile :fast
  test "cleanup_all_workspaces removes all workspaces" do
    workspace1 = "workspace-1-#{SecureRandom.hex(4)}"
    workspace2 = "workspace-2-#{SecureRandom.hex(4)}"
    
    @service.create_workspace(workspace_id: workspace1)
    @service.create_workspace(workspace_id: workspace2)

    count = @service.cleanup_all_workspaces

    assert_equal 2, count, "Should clean up 2 workspaces"
    refute @service.workspace_exists?(workspace_id: workspace1)
    refute @service.workspace_exists?(workspace_id: workspace2)
  end

  speed_profile :fast
  test "create_file creates file in workspace" do
    @service.create_workspace(workspace_id: @workspace_id)
    
    filepath = @service.create_file(
      workspace_id: @workspace_id,
      filename: "test.txt",
      content: "test content"
    )

    assert File.exist?(filepath), "File should be created"
    assert_equal "test content", File.read(filepath)
  end

  speed_profile :fast
  test "commit_changes commits and returns SHA" do
    @service.create_workspace(workspace_id: @workspace_id)
    @service.create_file(
      workspace_id: @workspace_id,
      filename: "new_file.txt",
      content: "new content"
    )

    sha = @service.commit_changes(
      workspace_id: @workspace_id,
      message: "Add new file"
    )

    assert sha.is_a?(String), "Should return commit SHA"
    assert_equal 40, sha.length, "SHA should be 40 characters"
  end

  speed_profile :fast
  test "isolated workspaces don't interfere with each other" do
    workspace1 = "isolated-1-#{SecureRandom.hex(4)}"
    workspace2 = "isolated-2-#{SecureRandom.hex(4)}"

    path1 = @service.create_workspace(workspace_id: workspace1)
    path2 = @service.create_workspace(workspace_id: workspace2)

    # Create files in each workspace
    @service.create_file(workspace_id: workspace1, filename: "file1.txt", content: "content1")
    @service.create_file(workspace_id: workspace2, filename: "file2.txt", content: "content2")

    # Verify isolation
    assert File.exist?(File.join(path1, "file1.txt"))
    refute File.exist?(File.join(path1, "file2.txt"))
    
    assert File.exist?(File.join(path2, "file2.txt"))
    refute File.exist?(File.join(path2, "file1.txt"))

    # Cleanup
    @service.cleanup_workspace(workspace_id: workspace1)
    @service.cleanup_workspace(workspace_id: workspace2)
  end
end

