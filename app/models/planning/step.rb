# frozen_string_literal: true

module Planning
  # Represents a single step within a milestone in a project plan.
  # Steps are numbered using a format like "1.1", "2.3", etc.
  #
  # @example Creating a step
  #   step = Planning::Step.new(
  #     number: "1.1",
  #     title: "Create User Model",
  #     intent: "Define the core user entity with authentication",
  #     details: ["Add email and password fields", "Include validation"],
  #     tests: ["Test user creation", "Test validations"]
  #   )
  class Step
    attr_reader :number, :title, :intent, :details, :tests

    # Step number pattern: digit.digit (e.g., "1.1", "2.3")
    STEP_NUMBER_PATTERN = /^\d+\.\d+$/

    # @param number [String] Step number in format "milestone.step" (e.g., "1.1")
    # @param title [String] Step title
    # @param intent [String] Description of what this step accomplishes and why
    # @param details [Array<String>] List of specific implementation details
    # @param tests [Array<String>] List of test requirements
    def initialize(number:, title:, intent:, details:, tests:)
      validate_types!(number, title, intent, details, tests)
      validate_number_format!(number)
      
      @number = number
      @title = title
      @intent = intent
      @details = Array(details)
      @tests = Array(tests)
    end

    # Extract the milestone number from the step number
    # @return [Integer] The milestone number (e.g., 1 from "1.1")
    def milestone_number
      @number.split(".").first.to_i
    end

    # Extract the step index within the milestone
    # @return [Integer] The step index (e.g., 1 from "1.1")
    def step_index
      @number.split(".").last.to_i
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
        number: @number,
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
      
      new(
        number: hash[:number] || hash["number"],
        title: hash[:title] || hash["title"],
        intent: hash[:intent] || hash["intent"],
        details: hash[:details] || hash["details"] || [],
        tests: hash[:tests] || hash["tests"] || []
      )
    end

    private

    def validate_types!(number, title, intent, details, tests)
      raise ArgumentError, "number must be a String, got #{number.class}" unless number.is_a?(String)
      raise ArgumentError, "title must be a String, got #{title.class}" unless title.is_a?(String)
      raise ArgumentError, "title cannot be empty" if title.strip.empty?
      raise ArgumentError, "intent must be a String, got #{intent.class}" unless intent.is_a?(String)
      raise ArgumentError, "intent cannot be empty" if intent.strip.empty?
      raise ArgumentError, "details must be an Array, got #{details.class}" unless details.is_a?(Array)
      raise ArgumentError, "tests must be an Array, got #{tests.class}" unless tests.is_a?(Array)
      
      # Validate array elements are strings
      if details.any? { |d| !d.is_a?(String) }
        raise ArgumentError, "all details must be Strings"
      end
      
      if tests.any? { |t| !t.is_a?(String) }
        raise ArgumentError, "all tests must be Strings"
      end
    end

    def validate_number_format!(number)
      unless number.match?(STEP_NUMBER_PATTERN)
        raise ArgumentError, "number must match pattern 'milestone.step' (e.g., '1.1'), got '#{number}'"
      end
    end
  end
end

