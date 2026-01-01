# frozen_string_literal: true

# Service for rolling back to previous Git checkpoints.
# Provides safe rollback with backup creation and validation.
#
# @example Basic rollback
#   service = GitRollbackService.new(path: "/path/to/repo")
#   success = service.rollback_to(checkpoint, strategy: :hard)
#
# @example Check if can rollback
#   result = service.can_rollback?(checkpoint)
#   if result[:can_rollback]
#     service.rollback_to(checkpoint)
#   else
#     puts result[:reason]
#   end
class GitRollbackService
  # Available rollback strategies
  STRATEGIES = [
    HARD = :hard,      # git reset --hard (discards changes)
    SOFT = :soft,      # git reset --soft (keeps changes staged)
    MIXED = :mixed     # git reset --mixed (keeps changes unstaged)
  ].freeze

  attr_reader :path, :checkpoint_service

  # Initialize the rollback service
  #
  # @param path [String] Path to git repository root
  # @raise [ArgumentError] If path is not a git repository
  def initialize(path:)
    @path = File.expand_path(path)
    @checkpoint_service = CheckpointService.new(path: path)
    
    validate_git_repository!
  end

  # Rollback to a checkpoint
  #
  # @param checkpoint [Checkpoint, String] Checkpoint object or commit ID
  # @param strategy [Symbol] Rollback strategy (:hard, :soft, :mixed)
  # @param create_backup [Boolean] Whether to create backup before rollback
  # @return [Boolean] True if rollback successful
  # @raise [ArgumentError] If checkpoint invalid or strategy unknown
  # @raise [TypeError] If checkpoint is wrong type
  # @raise [RuntimeError] If uncommitted changes exist
  def rollback_to(checkpoint, strategy: HARD, create_backup: true)
    checkpoint_id = extract_checkpoint_id(checkpoint)
    validate_rollback!(checkpoint_id, strategy)
    
    # Create backup checkpoint before rollback
    backup_checkpoint = create_backup_checkpoint if create_backup
    
    # Perform the rollback
    result = execute_rollback(checkpoint_id, strategy)
    
    if result[:success]
      Rails.logger.info "[GitRollbackService] Rolled back to #{checkpoint_id} (strategy: #{strategy})"
      Rails.logger.info "[GitRollbackService] Backup checkpoint: #{backup_checkpoint.id}" if backup_checkpoint
      true
    else
      Rails.logger.error "[GitRollbackService] Rollback failed: #{result[:error]}"
      false
    end
  end

  # Check if rollback is possible
  #
  # @param checkpoint [Checkpoint, String] Checkpoint object or commit ID
  # @return [Hash] Result with :can_rollback boolean and optional :reason
  def can_rollback?(checkpoint)
    checkpoint_id = extract_checkpoint_id(checkpoint)
    
    # Check if checkpoint exists
    unless @checkpoint_service.validate_checkpoint(checkpoint_id)
      return { can_rollback: false, reason: "Checkpoint does not exist: #{checkpoint_id}" }
    end
    
    # Check for uncommitted changes
    if has_uncommitted_changes?
      return { can_rollback: false, reason: "Uncommitted changes in working directory. Commit or stash them first." }
    end
    
    { can_rollback: true }
  end

  # List checkpoints that can be rolled back to
  #
  # @param from_checkpoint [Checkpoint, String, nil] Starting point (default: HEAD)
  # @return [Array<Checkpoint>] Array of checkpoint objects
  def list_rollback_candidates(from_checkpoint = nil)
    from_id = from_checkpoint ? extract_checkpoint_id(from_checkpoint) : "HEAD"
    
    @checkpoint_service.list_checkpoints.select do |checkpoint|
      checkpoint_reachable_from?(checkpoint.id, from_id)
    end
  end

  # Create backup checkpoint before rollback
  #
  # @return [Checkpoint] Backup checkpoint object
  def create_backup_checkpoint
    require 'shellwords'
    
    # Stage all current changes (if any)
    run_git_command("add -A")
    
    # Create backup commit (allow empty for when there are no changes)
    message = "Backup before rollback at #{Time.now.utc.iso8601}"
    metadata = { backup: true, created_at: Time.now.utc.iso8601 }
    
    escaped_message = Shellwords.escape("[SISYPHUS CHECKPOINT] #{message}")
    result = run_git_command("commit --allow-empty -m #{escaped_message}")
    unless result[:success]
      raise RuntimeError, "Failed to create backup checkpoint: #{result[:output]}"
    end
    
    # Get the commit hash
    hash_result = run_git_command("rev-parse HEAD")
    checkpoint_id = hash_result[:output].strip
    
    # Store metadata in git notes
    json_metadata = JSON.generate(metadata)
    escaped_json = Shellwords.escape(json_metadata)
    run_git_command("notes --ref=sisyphus add -m #{escaped_json} #{checkpoint_id}")
    
    # Create and return Checkpoint object
    Checkpoint.new(
      id: checkpoint_id,
      message: "[SISYPHUS CHECKPOINT] #{message}",
      created_at: Time.now.utc,
      metadata: metadata
    )
  end

  private

  def validate_git_repository!
    unless File.directory?(File.join(@path, ".git"))
      raise ArgumentError, "Path #{@path} is not a git repository"
    end
  end

  def extract_checkpoint_id(checkpoint)
    case checkpoint
    when Checkpoint
      checkpoint.id
    when String
      checkpoint
    else
      raise TypeError, "checkpoint must be a Checkpoint or String, got #{checkpoint.class}"
    end
  end

  def validate_rollback!(checkpoint_id, strategy)
    # Validate checkpoint_id
    raise ArgumentError, "checkpoint_id is required" if checkpoint_id.nil? || checkpoint_id.empty?
    
    # Validate strategy
    unless STRATEGIES.include?(strategy)
      raise ArgumentError, "Invalid strategy: #{strategy}. Must be one of: #{STRATEGIES.join(', ')}"
    end
    
    # Validate checkpoint exists
    unless @checkpoint_service.validate_checkpoint(checkpoint_id)
      raise ArgumentError, "Checkpoint does not exist: #{checkpoint_id}"
    end
    
    # Validate no uncommitted changes
    if has_uncommitted_changes?
      raise RuntimeError, "Cannot rollback with uncommitted changes. Commit or stash changes first."
    end
  end

  def has_uncommitted_changes?
    result = run_git_command("status --porcelain")
    result[:success] && !result[:output].strip.empty?
  end

  def execute_rollback(checkpoint_id, strategy)
    strategy_flag = case strategy
    when HARD then "--hard"
    when SOFT then "--soft"
    when MIXED then "--mixed"
    end
    
    result = run_git_command("reset #{strategy_flag} #{checkpoint_id}")
    
    {
      success: result[:success],
      error: result[:success] ? nil : result[:output]
    }
  end

  def checkpoint_reachable_from?(target_id, from_id)
    # Check if target_id is an ancestor of from_id using git merge-base
    result = run_git_command("merge-base --is-ancestor #{target_id} #{from_id}")
    result[:exit_status] == 0
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
end

