# frozen_string_literal: true

# Service for managing Git checkpoints during Sisyphus execution.
# Creates commits at milestone boundaries, stores metadata in git notes,
# and provides checkpoint inspection and diffing capabilities.
#
# @example Basic usage
#   service = CheckpointService.new(path: "/path/to/repo")
#   checkpoint_id = service.create_checkpoint("Milestone 1 complete", milestone_id: "m1")
#   diff = service.diff_since_checkpoint(checkpoint_id)
#
# @example With metadata
#   checkpoint_id = service.create_checkpoint(
#     "Step execution complete",
#     milestone_id: "m1",
#     step_ids: ["s1", "s2"],
#     worker_id: "worker_123"
#   )
class CheckpointService
  attr_reader :path, :options

  DEFAULT_OPTIONS = {
    auto_commit: true,
    commit_prefix: "Sisyphus"
  }.freeze

  # Initialize the checkpoint service
  #
  # @param path [String] Path to git repository root
  # @param memory_store [WorkflowMemoryStore, nil] Optional memory store for generating contextual messages
  # @param auto_commit [Boolean] Whether to auto-commit (default: true)
  # @param commit_prefix [String] Prefix for commit messages (default: "Sisyphus")
  # @raise [ArgumentError] If path is not a git repository
  def initialize(path:, memory_store: nil, **options)
    @path = File.expand_path(path)
    @memory_store = memory_store
    @options = DEFAULT_OPTIONS.merge(options)
    
    validate_git_repository!
  end

  # Create a checkpoint (git commit) with metadata
  #
  # @param message [String] Commit message
  # @param milestone_id [String, nil] Optional milestone ID
  # @param step_ids [Array<String>, nil] Optional step IDs
  # @param worker_id [String, nil] Optional worker ID
  # @param execution_id [String, nil] Optional execution ID
  # @param backup [Boolean, nil] Whether this is a backup checkpoint
  # @return [Checkpoint] Checkpoint object
  # @raise [RuntimeError] If commit fails
  def create_checkpoint(message, milestone_id: nil, step_ids: nil, worker_id: nil, execution_id: nil, backup: nil)
    raise ArgumentError, "message must be a String" unless message.is_a?(String)
    
    # Build full commit message with prefix
    full_message = build_commit_message(message)
    
    # Create the commit
    checkpoint_id = create_git_commit(full_message)
    
    # Build metadata
    metadata = build_metadata(milestone_id, step_ids, worker_id, execution_id, backup)
    
    # Store metadata in git notes
    store_metadata(checkpoint_id, metadata) unless metadata.empty?
    
    # Get files changed in this commit
    files_changed = get_files_changed(checkpoint_id)
    
    # Create and return Checkpoint object
    Checkpoint.new(
      id: checkpoint_id,
      message: full_message,
      created_at: Time.now.utc,
      metadata: metadata,
      files_changed: files_changed
    )
  end

  # List recent checkpoints
  #
  # @param limit [Integer] Maximum number of checkpoints to return (default: 20)
  # @return [Array<Checkpoint>] Array of checkpoint objects
  def list_checkpoints(limit: 20)
    raise ArgumentError, "limit must be a positive Integer" unless limit.is_a?(Integer) && limit > 0
    
    result = run_git_command("log --pretty=format:'%H|%s|%at' -n #{limit}")
    return [] if result[:output].empty?
    
    result[:output].split("\n").map do |line|
      hash, message, timestamp = line.split("|", 3)
      
      # Get metadata for this checkpoint
      metadata = checkpoint_metadata(hash)
      
      # Create Checkpoint object
      Checkpoint.new(
        id: hash,
        message: message,
        created_at: Time.at(timestamp.to_i),
        metadata: metadata,
        files_changed: [] # Don't fetch files for list (performance)
      )
    end
  end

  # Get details for a specific checkpoint
  #
  # @param checkpoint_id [String] Git commit hash
  # @return [Checkpoint, nil] Checkpoint object or nil if not found
  def get_checkpoint(checkpoint_id)
    return nil unless validate_checkpoint(checkpoint_id)
    
    # Get commit info
    result = run_git_command("show --no-patch --pretty=format:'%H|%s|%at' #{checkpoint_id}")
    return nil unless result[:success]
    
    hash, message, timestamp = result[:output].strip.split("|", 3)
    
    # Get files changed in this commit
    files_changed = get_files_changed(checkpoint_id)
    
    # Get metadata
    metadata = checkpoint_metadata(checkpoint_id)
    
    # Create and return Checkpoint object
    Checkpoint.new(
      id: hash,
      message: message,
      created_at: Time.at(timestamp.to_i),
      files_changed: files_changed,
      metadata: metadata
    )
  end

  # Generate diff between two checkpoints
  #
  # @param checkpoint_id [String] First checkpoint
  # @param other_checkpoint_id [String, nil] Second checkpoint (nil for HEAD)
  # @return [String] Unified diff
  def diff_checkpoint(checkpoint_id, other_checkpoint_id = nil)
    raise ArgumentError, "checkpoint_id is required" if checkpoint_id.nil?
    
    if other_checkpoint_id
      cmd = "diff #{checkpoint_id} #{other_checkpoint_id}"
    else
      cmd = "diff #{checkpoint_id}"
    end
    
    result = run_git_command(cmd)
    result[:output]
  end

  # Generate diff of current changes since a checkpoint
  #
  # @param checkpoint_id [String] Checkpoint to diff against
  # @return [String] Unified diff of uncommitted changes
  def diff_since_checkpoint(checkpoint_id)
    raise ArgumentError, "checkpoint_id is required" if checkpoint_id.nil?
    
    result = run_git_command("diff #{checkpoint_id}")
    result[:output]
  end

  # Validate that a checkpoint exists
  #
  # @param checkpoint_id [String] Git commit hash
  # @return [Boolean] True if checkpoint exists
  def validate_checkpoint(checkpoint_id)
    return false if checkpoint_id.nil? || checkpoint_id.empty?
    
    result = run_git_command("cat-file -t #{checkpoint_id}")
    result[:success] && result[:output].strip == "commit"
  end

  # Check if there are uncommitted changes in the working directory
  #
  # @return [Boolean] True if there are uncommitted changes (staged or unstaged, excluding untracked)
  def has_uncommitted_changes?
    # Only check for modifications to tracked files, not untracked files
    result = run_git_command("diff HEAD")
    !result[:output].strip.empty?
  end

  # Get the current commit ID (HEAD)
  #
  # @return [String] The current commit hash
  def current_commit_id
    result = run_git_command("rev-parse HEAD")
    raise RuntimeError, "Failed to get current commit: #{result[:output]}" unless result[:success]
    result[:output].strip
  end

  # Get current checkpoint ID, creating a new checkpoint if codebase has changed
  #
  # @return [String] Checkpoint ID (commit hash)
  def current_checkpoint_id
    # Initialize cached checkpoint to HEAD if not set
    @current_checkpoint ||= get_checkpoint(current_commit_id)

    # If no changes, return cached checkpoint
    return @current_checkpoint.id unless has_uncommitted_changes?

    # Changes detected - create new checkpoint
    message = "Checkpoint at #{Time.now.utc.iso8601}"
    checkpoint = create_checkpoint(message)
    @current_checkpoint = checkpoint
    checkpoint.id
  end

  # Check if there are uncommitted changes in the working directory
  #
  # @return [Boolean] True if there are changes to tracked files
  def has_uncommitted_changes?
    # Check for modifications to tracked files only
    result = run_git_command("diff HEAD")
    !result[:output].strip.empty?
  end

  # Retrieve metadata for a checkpoint
  #
  # @param checkpoint_id [String] Git commit hash
  # @return [Hash] Metadata hash (may be empty)
  def checkpoint_metadata(checkpoint_id)
    result = run_git_command("notes --ref=sisyphus show #{checkpoint_id}")
    
    if result[:success] && !result[:output].empty?
      begin
        JSON.parse(result[:output], symbolize_names: true)
      rescue JSON::ParserError
        {}
      end
    else
      {}
    end
  end

  private

  def validate_git_repository!
    unless File.directory?(File.join(@path, ".git"))
      raise ArgumentError, "Path #{@path} is not a git repository"
    end
  end

  def build_commit_message(message)
    prefix = @options[:commit_prefix]
    "#{prefix}: #{message}"
  end

  def build_metadata(milestone_id, step_ids, worker_id, execution_id, backup)
    metadata = {}
    metadata[:milestone_id] = milestone_id if milestone_id
    metadata[:step_ids] = step_ids if step_ids
    metadata[:worker_id] = worker_id if worker_id
    metadata[:execution_id] = execution_id if execution_id
    metadata[:backup] = true if backup
    metadata[:created_at] = Time.now.utc.iso8601
    metadata
  end
  
  def get_files_changed(checkpoint_id)
    files_result = run_git_command("show --name-only --pretty=format:'' #{checkpoint_id}")
    files_result[:output].split("\n").reject(&:empty?)
  end

  def create_git_commit(message)
    # Commit all tracked files with changes
    result = run_git_command("commit -a -m '#{escape_single_quotes(message)}'")
    
    unless result[:success]
      raise RuntimeError, "Failed to create checkpoint: #{result[:output]}"
    end
    
    # Get the commit hash
    hash_result = run_git_command("rev-parse HEAD")
    hash_result[:output].strip
  end

  def store_metadata(checkpoint_id, metadata)
    json_metadata = JSON.generate(metadata)
    result = run_git_command("notes --ref=sisyphus add -m '#{escape_single_quotes(json_metadata)}' #{checkpoint_id}")
    
    unless result[:success]
      # Note: This is non-fatal, just log it
      Rails.logger.warn("Failed to store metadata for checkpoint #{checkpoint_id}: #{result[:output]}")
    end
  end

  def run_git_command(cmd)
    full_cmd = "cd #{@path} && git #{cmd}"
    stdout, stderr, status = Open3.capture3(full_cmd)
    
    {
      success: status.success?,
      output: status.success? ? stdout : stderr,
      exit_status: status.exitstatus
    }
  end

  def escape_single_quotes(str)
    str.gsub("'", "'\\''")
  end
end
