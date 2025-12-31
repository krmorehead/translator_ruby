# frozen_string_literal: true

module Planning
  # Formats milestones and steps into a project plan markdown document.
  # Generates the project_plan.md content with proper milestone and step formatting.
  #
  # @example
  #   formatter = Planning::ProjectPlanFormatter.new(
  #     goal: "Add user authentication",
  #     milestones: [milestone1, milestone2]
  #   )
  #   markdown = formatter.generate
  class ProjectPlanFormatter
    attr_reader :goal, :milestones

    # @param goal [String] The project goal
    # @param milestones [Array<Planning::Milestone>] Array of milestone objects
    def initialize(goal:, milestones:)
      validate_inputs!(goal, milestones)
      
      @goal = goal
      @milestones = milestones
    end

    # Generate the markdown content for project_plan.md
    # @return [String] Markdown-formatted project plan document
    def generate
      lines = []
      lines << "# Project Plan"
      lines << ""
      lines << "**Goal**: #{@goal}"
      lines << ""
      
      @milestones.each do |milestone|
        lines.concat(format_milestone(milestone))
      end
      
      lines.join("\n")
    end

    private

    def validate_inputs!(goal, milestones)
      raise ArgumentError, "goal must be a String, got #{goal.class}" unless goal.is_a?(String)
      raise ArgumentError, "goal cannot be empty" if goal.strip.empty?
      
      raise ArgumentError, "milestones must be an Array, got #{milestones.class}" unless milestones.is_a?(Array)
      
      if milestones.any? { |m| !m.is_a?(Milestone) }
        raise TypeError, "all milestones must be Planning::Milestone objects"
      end
    end

    def format_milestone(milestone)
      lines = []
      lines << "## Milestone #{milestone.number}: #{milestone.title}"
      lines << ""
      lines << milestone.description
      lines << ""
      
      milestone.steps.each_with_index do |step, index|
        lines.concat(format_step(step))
        
        # Add horizontal rule between steps (but not after the last step)
        if index < milestone.steps.size - 1
          lines << "---"
          lines << ""
        end
      end
      
      lines
    end

    def format_step(step)
      lines = []
      lines << "### Step #{step.number}: #{step.title}"
      lines << ""
      lines << "**Intent**: #{step.intent}"
      lines << ""
      
      # Format details section
      lines << "**Details**:"
      if step.details.any?
        step.details.each do |detail|
          lines << "- #{detail}"
        end
      else
        lines << "- _No details provided_"
      end
      lines << ""
      
      # Format tests section
      lines << "**Tests**:"
      if step.tests.any?
        step.tests.each do |test|
          lines << "- #{test}"
        end
      else
        lines << "- _No tests provided_"
      end
      lines << ""
      
      lines
    end
  end
end

