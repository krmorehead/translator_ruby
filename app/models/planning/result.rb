# frozen_string_literal: true

module Planning
  # Represents the complete output from a ProjectPlanningWorkflow.
  # Contains all planning data including milestones, steps, file references, and generated markdown.
  #
  # @example Creating a planning result
  #   result = Planning::Result.new(
  #     goal: "Add user authentication",
  #     project_name: "user_auth",
  #     milestones: [milestone1, milestone2],
  #     existing_files: [file_ref1, file_ref2],
  #     planned_files: [file_ref3, file_ref4],
  #     file_references_content: "# File References...",
  #     project_plan_content: "# Project Plan..."
  #   )
  class Result
    attr_reader :id, :goal, :project_name, :milestones, :existing_files, :planned_files,
                :file_references_content, :project_plan_content

    # @param id [String] Unique identifier for this planning result
    # @param goal [String] The project goal
    # @param project_name [String] The project name
    # @param milestones [Array<Planning::Milestone>] Array of milestone objects
    # @param existing_files [Array<Planning::FileReference>] Array of existing file references
    # @param planned_files [Array<Planning::FileReference>] Array of planned file references
    # @param file_references_content [String] Generated markdown for file_references.md
    # @param project_plan_content [String] Generated markdown for project_plan.md
    def initialize(goal:, project_name:, milestones:, existing_files:, planned_files:,
                   file_references_content:, project_plan_content:, id: SecureRandom.uuid)
      validate_types!(id, goal, project_name, milestones, existing_files, planned_files,
                      file_references_content, project_plan_content)
      
      @id = id
      @goal = goal
      @project_name = project_name
      @milestones = milestones
      @existing_files = existing_files
      @planned_files = planned_files
      @file_references_content = file_references_content
      @project_plan_content = project_plan_content
    end

    # Get the count of milestones
    # @return [Integer] Number of milestones
    def milestone_count
      @milestones.size
    end

    # Get the total count of steps across all milestones
    # @return [Integer] Total number of steps
    def step_count
      @milestones.sum(&:step_count)
    end

    # Get the total count of file references (existing + planned)
    # @return [Integer] Total number of file references
    def file_count
      @existing_files.size + @planned_files.size
    end

    # Check if the result represents a successful planning operation
    # @return [Boolean] true if has milestones and markdown content
    def success?
      @milestones.any? &&
        @file_references_content.present? &&
        @project_plan_content.present?
    end

    # Serialize to hash for persistence
    # @return [Hash] Hash representation of the result
    def to_h
      {
        id: @id,
        goal: @goal,
        project_name: @project_name,
        milestones: @milestones.map(&:to_h),
        existing_files: @existing_files.map(&:to_h),
        planned_files: @planned_files.map(&:to_h),
        file_references_content: @file_references_content,
        project_plan_content: @project_plan_content
      }
    end

    # Reconstruct a Planning::Result from a hash
    # @param id [String] Unique identifier (required - we're hydrating an existing object)
    # @param goal [String] The project goal
    # @param project_name [String] The project name
    # @param milestones [Array<Hash>] Array of milestone hashes
    # @param existing_files [Array<Hash>] Array of existing file reference hashes
    # @param planned_files [Array<Hash>] Array of planned file reference hashes
    # @param file_references_content [String] Generated markdown for file_references.md
    # @param project_plan_content [String] Generated markdown for project_plan.md
    # @return [Planning::Result] Reconstructed result
    def self.from_h(id:, goal:, project_name:, milestones:, existing_files:, planned_files:,
                    file_references_content:, project_plan_content:)
      # Reconstruct milestone objects
      milestone_objects = milestones.map { |m| Milestone.from_h(m) }
      
      # Reconstruct existing file reference objects
      existing_file_objects = existing_files.map { |f| FileReference.from_h(f) }
      
      # Reconstruct planned file reference objects
      planned_file_objects = planned_files.map { |f| FileReference.from_h(f) }
      
      new(
        id: id,
        goal: goal,
        project_name: project_name,
        milestones: milestone_objects,
        existing_files: existing_file_objects,
        planned_files: planned_file_objects,
        file_references_content: file_references_content,
        project_plan_content: project_plan_content
      )
    end

    private

    def validate_types!(id, goal, project_name, milestones, existing_files, planned_files,
                        file_references_content, project_plan_content)
      raise ArgumentError, "id must be a String, got #{id.class}" unless id.is_a?(String)
      raise ArgumentError, "id cannot be empty" if id.strip.empty?
      
      raise ArgumentError, "goal must be a String, got #{goal.class}" unless goal.is_a?(String)
      raise ArgumentError, "goal cannot be empty" if goal.strip.empty?
      
      raise ArgumentError, "project_name must be a String, got #{project_name.class}" unless project_name.is_a?(String)
      raise ArgumentError, "project_name cannot be empty" if project_name.strip.empty?
      
      raise ArgumentError, "milestones must be an Array, got #{milestones.class}" unless milestones.is_a?(Array)
      if milestones.any? { |m| !m.is_a?(Milestone) }
        raise TypeError, "all milestones must be Planning::Milestone objects"
      end
      
      raise ArgumentError, "existing_files must be an Array, got #{existing_files.class}" unless existing_files.is_a?(Array)
      if existing_files.any? { |f| !f.is_a?(FileReference) }
        raise TypeError, "all existing_files must be Planning::FileReference objects"
      end
      
      raise ArgumentError, "planned_files must be an Array, got #{planned_files.class}" unless planned_files.is_a?(Array)
      if planned_files.any? { |f| !f.is_a?(FileReference) }
        raise TypeError, "all planned_files must be Planning::FileReference objects"
      end
      
      unless file_references_content.is_a?(String)
        raise ArgumentError, "file_references_content must be a String, got #{file_references_content.class}"
      end
      
      unless project_plan_content.is_a?(String)
        raise ArgumentError, "project_plan_content must be a String, got #{project_plan_content.class}"
      end
    end
  end
end

