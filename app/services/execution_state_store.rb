# frozen_string_literal: true

# Persistence layer for Sisyphus execution states.
# Uses MemoryStore for storage.
#
# This store manages ExecutionState objects, providing CRUD operations
# and list functionality for the ExecutionOrchestrationService.
#
# Follows OOP patterns with strict validation and clear error handling.
class ExecutionStateStore
  # Key prefix for execution states
  KEY_PREFIX = "sisyphus:execution:"

  # Key for the sorted set of execution IDs (sorted by start time)
  LIST_KEY = "sisyphus:executions:list"

  def initialize(store: nil)
    @store = store || SessionCache.instance
  end

  # Store an execution state
  #
  # @param state [Execution::ExecutionState] The state to store
  # @return [Boolean] true if successful
  def save(state)
    validate_state!(state)

    key = store_key(state.execution_id)
    serialized = state.to_h.to_json

    @store.set(key, serialized)

    # Add to sorted set (score = timestamp for ordering)
    timestamp = Time.parse(state.started_at).to_i
    @store.zadd(LIST_KEY, timestamp, state.execution_id)

    true
  rescue StandardError => e
    Rails.logger.error "Failed to save execution state: #{e.message}"
    false
  end

  # Retrieve an execution state by ID
  #
  # @param execution_id [String] The execution identifier
  # @return [Execution::ExecutionState, nil] The state or nil if not found
  def get(execution_id)
    validate_execution_id!(execution_id)

    key = store_key(execution_id)
    serialized = @store.get(key)

    return nil if serialized.nil?

    hash = JSON.parse(serialized)
    Execution::ExecutionState.from_h(hash)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse execution state: #{e.message}"
    nil
  end

  # List executions (most recent first)
  #
  # @param limit [Integer] Maximum number of executions to return
  # @return [Array<Execution::ExecutionState>] Array of execution states
  def list(limit: 50)
    # Get execution IDs from sorted set (descending order = most recent first)
    execution_ids = @store.zrevrange(LIST_KEY, 0, limit - 1)

    # Fetch each execution state
    execution_ids.map { |id| get(id) }.compact
  end

  # Delete an execution state
  #
  # @param execution_id [String] The execution identifier
  # @return [Boolean] true if deleted, false if not found
  def delete(execution_id)
    validate_execution_id!(execution_id)

    key = store_key(execution_id)
    result = @store.del(key)

    # Remove from sorted set
    @store.zrem(LIST_KEY, execution_id)

    result > 0
  end

  # Check if an execution state exists
  #
  # @param execution_id [String] The execution identifier
  # @return [Boolean] true if exists
  def exists?(execution_id)
    validate_execution_id!(execution_id)

    key = store_key(execution_id)
    @store.exists?(key)
  end

  # Update execution state
  # This is a convenience method that loads, yields to a block, and saves
  #
  # @param execution_id [String] The execution identifier
  # @yield [Execution::ExecutionState] The current state for modification
  # @return [Execution::ExecutionState, nil] The updated state or nil if not found
  def update(execution_id)
    state = get(execution_id)
    return nil if state.nil?

    # Create updated state from block
    updated_state = yield(state)

    save(updated_state) if updated_state.is_a?(Execution::ExecutionState)
    updated_state
  end

  # Clear all execution states (use with caution!)
  #
  # @return [Integer] Number of states cleared
  def clear_all
    execution_ids = @store.zrange(LIST_KEY, 0, -1)

    count = 0
    execution_ids.each do |id|
      count += 1 if delete(id)
    end

    # Clear the list itself
    @store.del(LIST_KEY)

    count
  end

  private

  def store_key(execution_id)
    "#{KEY_PREFIX}#{execution_id}"
  end

  def validate_state!(state)
    unless state.is_a?(Execution::ExecutionState)
      raise TypeError, "state must be an Execution::ExecutionState, got #{state.class}"
    end
  end

  def validate_execution_id!(execution_id)
    raise ArgumentError, "execution_id must be a String" unless execution_id.is_a?(String)
    raise ArgumentError, "execution_id cannot be empty" if execution_id.strip.empty?
  end
end
