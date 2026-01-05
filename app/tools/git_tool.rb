# frozen_string_literal: true

# Tool for Git operations following standard tool patterns
# Handles git commands in isolated workspaces
#
# Following OOP principles:
# - Fail loudly on git errors
# - Real git operations (no stubs/mocks)
# - Standardized tool interface
class GitTool < BaseTool
  ACTIONS = %i[init config add commit status diff log].freeze

  def self.schema
    {
      type: "function",
      function: {
        name: "git",
        description: "Execute git commands in a repository",
        parameters: {
          type: "object",
          properties: {
            action: {
              type: "string",
              enum: ACTIONS.map(&:to_s),
              description: "Git action to perform"
            },
            path: {
              type: "string",
              description: "Repository path"
            },
            message: {
              type: "string",
              description: "Commit message (for commit action)"
            },
            files: {
              type: "array",
              items: { type: "string" },
              description: "Files to add (for add action)"
            },
            key: {
              type: "string",
              description: "Config key (for config action)"
            },
            value: {
              type: "string",
              description: "Config value (for config action)"
            }
          },
          required: ["action", "path"]
        }
      }
    }
  end

  def execute(params)
    # OOP: Structural errors (params, action) raise immediately
    validate_params!(params)
    
    action = params[:action].to_sym
    
    # OOP: Invalid actions return error results (operational error)
    unless ACTIONS.include?(action)
      return error_result("Invalid action '#{action}'. Must be one of: #{ACTIONS.join(', ')}")
    end

    path = params[:path]
    raise ArgumentError, "path must be a non-empty String" unless path.is_a?(String) && !path.strip.empty?
    
    begin
      result = send("action_#{action}", params)
      success_result(result)
    rescue StandardError => e
      error_result("Git #{action} failed: #{e.message}", error: e)
    end
  end

  private

  # Initialize a new git repository
  def action_init(params)
    path = params[:path]
    
    # OOP: Ensure directory exists before trying to initialize git
    raise ArgumentError, "path does not exist: #{path}" unless File.exist?(path)
    raise ArgumentError, "path is not a directory: #{path}" unless File.directory?(path)

    output = execute_git_command(path, "init")
    { message: "Initialized git repository", output: output }
  end

  # Configure git settings
  def action_config(params)
    path = params[:path]
    key = params.fetch(:key)
    value = params.fetch(:value)

    output = execute_git_command(path, "config", key, value)
    { message: "Set #{key} = #{value}", output: output }
  end

  # Add files to staging
  def action_add(params)
    path = params[:path]
    files = params[:files] || ["-A"]  # Default to all files

    output = execute_git_command(path, "add", *files)
    { message: "Added files to staging", files: files, output: output }
  end

  # Commit staged changes
  def action_commit(params)
    path = params[:path]
    message = params.fetch(:message)

    output = execute_git_command(path, "commit", "-m", message)
    sha = get_commit_sha(path)
    
    { message: "Committed changes", commit_sha: sha, output: output }
  end

  # Get repository status
  def action_status(params)
    path = params[:path]
    output = execute_git_command(path, "status", "--porcelain")
    
    { status: output, clean: output.strip.empty? }
  end

  # Get diff of changes
  def action_diff(params)
    path = params[:path]
    output = execute_git_command(path, "diff")
    
    { diff: output }
  end

  # Get commit log
  def action_log(params)
    path = params[:path]
    limit = params[:limit] || 10
    
    output = execute_git_command(path, "log", "--oneline", "-n", limit.to_s)
    commits = output.split("\n").map do |line|
      sha, *message_parts = line.split(" ")
      { sha: sha, message: message_parts.join(" ") }
    end
    
    { commits: commits }
  end

  # Execute a git command in the given path
  # @param path [String] Repository path
  # @param args [Array] Git command arguments
  # @return [String] Command output
  # @raise [RuntimeError] If command fails
  def execute_git_command(path, *args)
    Dir.chdir(path) do
      command = ["git", *args].shelljoin
      output = `#{command} 2>&1`
      
      unless $?.success?
        raise RuntimeError, "Git command failed (exit #{$?.exitstatus}): #{command}\nOutput: #{output}"
      end
      
      output
    end
  end

  # Get the current commit SHA
  # @param path [String] Repository path
  # @return [String] Commit SHA
  def get_commit_sha(path)
    Dir.chdir(path) do
      sha = `git rev-parse HEAD 2>&1`.strip
      unless $?.success? && sha.length == 40
        raise RuntimeError, "Failed to get commit SHA: #{sha}"
      end
      sha
    end
  end

  # Format success result
  def success_result(data)
    {
      success: true,
      result: data,
      error: nil
    }
  end

  # Format error result
  def error_result(message, error: nil)
    {
      success: false,
      result: nil,
      error: message
    }
  end

  # Validate required parameters
  def validate_params!(params)
    raise ArgumentError, "params must be a Hash" unless params.is_a?(Hash)
    raise ArgumentError, "action parameter is required" unless params.key?(:action)
    raise ArgumentError, "path parameter is required" unless params.key?(:path)
  end
end

