# frozen_string_literal: true

module Execution
  # Domain model for approval requests during Sisyphus execution.
  # Represents a pending approval that blocks execution until approved/rejected.
  #
  # Follows OOP patterns with strict validation and immutability.
  class ApprovalRequest
    # Approval statuses
    STATUSES = [
      PENDING = :pending,
      APPROVED = :approved,
      REJECTED = :rejected,
      TIMEOUT = :timeout
    ].freeze

    # Approval types (what is being approved)
    TYPES = [
      STEP = :step,
      MILESTONE = :milestone
    ].freeze

    attr_reader :id, :execution_id, :type, :status, :subject_id, :subject_title,
                :planned_actions, :estimated_changes, :created_at, :resolved_at,
                :resolved_by, :timeout_seconds

    # Initialize an ApprovalRequest
    #
    # @param id [String] Unique approval request identifier
    # @param execution_id [String] Associated execution identifier
    # @param type [Symbol] Type of approval (:step, :milestone)
    # @param status [Symbol] Current status (:pending, :approved, :rejected, :timeout)
    # @param subject_id [String] ID of the step/milestone being approved
    # @param subject_title [String] Title of the step/milestone
    # @param planned_actions [Array<Hash>] Array of planned tool calls
    # @param estimated_changes [Hash] Estimated file changes
    # @param created_at [String] ISO8601 timestamp when request created
    # @param resolved_at [String, nil] ISO8601 timestamp when resolved
    # @param resolved_by [String, nil] Who resolved it (user ID, system, etc.)
    # @param timeout_seconds [Integer] Timeout in seconds (default: 300 = 5 minutes)
    def initialize(id:, execution_id:, type:, status:, subject_id:, subject_title:,
                   planned_actions: [], estimated_changes: {}, created_at:,
                   resolved_at: nil, resolved_by: nil, timeout_seconds: 300)
      validate_params!(id, execution_id, type, status, subject_id, subject_title,
                       planned_actions, estimated_changes, created_at, timeout_seconds)

      @id = id
      @execution_id = execution_id
      @type = type
      @status = status
      @subject_id = subject_id
      @subject_title = subject_title
      @planned_actions = planned_actions.freeze
      @estimated_changes = estimated_changes.freeze
      @created_at = created_at
      @resolved_at = resolved_at
      @resolved_by = resolved_by
      @timeout_seconds = timeout_seconds
    end

    # Check if approval is pending
    #
    # @return [Boolean]
    def pending?
      @status == PENDING
    end

    # Check if approval was approved
    #
    # @return [Boolean]
    def approved?
      @status == APPROVED
    end

    # Check if approval was rejected
    #
    # @return [Boolean]
    def rejected?
      @status == REJECTED
    end

    # Check if approval timed out
    #
    # @return [Boolean]
    def timeout?
      @status == TIMEOUT
    end

    # Check if approval is resolved (not pending)
    #
    # @return [Boolean]
    def resolved?
      !pending?
    end

    # Check if approval has expired (based on timeout)
    #
    # @return [Boolean]
    def expired?
      return false unless pending?

      Time.parse(@created_at) + @timeout_seconds < Time.now.utc
    end

    # Create a new ApprovalRequest with approved status
    #
    # @param resolved_by [String] Who approved it
    # @return [ApprovalRequest] New instance with approved status
    def approve(resolved_by:)
      self.class.new(
        id: @id,
        execution_id: @execution_id,
        type: @type,
        status: APPROVED,
        subject_id: @subject_id,
        subject_title: @subject_title,
        planned_actions: @planned_actions,
        estimated_changes: @estimated_changes,
        created_at: @created_at,
        resolved_at: Time.now.utc.iso8601,
        resolved_by: resolved_by,
        timeout_seconds: @timeout_seconds
      )
    end

    # Create a new ApprovalRequest with rejected status
    #
    # @param resolved_by [String] Who rejected it
    # @return [ApprovalRequest] New instance with rejected status
    def reject(resolved_by:)
      self.class.new(
        id: @id,
        execution_id: @execution_id,
        type: @type,
        status: REJECTED,
        subject_id: @subject_id,
        subject_title: @subject_title,
        planned_actions: @planned_actions,
        estimated_changes: @estimated_changes,
        created_at: @created_at,
        resolved_at: Time.now.utc.iso8601,
        resolved_by: resolved_by,
        timeout_seconds: @timeout_seconds
      )
    end

    # Create a new ApprovalRequest with timeout status
    #
    # @return [ApprovalRequest] New instance with timeout status
    def mark_timeout
      self.class.new(
        id: @id,
        execution_id: @execution_id,
        type: @type,
        status: TIMEOUT,
        subject_id: @subject_id,
        subject_title: @subject_title,
        planned_actions: @planned_actions,
        estimated_changes: @estimated_changes,
        created_at: @created_at,
        resolved_at: Time.now.utc.iso8601,
        resolved_by: "system_timeout",
        timeout_seconds: @timeout_seconds
      )
    end

    # Serialize to hash
    #
    # @return [Hash]
    def to_h
      {
        id: @id,
        execution_id: @execution_id,
        type: @type,
        status: @status,
        subject_id: @subject_id,
        subject_title: @subject_title,
        planned_actions: @planned_actions,
        estimated_changes: @estimated_changes,
        created_at: @created_at,
        resolved_at: @resolved_at,
        resolved_by: @resolved_by,
        timeout_seconds: @timeout_seconds
      }
    end

    # Deserialize from hash
    #
    # @param hash [Hash]
    # @return [ApprovalRequest]
    def self.from_h(hash)
      raise ArgumentError, "hash must be a Hash" unless hash.is_a?(Hash)

      symbolized = hash.deep_symbolize_keys

      # Convert symbols if they're strings
      type = symbolized[:type]
      type = type.to_sym if type.is_a?(String)

      status = symbolized[:status]
      status = status.to_sym if status.is_a?(String)

      new(
        id: symbolized[:id],
        execution_id: symbolized[:execution_id],
        type: type,
        status: status,
        subject_id: symbolized[:subject_id],
        subject_title: symbolized[:subject_title],
        planned_actions: symbolized[:planned_actions] || [],
        estimated_changes: symbolized[:estimated_changes] || {},
        created_at: symbolized[:created_at],
        resolved_at: symbolized[:resolved_at],
        resolved_by: symbolized[:resolved_by],
        timeout_seconds: symbolized[:timeout_seconds] || 300
      )
    end

    private

    def validate_params!(id, execution_id, type, status, subject_id, subject_title,
                         planned_actions, estimated_changes, created_at, timeout_seconds)
      # Validate id
      raise ArgumentError, "id must be a String" unless id.is_a?(String)
      raise ArgumentError, "id cannot be empty" if id.strip.empty?

      # Validate execution_id
      raise ArgumentError, "execution_id must be a String" unless execution_id.is_a?(String)
      raise ArgumentError, "execution_id cannot be empty" if execution_id.strip.empty?

      # Validate type
      raise ArgumentError, "type must be a Symbol" unless type.is_a?(Symbol)
      unless TYPES.include?(type)
        raise ArgumentError, "Invalid type: #{type}. Must be one of: #{TYPES.join(', ')}"
      end

      # Validate status
      raise ArgumentError, "status must be a Symbol" unless status.is_a?(Symbol)
      unless STATUSES.include?(status)
        raise ArgumentError, "Invalid status: #{status}. Must be one of: #{STATUSES.join(', ')}"
      end

      # Validate subject_id
      raise ArgumentError, "subject_id must be a String" unless subject_id.is_a?(String)
      raise ArgumentError, "subject_id cannot be empty" if subject_id.strip.empty?

      # Validate subject_title
      raise ArgumentError, "subject_title must be a String" unless subject_title.is_a?(String)
      raise ArgumentError, "subject_title cannot be empty" if subject_title.strip.empty?

      # Validate planned_actions
      raise ArgumentError, "planned_actions must be an Array" unless planned_actions.is_a?(Array)

      # Validate estimated_changes
      raise ArgumentError, "estimated_changes must be a Hash" unless estimated_changes.is_a?(Hash)

      # Validate created_at
      raise ArgumentError, "created_at must be a String" unless created_at.is_a?(String)
      raise ArgumentError, "created_at cannot be empty" if created_at.strip.empty?

      # Validate timeout_seconds
      unless timeout_seconds.is_a?(Integer) && timeout_seconds > 0
        raise ArgumentError, "timeout_seconds must be a positive Integer"
      end
    end
  end
end


