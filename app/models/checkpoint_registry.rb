# frozen_string_literal: true

# Registry for tracking and querying checkpoints within a worker/workflow session.
# Provides session-scoped checkpoint management with efficient lookups.
#
# @example Basic usage
#   registry = CheckpointRegistry.new(owner_id: "worker_123")
#   registry.add(checkpoint)
#   latest = registry.latest
#   milestone_checkpoints = registry.for_milestone("m1")
#
# @example Persistence
#   hash = registry.to_h
#   File.write("registry.json", JSON.generate(hash))
#   loaded_registry = CheckpointRegistry.from_h(JSON.parse(File.read("registry.json"), symbolize_names: true))
class CheckpointRegistry
  attr_reader :owner_id, :created_at, :checkpoints

  # Initialize a new CheckpointRegistry
  #
  # @param owner_id [String] Owner identifier (worker ID, workflow ID, etc)
  # @raise [ArgumentError] If owner_id is invalid
  def initialize(owner_id:)
    validate_owner_id!(owner_id)
    
    @owner_id = owner_id
    @checkpoints = []
    @checkpoint_map = {}
    @created_at = Time.now.utc
  end

  # Add a checkpoint to the registry
  #
  # @param checkpoint [Checkpoint] Checkpoint to add
  # @return [Checkpoint] The added checkpoint
  # @raise [TypeError] If checkpoint is not a Checkpoint object
  def add(checkpoint)
    validate_checkpoint!(checkpoint)
    
    @checkpoints << checkpoint
    @checkpoints.sort_by!(&:created_at)  # Maintain chronological order
    @checkpoint_map[checkpoint.id] = checkpoint
    checkpoint
  end

  # Find a checkpoint by ID
  #
  # @param checkpoint_id [String] Checkpoint ID to find
  # @return [Checkpoint, nil] The checkpoint or nil if not found
  def find(checkpoint_id)
    @checkpoint_map[checkpoint_id]
  end

  # Get the most recent checkpoint
  #
  # @return [Checkpoint, nil] Latest checkpoint or nil if empty
  def latest
    @checkpoints.last
  end

  # Find all checkpoints for a milestone
  #
  # @param milestone_id [String] Milestone ID to filter by
  # @return [Array<Checkpoint>] Checkpoints for the milestone
  def for_milestone(milestone_id)
    @checkpoints.select { |cp| cp.milestone_id == milestone_id }
  end

  # Find all checkpoints for an execution
  #
  # @param execution_id [String] Execution ID to filter by
  # @return [Array<Checkpoint>] Checkpoints for the execution
  def for_execution(execution_id)
    @checkpoints.select { |cp| cp.execution_id == execution_id }
  end

  # Find all backup checkpoints
  #
  # @return [Array<Checkpoint>] Backup checkpoints
  def backups
    @checkpoints.select(&:backup?)
  end

  # Count of checkpoints in registry
  #
  # @return [Integer] Number of checkpoints
  def count
    @checkpoints.size
  end

  # Check if registry is empty
  #
  # @return [Boolean] True if no checkpoints
  def empty?
    @checkpoints.empty?
  end

  # Get all checkpoint IDs
  #
  # @return [Array<String>] Array of checkpoint IDs
  def checkpoint_ids
    @checkpoints.map(&:id)
  end

  # Iterate over checkpoints
  #
  # @yield [Checkpoint] Each checkpoint in chronological order
  def each(&block)
    @checkpoints.each(&block)
  end

  # Map over checkpoints
  #
  # @yield [Checkpoint] Each checkpoint
  # @return [Array] Mapped results
  def map(&block)
    @checkpoints.map(&block)
  end

  # Select checkpoints matching criteria
  #
  # @yield [Checkpoint] Each checkpoint
  # @return [Array<Checkpoint>] Filtered checkpoints
  def select(&block)
    @checkpoints.select(&block)
  end

  # Get all checkpoints (defensive copy)
  #
  # @return [Array<Checkpoint>] Frozen copy of checkpoints array
  def all
    @checkpoints.dup.freeze
  end

  # Clear all checkpoints from registry
  def clear!
    @checkpoints.clear
    @checkpoint_map.clear
  end

  # Convert to hash for serialization
  #
  # @return [Hash] Hash representation
  def to_h
    {
      owner_id: owner_id,
      checkpoints: @checkpoints.map(&:to_h),
      created_at: @created_at.iso8601,
      count: count
    }
  end

  # Reconstruct registry from hash
  #
  # @param hash [Hash] Hash with registry data
  # @return [CheckpointRegistry] New registry instance
  # @raise [ArgumentError] If hash is invalid
  def self.from_h(hash)
    raise ArgumentError, "hash is required" if hash.nil?
    raise ArgumentError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)
    
    # Symbolize keys if needed
    hash = hash.transform_keys(&:to_sym) if hash.keys.first.is_a?(String)
    
    # Create registry instance
    registry = allocate
    registry.instance_variable_set(:@owner_id, hash[:owner_id])
    registry.instance_variable_set(:@created_at, parse_time(hash[:created_at]))
    
    # Reconstruct checkpoints
    checkpoints = (hash[:checkpoints] || []).map { |cp_hash| Checkpoint.from_h(cp_hash) }
    registry.instance_variable_set(:@checkpoints, checkpoints)
    registry.instance_variable_set(:@checkpoint_map, build_map(checkpoints))
    
    registry
  end

  private

  def validate_owner_id!(owner_id)
    raise ArgumentError, "owner_id must be a String, got #{owner_id.class}" unless owner_id.is_a?(String)
    raise ArgumentError, "owner_id cannot be empty" if owner_id.empty?
  end

  def validate_checkpoint!(checkpoint)
    raise TypeError, "checkpoint must be a Checkpoint, got #{checkpoint.class}" unless checkpoint.is_a?(Checkpoint)
  end

  def self.build_map(checkpoints)
    checkpoints.each_with_object({}) { |cp, map| map[cp.id] = cp }
  end

  def self.parse_time(time_value)
    case time_value
    when Time
      time_value
    when String
      Time.parse(time_value)
    else
      raise ArgumentError, "created_at must be a Time or String, got #{time_value.class}"
    end
  end
end

