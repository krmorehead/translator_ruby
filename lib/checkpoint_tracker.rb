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
  # @return [String] The current checkpoint ID
  def current_id(path:)
    @mutex.synchronize do
      checkpoint_service_for(path).current_checkpoint_id
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
end

