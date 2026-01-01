# frozen_string_literal: true

require "singleton"
require "digest"

# Singleton that tracks the current codebase checkpoint.
# Automatically creates new checkpoints when the codebase changes.
#
# Usage:
#   CheckpointTracker.instance.current_id(path: "/path/to/repo")
#   => "abc123..."  # Returns existing checkpoint ID if no changes
#   => "def456..."  # Creates and returns new checkpoint ID if changes detected
#
# This ensures every memory recorded is tied to a specific codebase state.
class CheckpointTracker
  include Singleton

  def initialize
    @checkpoints_by_path = {}
    @checkpoint_services = {}
    @mutex = Mutex.new
  end

  # Get the current checkpoint ID for a given repository path.
  # Creates a new checkpoint if the codebase has changed since the last checkpoint.
  #
  # @param path [String] The repository path
  # @param message [String] Optional message for new checkpoint
  # @param milestone_id [String, nil] Optional milestone ID
  # @param worker_id [String, nil] Optional worker ID
  # @return [String] The current checkpoint ID
  def current_id(path:, message: nil, milestone_id: nil, worker_id: nil)
    @mutex.synchronize do
      service = checkpoint_service_for(path)
      last_checkpoint = @checkpoints_by_path[path]

      # If no previous checkpoint or codebase has changed, create new checkpoint
      if last_checkpoint.nil? || codebase_changed?(service)
        checkpoint = create_checkpoint(service, message, milestone_id, worker_id)
        @checkpoints_by_path[path] = checkpoint
        checkpoint.id
      else
        last_checkpoint.id
      end
    end
  end

  # Get the current checkpoint object (if any) for a path
  #
  # @param path [String] The repository path
  # @return [Checkpoint, nil] The current checkpoint or nil
  def current_checkpoint(path:)
    @mutex.synchronize do
      @checkpoints_by_path[path]
    end
  end

  # Force creation of a new checkpoint regardless of changes
  #
  # @param path [String] The repository path
  # @param message [String] The checkpoint message
  # @param milestone_id [String, nil] Optional milestone ID
  # @param worker_id [String, nil] Optional worker ID
  # @return [String] The new checkpoint ID
  def force_checkpoint(path:, message:, milestone_id: nil, worker_id: nil)
    @mutex.synchronize do
      service = checkpoint_service_for(path)
      checkpoint = service.create_checkpoint(
        message,
        milestone_id: milestone_id,
        worker_id: worker_id
      )
      @checkpoints_by_path[path] = checkpoint
      checkpoint.id
    end
  end

  # Clear cached checkpoint for a path (useful for testing)
  #
  # @param path [String] The repository path
  def clear_cache(path:)
    @mutex.synchronize do
      @checkpoints_by_path.delete(path)
      @checkpoint_services.delete(path)
    end
  end

  # Clear all cached checkpoints (useful for testing)
  def clear_all_caches
    @mutex.synchronize do
      @checkpoints_by_path.clear
      @checkpoint_services.clear
    end
  end

  private

  def checkpoint_service_for(path)
    @checkpoint_services[path] ||= CheckpointService.new(path: path)
  end

  def codebase_changed?(service)
    service.has_uncommitted_changes?
  end

  def create_checkpoint(service, message, milestone_id, worker_id)
    # Generate message if not provided
    message ||= "Automatic checkpoint at #{Time.now.utc.iso8601}"
    
    service.create_checkpoint(
      message,
      milestone_id: milestone_id,
      worker_id: worker_id
    )
  rescue StandardError => e
    Rails.logger.error "[CheckpointTracker] Failed to create checkpoint: #{e.message}"
    raise
  end
end

