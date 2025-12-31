# frozen_string_literal: true

module Planning
  # Represents a milestone in a project plan containing multiple steps.
  # Milestones group related functionality and should be independently demonstrable.
  #
  # @example Creating a milestone with steps
  #   milestone = Planning::Milestone.new(
  #     number: 1,
  #     title: "User Authentication",
  #     description: "Implement secure user login and registration"
  #   )
  #   
  #   step = Planning::Step.new(
  #     number: "1.1",
  #     title: "Create User Model",
  #     intent: "Define user entity",
  #     details: ["Add email field"],
  #     tests: ["Test user creation"]
  #   )
  #   
  #   milestone.add_step(step)
  class Milestone
    attr_reader :number, :title, :description, :steps

    # @param number [Integer] Milestone number (1, 2, 3, etc.)
    # @param title [String] Milestone title
    # @param description [String] Milestone description
    def initialize(number:, title:, description:)
      validate_types!(number, title, description)
      
      @number = number
      @title = title
      @description = description
      @steps = []
    end

    # Add a step to this milestone
    # @param step [Planning::Step] The step to add
    # @return [Planning::Step] The added step
    def add_step(step)
      unless step.is_a?(Step)
        raise TypeError, "step must be a Planning::Step, got #{step.class}"
      end
      
      # Validate step number matches this milestone
      if step.milestone_number != @number
        raise ArgumentError, "step number #{step.number} does not match milestone #{@number}"
      end
      
      @steps << step
      step
    end

    # Check if all steps in this milestone are complete
    # @return [Boolean] true if all steps have all required components
    def steps_complete?
      return false if @steps.empty?
      @steps.all?(&:complete?)
    end

    # Get the number of steps in this milestone
    # @return [Integer] The count of steps
    def step_count
      @steps.size
    end

    # Serialize to hash for persistence
    # @return [Hash] Hash representation of the milestone
    def to_h
      {
        number: @number,
        title: @title,
        description: @description,
        steps: @steps.map(&:to_h)
      }
    end

    # Reconstruct a Milestone from a hash
    # @param hash [Hash] Hash containing milestone data
    # @return [Planning::Milestone] Reconstructed milestone
    def self.from_h(hash)
      raise ArgumentError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)
      
      milestone = new(
        number: hash[:number] || hash["number"],
        title: hash[:title] || hash["title"],
        description: hash[:description] || hash["description"]
      )
      
      # Reconstruct steps
      steps_data = hash[:steps] || hash["steps"] || []
      steps_data.each do |step_hash|
        step = Step.from_h(step_hash)
        milestone.add_step(step)
      end
      
      milestone
    end

    private

    def validate_types!(number, title, description)
      raise ArgumentError, "number must be an Integer, got #{number.class}" unless number.is_a?(Integer)
      raise ArgumentError, "number must be positive" unless number > 0
      raise ArgumentError, "title must be a String, got #{title.class}" unless title.is_a?(String)
      raise ArgumentError, "title cannot be empty" if title.strip.empty?
      raise ArgumentError, "description must be a String, got #{description.class}" unless description.is_a?(String)
      raise ArgumentError, "description cannot be empty" if description.strip.empty?
    end
  end
end

