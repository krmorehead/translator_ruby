# frozen_string_literal: true

module Planning
  # Represents a single step within a milestone in a project plan.
  # Steps are numbered using milestone_number and step_number integers.
  # The full number serializes as "milestone.step" (e.g., "1.1", "2.3").
  #
  # @example Creating a step
  #   step = Planning::Step.new(
  #     milestone_number: 1,
  #     step_number: 1,
  #     title: "Create User Model",
  #     intent: "Define the core user entity with authentication",
  #     details: ["Add email and password fields", "Include validation"],
  #     tests: ["Test user creation", "Test validations"]
  #   )
  class Step
    attr_reader :id, :milestone_number, :step_number, :title, :intent, :details, :tests

    # @param milestone_number [Integer] Milestone number (1, 2, 3, etc.)
    # @param step_number [Integer] Step number within milestone (1, 2, 3, etc.)
    # @param title [String] Step title
    # @param intent [String] Description of what this step accomplishes and why
    # @param details [Array<String>] List of specific implementation details
    # @param tests [Array<String>] List of test requirements
    # @param id [String, nil] Optional UUID for the step (generated if not provided)
    def initialize(milestone_number:, step_number:, title:, intent:, details:, tests:, id: nil)
      validate_types!(milestone_number, step_number, title, intent, details, tests, id)
      
      @id = id || SecureRandom.uuid
      @milestone_number = milestone_number
      @step_number = step_number
      @title = title
      @intent = intent
      @details = Array(details)
      @tests = Array(tests)
    end

    # Get the full step number in format "milestone.step"
    # @return [String] The full step number (e.g., "1.1", "2.3")
    def number
      "#{@milestone_number}.#{@step_number}"
    end

    # Check if the step has all required components
    # @return [Boolean] true if title, intent, details, and tests are all present
    def complete?
      @title.present? &&
        @intent.present? &&
        @details.any? &&
        @tests.any?
    end

    # Serialize to hash for persistence
    # @return [Hash] Hash representation of the step
    def to_h
      {
        id: @id,
        milestone_number: @milestone_number,
        step_number: @step_number,
        title: @title,
        intent: @intent,
        details: @details,
        tests: @tests
      }
    end

    # Reconstruct a Step from a hash
    # @param hash [Hash] Hash containing step data
    # @return [Planning::Step] Reconstructed step
    def self.from_h(hash)
      raise ArgumentError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)
      
      milestone_number = hash[:milestone_number] || hash["milestone_number"]
      step_number = hash[:step_number] || hash["step_number"]
      
      # Validate required fields are present
      if milestone_number.nil?
        raise ArgumentError, "hash must contain :milestone_number (Integer). Got keys: #{hash.keys.inspect}"
      end
      
      if step_number.nil?
        raise ArgumentError, "hash must contain :step_number (Integer). Got keys: #{hash.keys.inspect}"
      end
      
      new(
        id: hash[:id] || hash["id"],
        milestone_number: milestone_number,
        step_number: step_number,
        title: hash[:title] || hash["title"],
        intent: hash[:intent] || hash["intent"],
        details: hash[:details] || hash["details"] || [],
        tests: hash[:tests] || hash["tests"] || []
      )
    end

    private

    def validate_types!(milestone_number, step_number, title, intent, details, tests, id)
      # Validate milestone_number
      unless milestone_number.is_a?(Integer)
        raise ArgumentError, "milestone_number must be an Integer, got #{milestone_number.class}. " \
                             "Example: milestone_number: 1"
      end
      raise ArgumentError, "milestone_number must be positive, got #{milestone_number}" unless milestone_number > 0
      
      # Validate step_number
      unless step_number.is_a?(Integer)
        raise ArgumentError, "step_number must be an Integer, got #{step_number.class}. " \
                             "Example: step_number: 1"
      end
      raise ArgumentError, "step_number must be positive, got #{step_number}" unless step_number > 0
      
      # Validate id if provided
      if id && !id.is_a?(String)
        raise ArgumentError, "id must be a String, got #{id.class}"
      end
      
      # Validate title
      raise ArgumentError, "title must be a String, got #{title.class}" unless title.is_a?(String)
      raise ArgumentError, "title cannot be empty" if title.strip.empty?
      
      # Validate intent
      raise ArgumentError, "intent must be a String, got #{intent.class}" unless intent.is_a?(String)
      raise ArgumentError, "intent cannot be empty" if intent.strip.empty?
      
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
  end
end

