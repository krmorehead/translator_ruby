# frozen_string_literal: true

module Planning
  # Represents an individual step in an execution plan.
  # Steps are the atomic units of work with status tracking.
  #
  # @example Creating a step
  #   step = Planning::PlanStep.new(
  #     title: "Create User Model",
  #     intent: "Define the core user entity with authentication",
  #     details: ["Add email and password fields", "Include validation"],
  #     tests: ["Test user creation", "Test validations"]
  #   )
  class PlanStep
    STATUSES = [
      PENDING = :pending,
      IN_PROGRESS = :in_progress,
      COMPLETE = :complete,
      SKIPPED = :skipped
    ].freeze

    attr_reader :id, :title, :intent, :details, :tests, :status,
                :estimated_duration, :dependencies, :file_changes, :order_index

    # @param title [String] Step title
    # @param intent [String] Description of what this step accomplishes and why
    # @param details [Array<String>] List of specific implementation details
    # @param tests [Array<String>] List of test requirements
    # @param id [String, nil] Optional UUID for the step (generated if not provided)
    # @param status [Symbol] Step status (:pending, :in_progress, :complete, :skipped)
    # @param estimated_duration [String, nil] Optional duration estimate
    # @param dependencies [Array<String>, nil] Optional array of step IDs this depends on
    # @param file_changes [Array<String>, nil] Optional array of files this step will change
    # @param order_index [Integer, nil] Optional ordering within parent milestone
    def initialize(title:, intent:, details:, tests:, id: nil, status: PENDING,
                   estimated_duration: nil, dependencies: nil, file_changes: nil, order_index: nil)
      validate_required!(title, intent, details, tests)
      validate_optional!(status, estimated_duration, dependencies, file_changes, order_index, id)

      @id = id || SecureRandom.uuid
      @title = title
      @intent = intent
      @details = Array(details)
      @tests = Array(tests)
      @status = status
      @estimated_duration = estimated_duration
      @dependencies = dependencies
      @file_changes = file_changes
      @order_index = order_index
    end

    # Check if step is pending
    # @return [Boolean]
    def pending?
      @status == PENDING
    end

    # Check if step is in progress
    # @return [Boolean]
    def in_progress?
      @status == IN_PROGRESS
    end

    # Check if step is complete
    # @return [Boolean]
    def complete?
      @status == COMPLETE
    end

    # Check if step is skipped
    # @return [Boolean]
    def skipped?
      @status == SKIPPED
    end

    # Mark step as complete
    def mark_complete
      @status = COMPLETE
    end

    # Mark step as skipped
    def mark_skipped
      @status = SKIPPED
    end

    # Mark step as in progress
    def mark_in_progress
      @status = IN_PROGRESS
    end

    # Serialize to hash for persistence
    # @return [Hash] Hash representation of the step
    def to_h
      {
        id: @id,
        title: @title,
        intent: @intent,
        details: @details,
        tests: @tests,
        status: @status,
        estimated_duration: @estimated_duration,
        dependencies: @dependencies,
        file_changes: @file_changes,
        order_index: @order_index
      }
    end

    # Reconstruct a PlanStep from a hash
    # @param hash [Hash] Hash containing step data
    # @return [Planning::PlanStep] Reconstructed step
    def self.from_h(hash)
      raise ArgumentError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)

      # Handle both symbol and string keys
      id = hash[:id] || hash["id"]
      title = hash[:title] || hash["title"]
      intent = hash[:intent] || hash["intent"]
      details = hash[:details] || hash["details"] || []
      tests = hash[:tests] || hash["tests"] || []
      status = hash[:status] || hash["status"] || PENDING
      estimated_duration = hash[:estimated_duration] || hash["estimated_duration"]
      dependencies = hash[:dependencies] || hash["dependencies"]
      file_changes = hash[:file_changes] || hash["file_changes"]
      order_index = hash[:order_index] || hash["order_index"]

      # Convert status to symbol if it's a string
      status = status.to_sym if status.is_a?(String)

      new(
        id: id,
        title: title,
        intent: intent,
        details: details,
        tests: tests,
        status: status,
        estimated_duration: estimated_duration,
        dependencies: dependencies,
        file_changes: file_changes,
        order_index: order_index
      )
    end

    private

    def validate_required!(title, intent, details, tests)
      # Validate title
      unless title.is_a?(String) && !title.strip.empty?
        raise ArgumentError, "title must be a non-empty String, got #{title.class}. " \
                             "Example: 'Create User Model'"
      end

      # Validate intent
      unless intent.is_a?(String) && !intent.strip.empty?
        raise ArgumentError, "intent must be a non-empty String, got #{intent.class}. " \
                             "Example: 'Define the core user entity'"
      end

      # Validate details
      raise ArgumentError, "details must be an Array, got #{details.class}" unless details.is_a?(Array)
      if details.any? { |d| !d.is_a?(String) }
        raise ArgumentError, "all details must be Strings"
      end

      # Validate tests
      raise ArgumentError, "tests must be an Array, got #{tests.class}" unless tests.is_a?(Array)
      if tests.any? { |t| !t.is_a?(String) }
        raise ArgumentError, "all tests must be Strings"
      end
    end

    def validate_optional!(status, estimated_duration, dependencies, file_changes, order_index, id)
      # Validate status
      unless STATUSES.include?(status)
        raise ArgumentError, "Invalid status: #{status}. Must be one of: #{STATUSES.join(", ")}"
      end

      # Validate estimated_duration (if provided)
      if estimated_duration && !estimated_duration.is_a?(String)
        raise ArgumentError, "estimated_duration must be a String, got #{estimated_duration.class}"
      end

      # Validate dependencies (if provided)
      if dependencies && !dependencies.is_a?(Array)
        raise ArgumentError, "dependencies must be an Array, got #{dependencies.class}"
      end

      # Validate file_changes (if provided)
      if file_changes && !file_changes.is_a?(Array)
        raise ArgumentError, "file_changes must be an Array, got #{file_changes.class}"
      end

      # Validate order_index (if provided)
      if order_index && !order_index.is_a?(Integer)
        raise ArgumentError, "order_index must be an Integer, got #{order_index.class}"
      end

      # Validate id (if provided)
      if id && !id.is_a?(String)
        raise ArgumentError, "id must be a String, got #{id.class}"
      end
    end
  end
end

