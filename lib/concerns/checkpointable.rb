# frozen_string_literal: true

# Checkpointable concern for Workers and Workflows.
# Provides checkpoint management capabilities to any class that includes it.
#
# @example Include in a Worker
#   class MyWorker < BaseWorker
#     include Checkpointable
#
#     def execute
#       create_checkpoint("Started execution")
#       # ... do work ...
#       create_checkpoint("Completed milestone 1", milestone_id: "m1")
#     end
#   end
#
# @example Query checkpoints
#   worker.checkpoint_count        # => 2
#   worker.last_checkpoint         # => Checkpoint object
#   worker.checkpoints_for_milestone("m1")  # => [Checkpoint]
module Checkpointable
  # Raised when checkpoint operations are attempted without required setup
  class CheckpointError < StandardError; end

  # Called when module is included in a class
  def self.included(base)
    base.class_eval do
      # Accessor for checkpoint policy
      attr_accessor :checkpoint_policy
    end
  end

  # Create a checkpoint with message and metadata
  #
  # @param message [String] Checkpoint message
  # @param metadata [Hash] Additional metadata
  # @option metadata [String] :milestone_id Milestone ID
  # @option metadata [Array<String>] :step_ids Step IDs
  # @option metadata [String] :worker_id Worker ID
  # @option metadata [String] :execution_id Execution ID
  # @option metadata [Boolean] :backup Whether this is a backup
  # @return [Checkpoint] Created checkpoint object
  # @raise [CheckpointError] If checkpoint creation fails
  def create_checkpoint(message, **metadata)
    validate_checkpoint_requirements!
    
    # Create checkpoint via service
    checkpoint = checkpoint_service.create_checkpoint(
      message,
      **metadata.merge(worker_id: checkpoint_worker_id)
    )
    
    # Store in registry
    checkpoint_registry.add(checkpoint)
    
    # Store in memory if available
    record_checkpoint_to_memory(checkpoint) if respond_to?(:memory_store) && memory_store
    
    checkpoint
  rescue StandardError => e
    Rails.logger.error "[Checkpointable] Failed to create checkpoint: #{e.message}"
    raise CheckpointError, "Failed to create checkpoint: #{e.message}"
  end

  # Get the checkpoint service instance
  #
  # @return [CheckpointService] Checkpoint service
  def checkpoint_service
    @checkpoint_service ||= begin
      validate_has_path!
      CheckpointService.new(path: checkpoint_path)
    end
  end

  # Get the checkpoint registry instance
  #
  # @return [CheckpointRegistry] Checkpoint registry
  def checkpoint_registry
    @checkpoint_registry ||= CheckpointRegistry.new(owner_id: checkpoint_owner_id)
  end

  # Get the most recent checkpoint
  #
  # @return [Checkpoint, nil] Latest checkpoint or nil if none exist
  def last_checkpoint
    checkpoint_registry.latest
  end

  # Get all checkpoints
  #
  # @return [Array<Checkpoint>] All checkpoints
  def all_checkpoints
    checkpoint_registry.all
  end

  # Count of checkpoints created
  #
  # @return [Integer] Number of checkpoints
  def checkpoint_count
    checkpoint_registry.count
  end

  # Get checkpoints for a specific milestone
  #
  # @param milestone_id [String] Milestone ID
  # @return [Array<Checkpoint>] Checkpoints for the milestone
  def checkpoints_for_milestone(milestone_id)
    checkpoint_registry.for_milestone(milestone_id)
  end

  # Get checkpoints for a specific execution
  #
  # @param execution_id [String] Execution ID
  # @return [Array<Checkpoint>] Checkpoints for the execution
  def checkpoints_for_execution(execution_id)
    checkpoint_registry.for_execution(execution_id)
  end

  # Get all backup checkpoints
  #
  # @return [Array<Checkpoint>] Backup checkpoints
  def backup_checkpoints
    checkpoint_registry.backups
  end

  # Check if checkpoints are enabled
  #
  # @return [Boolean] True if checkpointing is enabled
  def checkpoints_enabled?
    !@checkpoints_disabled && checkpoint_path_available?
  end

  # Disable checkpoint creation (useful for testing)
  def disable_checkpoints!
    @checkpoints_disabled = true
  end

  # Enable checkpoint creation
  def enable_checkpoints!
    @checkpoints_disabled = false
  end

  # Rollback to the last checkpoint
  #
  # @param strategy [Symbol] Rollback strategy (:hard, :soft, :mixed)
  # @return [Boolean] True if rollback successful
  # @raise [CheckpointError] If no checkpoints exist or rollback fails
  def rollback_to_last_checkpoint(strategy: :hard)
    checkpoint = last_checkpoint
    raise CheckpointError, "No checkpoints available to rollback to" unless checkpoint
    
    rollback_to_checkpoint(checkpoint, strategy: strategy)
  end

  # Rollback to a specific checkpoint
  #
  # @param checkpoint [Checkpoint, String] Checkpoint object or ID
  # @param strategy [Symbol] Rollback strategy (:hard, :soft, :mixed)
  # @return [Boolean] True if rollback successful
  # @raise [CheckpointError] If rollback fails
  def rollback_to_checkpoint(checkpoint, strategy: :hard)
    validate_has_path!
    
    rollback_service = GitRollbackService.new(path: checkpoint_path)
    success = rollback_service.rollback_to(checkpoint, strategy: strategy, create_backup: true)
    
    unless success
      raise CheckpointError, "Rollback failed"
    end
    
    Rails.logger.info "[Checkpointable] Rolled back to checkpoint #{checkpoint.is_a?(Checkpoint) ? checkpoint.short_id : checkpoint}"
    success
  rescue StandardError => e
    Rails.logger.error "[Checkpointable] Rollback failed: #{e.message}"
    raise CheckpointError, "Rollback failed: #{e.message}"
  end

  private

  # Get the path for git operations
  # Classes must implement either #path or #checkpoint_path
  def checkpoint_path
    if respond_to?(:path)
      path
    elsif respond_to?(:checkpoint_path)
      checkpoint_path
    else
      raise CheckpointError, "Class must implement #path or #checkpoint_path method"
    end
  end

  # Get the owner ID for namespacing
  # Classes can implement #owner_id or default to class name
  def checkpoint_owner_id
    if respond_to?(:owner_id)
      owner_id
    elsif instance_variable_defined?(:@owner_id)
      @owner_id
    else
      self.class.name
    end
  end

  # Get the worker ID for metadata
  # Classes can implement #worker_id or default to owner_id
  def checkpoint_worker_id
    if respond_to?(:worker_id)
      worker_id
    else
      checkpoint_owner_id
    end
  end

  # Check if path is available
  def checkpoint_path_available?
    respond_to?(:path) || respond_to?(:checkpoint_path)
  end

  # Validate that path is available
  def validate_has_path!
    unless checkpoint_path_available?
      raise CheckpointError, "Checkpoint path not available. Class must implement #path or #checkpoint_path"
    end
  end

  # Validate checkpoint requirements
  def validate_checkpoint_requirements!
    return if @checkpoints_disabled
    
    validate_has_path!
    
    unless Dir.exist?(File.join(checkpoint_path, ".git"))
      raise CheckpointError, "Path #{checkpoint_path} is not a git repository"
    end
  end

  # Record checkpoint to memory store if available
  def record_checkpoint_to_memory(checkpoint)
    memory_store.record_checkpoint(checkpoint)
  rescue StandardError => e
    Rails.logger.warn "[Checkpointable] Failed to record checkpoint to memory: #{e.message}"
    # Non-fatal - continue even if memory recording fails
  end
end








