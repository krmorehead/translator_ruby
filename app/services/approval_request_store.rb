# frozen_string_literal: true

# Persistence layer for approval requests.
# Uses Redis for fast storage with automatic TTL.
#
# This store manages Execution::ApprovalRequest objects, providing CRUD operations
# and wait/notify functionality for blocking approval workflows.
#
# Follows OOP patterns with strict validation and clear error handling.
class ApprovalRequestStore
  # Default TTL for approval requests (24 hours)
  DEFAULT_TTL = 24 * 60 * 60

  # Redis key prefix for approval requests
  KEY_PREFIX = "approval:request:"

  # Redis key prefix for execution's approval list
  LIST_KEY_PREFIX = "approval:execution:"

  def initialize(redis: nil, ttl: DEFAULT_TTL)
    @redis = redis || Redis.current
    @ttl = ttl
  end

  # Store an approval request
  #
  # @param request [Execution::ApprovalRequest] The request to store
  # @return [Boolean] true if successful
  def save(request)
    validate_request!(request)

    key = redis_key(request.id)
    serialized = request.to_h.to_json

    # Store the request with TTL
    @redis.setex(key, @ttl, serialized)

    # Add to execution's approval list
    list_key = execution_list_key(request.execution_id)
    @redis.sadd(list_key, request.id)
    @redis.expire(list_key, @ttl)

    true
  rescue Redis::BaseError => e
    Rails.logger.error "Failed to save approval request: #{e.message}"
    false
  end

  # Retrieve an approval request by ID
  #
  # @param request_id [String] The request identifier
  # @return [Execution::ApprovalRequest, nil] The request or nil if not found
  def get(request_id)
    validate_request_id!(request_id)

    key = redis_key(request_id)
    serialized = @redis.get(key)

    return nil if serialized.nil?

    hash = JSON.parse(serialized)
    Execution::ApprovalRequest.from_h(hash)
  rescue Redis::BaseError => e
    Rails.logger.error "Failed to get approval request: #{e.message}"
    nil
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse approval request: #{e.message}"
    nil
  end

  # List approval requests for an execution
  #
  # @param execution_id [String] The execution identifier
  # @param status [Symbol, nil] Optional status filter
  # @return [Array<Execution::ApprovalRequest>] Array of approval requests
  def list_for_execution(execution_id:, status: nil)
    validate_execution_id!(execution_id)

    list_key = execution_list_key(execution_id)
    request_ids = @redis.smembers(list_key)

    requests = request_ids.map { |id| get(id) }.compact

    # Filter by status if provided
    if status
      requests.select { |r| r.status == status }
    else
      requests
    end
  rescue Redis::BaseError => e
    Rails.logger.error "Failed to list approval requests: #{e.message}"
    []
  end

  # Get the current pending approval for an execution
  #
  # @param execution_id [String] The execution identifier
  # @return [Execution::ApprovalRequest, nil] The pending request or nil
  def get_pending_for_execution(execution_id)
    list_for_execution(execution_id: execution_id, status: :pending).first
  end

  # Update an approval request
  # This is a convenience method that loads, yields, and saves
  #
  # @param request_id [String] The request identifier
  # @yield [Execution::ApprovalRequest] The current request for modification
  # @return [Execution::ApprovalRequest, nil] The updated request or nil if not found
  def update(request_id)
    request = get(request_id)
    return nil if request.nil?

    # Create updated request from block
    updated_request = yield(request)

    save(updated_request) if updated_request.is_a?(Execution::ApprovalRequest)
    updated_request
  end

  # Approve an approval request
  #
  # @param request_id [String] The request identifier
  # @param resolved_by [String] Who approved it
  # @return [Execution::ApprovalRequest, nil] The approved request or nil
  def approve(request_id:, resolved_by:)
    update(request_id) do |request|
      request.approve(resolved_by: resolved_by)
    end
  end

  # Reject an approval request
  #
  # @param request_id [String] The request identifier
  # @param resolved_by [String] Who rejected it
  # @return [Execution::ApprovalRequest, nil] The rejected request or nil
  def reject(request_id:, resolved_by:)
    update(request_id) do |request|
      request.reject(resolved_by: resolved_by)
    end
  end

  # Mark an approval request as timed out
  #
  # @param request_id [String] The request identifier
  # @return [Execution::ApprovalRequest, nil] The timed out request or nil
  def mark_timeout(request_id)
    update(request_id, &:mark_timeout)
  end

  # Delete an approval request
  #
  # @param request_id [String] The request identifier
  # @return [Boolean] true if deleted, false if not found
  def delete(request_id)
    validate_request_id!(request_id)

    # Get the request to find its execution_id
    request = get(request_id)

    key = redis_key(request_id)
    result = @redis.del(key)

    # Remove from execution's list if we found the request
    if request
      list_key = execution_list_key(request.execution_id)
      @redis.srem(list_key, request_id)
    end

    result > 0
  rescue Redis::BaseError => e
    Rails.logger.error "Failed to delete approval request: #{e.message}"
    false
  end

  # Wait for approval request to be resolved (blocking)
  # Uses Redis BLPOP for efficient waiting
  #
  # @param request_id [String] The request identifier
  # @param timeout [Integer] Timeout in seconds (default: 300 = 5 minutes)
  # @return [Execution::ApprovalRequest, nil] The resolved request or nil if timeout
  def wait_for_resolution(request_id, timeout: 300)
    validate_request_id!(request_id)

    start_time = Time.now.to_i
    poll_interval = 1 # Poll every second

    while Time.now.to_i - start_time < timeout
      request = get(request_id)

      # Request not found or deleted
      return nil if request.nil?

      # Request resolved
      return request if request.resolved?

      # Check if expired
      if request.expired?
        # Mark as timeout and return
        return mark_timeout(request_id)
      end

      # Wait before polling again
      sleep(poll_interval)
    end

    # Timeout reached - mark request as timed out
    mark_timeout(request_id)
  end

  # Check if an approval request exists
  #
  # @param request_id [String] The request identifier
  # @return [Boolean] true if exists
  def exists?(request_id)
    validate_request_id!(request_id)

    key = redis_key(request_id)
    @redis.exists?(key)
  rescue Redis::BaseError => e
    Rails.logger.error "Failed to check approval request existence: #{e.message}"
    false
  end

  private

  def redis_key(request_id)
    "#{KEY_PREFIX}#{request_id}"
  end

  def execution_list_key(execution_id)
    "#{LIST_KEY_PREFIX}#{execution_id}"
  end

  def validate_request!(request)
    unless request.is_a?(Execution::ApprovalRequest)
      raise TypeError, "request must be an Execution::ApprovalRequest, got #{request.class}"
    end
  end

  def validate_request_id!(request_id)
    raise ArgumentError, "request_id must be a String" unless request_id.is_a?(String)
    raise ArgumentError, "request_id cannot be empty" if request_id.strip.empty?
  end

  def validate_execution_id!(execution_id)
    raise ArgumentError, "execution_id must be a String" unless execution_id.is_a?(String)
    raise ArgumentError, "execution_id cannot be empty" if execution_id.strip.empty?
  end
end

