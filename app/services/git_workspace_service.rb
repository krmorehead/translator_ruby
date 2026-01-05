# frozen_string_literal: true

# Service for managing isolated git workspaces per workflow/test
# Prevents race conditions and lock contention by giving each workflow its own git repo
#
# Following OOP principles:
# - Fail loudly if git operations fail
# - No stubs or mocks - real git repositories
# - Proper isolation and cleanup
# - Uses GitTool for all git operations (standardized interface)
class GitWorkspaceService
  # Initialize a new git workspace manager
  # @param base_path [String] Base directory for workspaces (defaults to tmp)
  def initialize(base_path: nil)
    @base_path = base_path || Rails.root.join("tmp", "git_workspaces")
    @git_tool = GitTool.new
    FileUtils.mkdir_p(@base_path)
  end

  # Create an isolated git workspace for a workflow
  # @param workspace_id [String] Unique identifier (e.g., owner_id, workflow_id)
  # @return [String] Path to the initialized git workspace
  # @raise [RuntimeError] If git initialization fails
  def create_workspace(workspace_id:)
    raise ArgumentError, "workspace_id must be a non-empty String" unless workspace_id.is_a?(String) && !workspace_id.strip.empty?

    workspace_path = File.join(@base_path, workspace_id)

    # OOP: Fail loudly if workspace already exists (shouldn't happen in tests)
    if File.exist?(workspace_path)
      raise RuntimeError, "Workspace already exists: #{workspace_path}. Call cleanup_workspace first."
    end

    # Create workspace directory
    FileUtils.mkdir_p(workspace_path)

    # Initialize git repository using GitTool
    result = @git_tool.execute(action: :init, path: workspace_path)
    raise RuntimeError, "Failed to initialize git repository: #{result[:error]}" unless result[:success]

    # Configure git for automated commits
    @git_tool.execute(action: :config, path: workspace_path, key: "user.name", value: "Test Workflow")
    @git_tool.execute(action: :config, path: workspace_path, key: "user.email", value: "test@workflow.local")

    # Create initial commit so we have a valid HEAD
    File.write(File.join(workspace_path, ".gitkeep"), "# Workspace for #{workspace_id}\n")
    
    add_result = @git_tool.execute(action: :add, path: workspace_path, files: [".gitkeep"])
    raise RuntimeError, "Failed to add initial file: #{add_result[:error]}" unless add_result[:success]
    
    commit_result = @git_tool.execute(
      action: :commit,
      path: workspace_path,
      message: "Initial commit for workspace #{workspace_id}"
    )
    raise RuntimeError, "Failed to create initial commit: #{commit_result[:error]}" unless commit_result[:success]

    workspace_path
  end

  # Get the path to an existing workspace
  # @param workspace_id [String] Unique identifier
  # @return [String] Path to the workspace
  # @raise [RuntimeError] If workspace doesn't exist
  def workspace_path(workspace_id:)
    raise ArgumentError, "workspace_id must be a non-empty String" unless workspace_id.is_a?(String) && !workspace_id.strip.empty?

    path = File.join(@base_path, workspace_id)
    raise RuntimeError, "Workspace does not exist: #{path}" unless File.exist?(path)
    
    path
  end

  # Check if a workspace exists
  # @param workspace_id [String] Unique identifier
  # @return [Boolean] True if workspace exists
  def workspace_exists?(workspace_id:)
    return false unless workspace_id.is_a?(String) && !workspace_id.strip.empty?
    File.exist?(File.join(@base_path, workspace_id))
  end

  # Find existing workspace or create new one
  # @param workspace_id [String] Unique workspace identifier
  # @return [String] Path to the workspace
  def find_or_create_workspace(workspace_id:)
    if workspace_exists?(workspace_id: workspace_id)
      workspace_path(workspace_id: workspace_id)
    else
      create_workspace(workspace_id: workspace_id)
    end
  end

  # Clean up a workspace (remove directory and all contents)
  # @param workspace_id [String] Unique identifier
  # @return [Boolean] True if cleaned up successfully
  def cleanup_workspace(workspace_id:)
    raise ArgumentError, "workspace_id must be a non-empty String" unless workspace_id.is_a?(String) && !workspace_id.strip.empty?

    workspace_path = File.join(@base_path, workspace_id)
    return false unless File.exist?(workspace_path)

    FileUtils.rm_rf(workspace_path)
    true
  end

  # Clean up all workspaces (for test teardown)
  # @return [Integer] Number of workspaces cleaned up
  def cleanup_all_workspaces
    return 0 unless File.exist?(@base_path)

    count = 0
    Dir.children(@base_path).each do |workspace_id|
      workspace_path = File.join(@base_path, workspace_id)
      next unless File.directory?(workspace_path)
      
      FileUtils.rm_rf(workspace_path)
      count += 1
    end
    count
  end

  # Create a test file in the workspace (for testing checkpoint creation)
  # @param workspace_id [String] Unique identifier
  # @param filename [String] Name of file to create
  # @param content [String] File content
  # @return [String] Full path to created file
  def create_file(workspace_id:, filename:, content:)
    workspace = workspace_path(workspace_id: workspace_id)
    filepath = File.join(workspace, filename)
    File.write(filepath, content)
    filepath
  end

  # Commit changes in a workspace
  # @param workspace_id [String] Unique identifier
  # @param message [String] Commit message
  # @return [String] Commit SHA
  # @raise [RuntimeError] If commit fails
  def commit_changes(workspace_id:, message:)
    workspace = workspace_path(workspace_id: workspace_id)
    
    # Add all changes using GitTool
    add_result = @git_tool.execute(action: :add, path: workspace, files: ["-A"])
    raise RuntimeError, "Failed to add files: #{add_result[:error]}" unless add_result[:success]
    
    # Commit using GitTool
    commit_result = @git_tool.execute(action: :commit, path: workspace, message: message)
    raise RuntimeError, "Failed to commit: #{commit_result[:error]}" unless commit_result[:success]
    
    commit_result[:result][:commit_sha]
  end

  # Get workspace status
  # @param workspace_id [String] Unique identifier
  # @return [Hash] Status information
  def status(workspace_id:)
    workspace = workspace_path(workspace_id: workspace_id)
    result = @git_tool.execute(action: :status, path: workspace)
    
    raise RuntimeError, "Failed to get status: #{result[:error]}" unless result[:success]
    result[:result]
  end

  # Get commit log
  # @param workspace_id [String] Unique identifier
  # @param limit [Integer] Number of commits to retrieve
  # @return [Array<Hash>] Commit information
  def log(workspace_id:, limit: 10)
    workspace = workspace_path(workspace_id: workspace_id)
    result = @git_tool.execute(action: :log, path: workspace, limit: limit)
    
    raise RuntimeError, "Failed to get log: #{result[:error]}" unless result[:success]
    result[:result][:commits]
  end
end
