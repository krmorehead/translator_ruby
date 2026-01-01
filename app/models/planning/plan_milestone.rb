# frozen_string_literal: true

module Planning
  # Represents a milestone that groups related steps into logical phases.
  # Milestones provide high-level organization to execution plans.
  #
  # @example Creating a milestone
  #   milestone = Planning::PlanMilestone.new(
  #     title: "Core Infrastructure",
  #     description: "Build the foundational worker and workflow infrastructure",
  #     steps: [step1, step2, step3]
  #   )
  class PlanMilestone
    attr_reader :id, :title, :description, :steps, :order_index,
                :estimated_duration, :success_criteria

    # @param title [String] Milestone title
    # @param description [String] Milestone description
    # @param steps [Array<PlanStep>] Array of steps in this milestone
    # @param id [String, nil] Optional UUID for the milestone (generated if not provided)
    # @param order_index [Integer, nil] Optional ordering within parent plan
    # @param estimated_duration [String, nil] Optional duration estimate
    # @param success_criteria [Array<String>, nil] Optional success criteria
    def initialize(title:, description:, steps:, id: nil, order_index: nil,
                   estimated_duration: nil, success_criteria: nil)
      validate_required!(title, description, steps)
      validate_optional!(order_index, estimated_duration, success_criteria, id)

      @id = id || SecureRandom.uuid
      @title = title
      @description = description
      @steps = Array(steps)
      @order_index = order_index
      @estimated_duration = estimated_duration
      @success_criteria = success_criteria
    end

    # Add a step to the milestone
    # @param step [PlanStep] Step to add
    # @return [PlanStep] The added step
    def add_step(step)
      raise ArgumentError, "step must be a PlanStep, got #{step.class}" unless step.is_a?(PlanStep)

      @steps << step
      step
    end

    # Count of steps in the milestone
    # @return [Integer]
    def step_count
      @steps.size
    end

    # Calculate progress as percentage of completed steps
    # @return [Integer] Progress percentage (0-100)
    def progress
      return 0 if @steps.empty?

      completed_count = @steps.count(&:complete?)
      ((completed_count.to_f / @steps.size) * 100).round
    end

    # Check if all steps are complete
    # @return [Boolean]
    def completed?
      return true if @steps.empty?

      @steps.all?(&:complete?)
    end

    # Serialize to hash for persistence (recursive with steps)
    # @return [Hash] Hash representation of the milestone
    def to_h
      {
        id: @id,
        title: @title,
        description: @description,
        steps: @steps.map(&:to_h),
        order_index: @order_index,
        estimated_duration: @estimated_duration,
        success_criteria: @success_criteria
      }
    end

    # Reconstruct a PlanMilestone from a hash
    # @param hash [Hash] Hash containing milestone data
    # @return [Planning::PlanMilestone] Reconstructed milestone
    def self.from_h(hash)
      raise ArgumentError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)

      # Handle both symbol and string keys
      id = hash[:id] || hash["id"]
      title = hash[:title] || hash["title"]
      description = hash[:description] || hash["description"]
      steps_data = hash[:steps] || hash["steps"] || []
      order_index = hash[:order_index] || hash["order_index"]
      estimated_duration = hash[:estimated_duration] || hash["estimated_duration"]
      success_criteria = hash[:success_criteria] || hash["success_criteria"]

      # Reconstruct steps
      steps = steps_data.map { |step_hash| PlanStep.from_h(step_hash) }

      new(
        id: id,
        title: title,
        description: description,
        steps: steps,
        order_index: order_index,
        estimated_duration: estimated_duration,
        success_criteria: success_criteria
      )
    end

    private

    def validate_required!(title, description, steps)
      # Validate title
      unless title.is_a?(String) && !title.strip.empty?
        raise ArgumentError, "title must be a non-empty String, got #{title.class}. " \
                             "Example: 'Core Infrastructure'"
      end

      # Validate description
      unless description.is_a?(String)
        raise ArgumentError, "description must be a String, got #{description.class}"
      end

      # Validate steps
      raise ArgumentError, "steps must be an Array, got #{steps.class}" unless steps.is_a?(Array)
      if steps.any? { |s| !s.is_a?(PlanStep) }
        raise ArgumentError, "all steps must be PlanStep instances"
      end
    end

    def validate_optional!(order_index, estimated_duration, success_criteria, id)
      # Validate order_index (if provided)
      if order_index && !order_index.is_a?(Integer)
        raise ArgumentError, "order_index must be an Integer, got #{order_index.class}"
      end

      # Validate estimated_duration (if provided)
      if estimated_duration && !estimated_duration.is_a?(String)
        raise ArgumentError, "estimated_duration must be a String, got #{estimated_duration.class}"
      end

      # Validate success_criteria (if provided)
      if success_criteria && !success_criteria.is_a?(Array)
        raise ArgumentError, "success_criteria must be an Array, got #{success_criteria.class}"
      end

      # Validate id (if provided)
      if id && !id.is_a?(String)
        raise ArgumentError, "id must be a String, got #{id.class}"
      end
    end
  end
end

