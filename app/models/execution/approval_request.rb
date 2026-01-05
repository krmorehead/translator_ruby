# frozen_string_literal: true

module Execution
  # Domain model for approval requests during Sisyphus execution.
  # Represents a pending approval that blocks execution until approved/rejected.
  #
  # IMPORTANT: Approvals wait FOREVER until resolved by the user.
  # There are NO TIMEOUTS. The system does not auto-resolve approvals.
  # This prevents masking real issues and ensures human oversight.
  #
  # Follows OOP patterns with strict validation and immutability.
  class ApprovalRequest
    # Approval statuses - NO TIMEOUT STATUS
    # Approvals are either pending, approved, or rejected.
    # They NEVER timeout - they wait forever for user action.
    STATUSES = [
      PENDING = :pending,
      APPROVED = :approved,
      REJECTED = :rejected
    ].freeze

    # Approval types (what is being approved)
    TYPES = [
      STEP = :step,
      MILESTONE = :milestone
    ].freeze

    attr_reader :id, :execution_id, :type, :status, :subject_id, :subject_title,
                :planned_actions, :estimated_changes, :created_at, :resolved_at,
                :resolved_by

    # Initialize a NEW ApprovalRequest
    # NEVER pass an id - it's generated automatically
    #
    # @param execution_id [String] Associated execution identifier
    # @param type [Symbol] Type of approval (:step, :milestone)
    # @param status [Symbol] Current status (:pending, :approved, :rejected)
    # @param subject_id [String] ID of the step/milestone being approved
    # @param subject_title [String] Title of the step/milestone
    # @param planned_actions [Array<Hash>] Array of planned tool calls
    # @param estimated_changes [Hash] Estimated file changes
    def initialize(execution_id:, type:, subject_id:, subject_title:,
                   planned_actions: [], estimated_changes: {})
      # Generate ID automatically - NEVER accept it as a parameter
      @id = SecureRandom.uuid
      @created_at = Time.now.utc.iso8601
      @status = PENDING # New approvals are always pending
      @resolved_at = nil
      @resolved_by = nil
      
      validate_params!(execution_id, type, subject_id, subject_title,
                       planned_actions, estimated_changes)

      @execution_id = execution_id
      @type = type
      @subject_id = subject_id
      @subject_title = subject_title
      @planned_actions = planned_actions.freeze
      @estimated_changes = estimated_changes.freeze
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

    # Check if approval is resolved (not pending)
    #
    # @return [Boolean]
    def resolved?
      !pending?
    end

    # Create a new ApprovalRequest with approved status
    #
    # @param resolved_by [String] Who approved it
    # @return [ApprovalRequest] New instance with approved status
    def approve(resolved_by:)
      self.class.send(:reconstruct,
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
        resolved_by: resolved_by
      )
    end

    # Create a new ApprovalRequest with rejected status
    #
    # @param resolved_by [String] Who rejected it
    # @return [ApprovalRequest] New instance with rejected status
    def reject(resolved_by:)
      self.class.send(:reconstruct,
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
        resolved_by: resolved_by
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
        resolved_by: @resolved_by
      }
    end

    # Deserialize from hash (for loading from storage)
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

      reconstruct(
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
        resolved_by: symbolized[:resolved_by]
      )
    end

    private

    # Private constructor for deserialization and state changes
    # Only used by from_h, approve, and reject
    def self.reconstruct(id:, execution_id:, type:, status:, subject_id:, subject_title:,
                         planned_actions:, estimated_changes:, created_at:,
                         resolved_at: nil, resolved_by: nil)
      instance = allocate
      instance.instance_variable_set(:@id, id)
      instance.instance_variable_set(:@execution_id, execution_id)
      instance.instance_variable_set(:@type, type)
      instance.instance_variable_set(:@status, status)
      instance.instance_variable_set(:@subject_id, subject_id)
      instance.instance_variable_set(:@subject_title, subject_title)
      instance.instance_variable_set(:@planned_actions, planned_actions.freeze)
      instance.instance_variable_set(:@estimated_changes, estimated_changes.freeze)
      instance.instance_variable_set(:@created_at, created_at)
      instance.instance_variable_set(:@resolved_at, resolved_at)
      instance.instance_variable_set(:@resolved_by, resolved_by)
      instance
    end

    def validate_params!(execution_id, type, subject_id, subject_title,
                         planned_actions, estimated_changes)
      # Validate execution_id
      raise ArgumentError, "execution_id must be a String" unless execution_id.is_a?(String)
      raise ArgumentError, "execution_id cannot be empty" if execution_id.strip.empty?

      # Validate type
      raise ArgumentError, "type must be a Symbol" unless type.is_a?(Symbol)
      unless TYPES.include?(type)
        raise ArgumentError, "Invalid type: #{type}. Must be one of: #{TYPES.join(', ')}"
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
    end
  end
end
