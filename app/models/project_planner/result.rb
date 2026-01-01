# frozen_string_literal: true

module ProjectPlanner
  # Represents the complete result from a ProjectPlannerWorker execution.
  # Provides clear success/failure handling and output paths.
  #
  # @example Success result
  #   result = ProjectPlanner::Result.new(
  #     success: true,
  #     goal: "Add authentication",
  #     path: "/path/to/project",
  #     project_name: "user_auth",
  #     owner_id: "abc123",
  #     planning_result: planning_result_obj,
  #     project_path: "/path/to/docs/projects/01-01-2025_user_auth",
  #     file_references_path: "/path/to/docs/projects/01-01-2025_user_auth/file_references.md",
  #     project_plan_path: "/path/to/docs/projects/01-01-2025_user_auth/project_plan.md",
  #     research_summary: "Found 5 relevant files...",
  #     metadata: { max_depth: 2 }
  #   )
  #
  # @example Failure result
  #   result = ProjectPlanner::Result.new(
  #     success: false,
  #     goal: "Add authentication",
  #     path: "/path/to/project",
  #     project_name: "user_auth",
  #     owner_id: "abc123",
  #     error: "Research workflow failed: timeout",
  #     metadata: { final_state: :failed }
  #   )
  class Result
    attr_reader :success, :goal, :path, :project_name, :owner_id, :planning_result,
                :project_path, :file_references_path, :project_plan_path,
                :research_summary, :error, :metadata

    # @param success [Boolean] Whether the operation succeeded
    # @param goal [String] The project goal
    # @param path [String] Path to the codebase
    # @param project_name [String] The project name
    # @param owner_id [String] Unique ID for this execution
    # @param planning_result [Planning::Result, nil] The planning result (for success)
    # @param project_path [String, nil] Path to the project directory
    # @param file_references_path [String, nil] Path to file_references.md
    # @param project_plan_path [String, nil] Path to project_plan.md
    # @param research_summary [String, nil] Summary from research phase
    # @param error [String, nil] Error message (for failure)
    # @param metadata [Hash] Additional metadata about the execution
    def initialize(success:, goal:, path:, project_name:, owner_id:,
                   planning_result: nil, project_path: nil, file_references_path: nil,
                   project_plan_path: nil, research_summary: nil, error: nil, metadata: {})
      validate_types!(success, goal, path, project_name, owner_id, planning_result, error, metadata)
      validate_success_exclusivity!(success, error, planning_result)
      
      @success = success
      @goal = goal
      @path = path
      @project_name = project_name
      @owner_id = owner_id
      @planning_result = planning_result
      @project_path = project_path
      @file_references_path = file_references_path
      @project_plan_path = project_plan_path
      @research_summary = research_summary
      @error = error
      @metadata = metadata
    end

    # Check if the result represents success
    # @return [Boolean] true if successful
    def success?
      @success == true
    end

    # Check if the result represents failure
    # @return [Boolean] true if failed
    def failed?
      @success == false
    end

    # Serialize to hash for persistence or JSON response
    # @return [Hash] Hash representation of the result
    def to_h
      base = {
        success: @success,
        goal: @goal,
        path: @path,
        project_name: @project_name,
        owner_id: @owner_id,
        project_path: @project_path,
        file_references_path: @file_references_path,
        project_plan_path: @project_plan_path,
        research_summary: @research_summary,
        error: @error,
        metadata: @metadata
      }

      # Add planning result data if present
      if @planning_result
        base.merge!(
          milestones: @planning_result.milestones.map(&:to_h),
          existing_files: @planning_result.existing_files.map(&:to_h),
          planned_files: @planning_result.planned_files.map(&:to_h)
        )
      else
        base.merge!(
          milestones: [],
          existing_files: [],
          planned_files: []
        )
      end

      base
    end

    # Reconstruct a ProjectPlanner::Result from a hash
    # @param hash [Hash] Hash containing result data
    # @return [ProjectPlanner::Result] Reconstructed result
    def self.from_h(hash)
      raise ArgumentError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)
      
      # Reconstruct planning result if present
      planning_result = nil
      if hash[:planning_result] || hash["planning_result"]
        planning_result_hash = hash[:planning_result] || hash["planning_result"]
        planning_result = Planning::Result.from_h(**planning_result_hash.deep_symbolize_keys)
      end
      
      new(
        success: hash[:success] || hash["success"],
        goal: hash[:goal] || hash["goal"],
        path: hash[:path] || hash["path"],
        project_name: hash[:project_name] || hash["project_name"],
        owner_id: hash[:owner_id] || hash["owner_id"],
        planning_result: planning_result,
        project_path: hash[:project_path] || hash["project_path"],
        file_references_path: hash[:file_references_path] || hash["file_references_path"],
        project_plan_path: hash[:project_plan_path] || hash["project_plan_path"],
        research_summary: hash[:research_summary] || hash["research_summary"],
        error: hash[:error] || hash["error"],
        metadata: hash[:metadata] || hash["metadata"] || {}
      )
    end

    private

    def validate_types!(success, goal, path, project_name, owner_id, planning_result, error, metadata)
      unless [true, false].include?(success)
        raise ArgumentError, "success must be a Boolean, got #{success.class}"
      end
      
      raise ArgumentError, "goal must be a String, got #{goal.class}" unless goal.is_a?(String)
      raise ArgumentError, "goal cannot be empty" if goal.strip.empty?
      
      raise ArgumentError, "path must be a String, got #{path.class}" unless path.is_a?(String)
      raise ArgumentError, "path cannot be empty" if path.strip.empty?
      
      raise ArgumentError, "project_name must be a String, got #{project_name.class}" unless project_name.is_a?(String)
      raise ArgumentError, "project_name cannot be empty" if project_name.strip.empty?
      
      raise ArgumentError, "owner_id must be a String, got #{owner_id.class}" unless owner_id.is_a?(String)
      raise ArgumentError, "owner_id cannot be empty" if owner_id.strip.empty?
      
      if planning_result && !planning_result.is_a?(Planning::Result)
        raise TypeError, "planning_result must be a Planning::Result or nil, got #{planning_result.class}"
      end
      
      if error && !error.is_a?(String)
        raise ArgumentError, "error must be a String or nil, got #{error.class}"
      end
      
      raise ArgumentError, "metadata must be a Hash, got #{metadata.class}" unless metadata.is_a?(Hash)
    end

    def validate_success_exclusivity!(success, error, planning_result)
      if success && error.present?
        raise ArgumentError, "Cannot have both success=true and error present"
      end
      
      if success && planning_result.nil?
        raise ArgumentError, "success=true requires planning_result to be present"
      end
      
      if !success && planning_result.present?
        raise ArgumentError, "success=false should not have planning_result present"
      end
    end
  end
end

