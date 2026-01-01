# frozen_string_literal: true

module Planning
  # Represents a top-level execution plan with milestones and metadata.
  # This is the primary result object returned by the PlanAgentWorker.
  #
  # @example Creating an execution plan
  #   plan = Planning::ExecutionPlan.new(
  #     goal: "Create a PlanAgentWorker",
  #     milestones: [milestone1, milestone2],
  #     constraints: ["Must follow OOP patterns"],
  #     assumptions: ["Rails environment available"]
  #   )
  class ExecutionPlan
    attr_reader :goal, :milestones, :created_at, :metadata,
                :constraints, :assumptions, :risks

    # @param goal [String] The goal this plan achieves
    # @param milestones [Array<PlanMilestone>] Array of milestones
    # @param created_at [String, nil] ISO8601 timestamp (generated if not provided)
    # @param metadata [Hash] Additional metadata
    # @param constraints [Array<String>, nil] Optional constraints to follow
    # @param assumptions [Array<String>, nil] Optional assumptions made
    # @param risks [Array<String>, nil] Optional identified risks
    def initialize(goal:, milestones:, created_at: nil, metadata: {},
                   constraints: nil, assumptions: nil, risks: nil)
      validate_required!(goal, milestones, metadata)
      validate_optional!(constraints, assumptions, risks)

      @goal = goal
      @milestones = Array(milestones)
      @created_at = created_at || Time.now.utc.iso8601
      @metadata = metadata
      @constraints = constraints
      @assumptions = assumptions
      @risks = risks
    end

    # Add a milestone to the plan
    # @param milestone [PlanMilestone] Milestone to add
    # @return [PlanMilestone] The added milestone
    def add_milestone(milestone)
      unless milestone.is_a?(PlanMilestone)
        raise ArgumentError, "milestone must be a PlanMilestone, got #{milestone.class}"
      end

      @milestones << milestone
      milestone
    end

    # Count of milestones in the plan
    # @return [Integer]
    def milestone_count
      @milestones.size
    end

    # Total count of steps across all milestones
    # @return [Integer]
    def step_count
      @milestones.sum(&:step_count)
    end

    # Serialize to hash for persistence (recursive with milestones)
    # @return [Hash] Hash representation of the plan
    def to_h
      {
        goal: @goal,
        milestones: @milestones.map(&:to_h),
        created_at: @created_at,
        metadata: @metadata,
        constraints: @constraints,
        assumptions: @assumptions,
        risks: @risks
      }
    end

    # Reconstruct an ExecutionPlan from a hash
    # @param hash [Hash] Hash containing plan data
    # @return [Planning::ExecutionPlan] Reconstructed plan
    def self.from_h(hash)
      raise ArgumentError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)

      # Handle both symbol and string keys
      goal = hash[:goal] || hash["goal"]
      milestones_data = hash[:milestones] || hash["milestones"] || []
      created_at = hash[:created_at] || hash["created_at"]
      metadata = hash[:metadata] || hash["metadata"] || {}
      constraints = hash[:constraints] || hash["constraints"]
      assumptions = hash[:assumptions] || hash["assumptions"]
      risks = hash[:risks] || hash["risks"]

      # Reconstruct milestones
      milestones = milestones_data.map { |milestone_hash| PlanMilestone.from_h(milestone_hash) }

      new(
        goal: goal,
        milestones: milestones,
        created_at: created_at,
        metadata: metadata,
        constraints: constraints,
        assumptions: assumptions,
        risks: risks
      )
    end

    private

    def validate_required!(goal, milestones, metadata)
      # Validate goal
      unless goal.is_a?(String) && !goal.strip.empty?
        raise ArgumentError, "goal must be a non-empty String, got #{goal.class}. " \
                             "Example: 'Create a PlanAgentWorker'"
      end

      # Validate milestones
      raise ArgumentError, "milestones must be an Array, got #{milestones.class}" unless milestones.is_a?(Array)
      if milestones.any? { |m| !m.is_a?(PlanMilestone) }
        raise ArgumentError, "all milestones must be PlanMilestone instances"
      end

      # Validate metadata
      raise ArgumentError, "metadata must be a Hash, got #{metadata.class}" unless metadata.is_a?(Hash)
    end

    def validate_optional!(constraints, assumptions, risks)
      # Validate constraints (if provided)
      if constraints && !constraints.is_a?(Array)
        raise ArgumentError, "constraints must be an Array, got #{constraints.class}"
      end

      # Validate assumptions (if provided)
      if assumptions && !assumptions.is_a?(Array)
        raise ArgumentError, "assumptions must be an Array, got #{assumptions.class}"
      end

      # Validate risks (if provided)
      if risks && !risks.is_a?(Array)
        raise ArgumentError, "risks must be an Array, got #{risks.class}"
      end
    end
  end
end

