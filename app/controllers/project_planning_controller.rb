# frozen_string_literal: true

# Controller for project planning functionality.
# Handles both the SPA entry point and API endpoints for project planning.
class ProjectPlanningController < ApplicationController
  # GET /project_planning
  # Serves the SPA frontend
  def spa
    public_index = Rails.root.join("public", "index.html")
    built_index = Rails.root.join("frontend", "dist", "index.html")
    index_path = File.exist?(public_index) ? public_index : built_index

    unless File.exist?(index_path)
      return render plain: "Frontend not built. Run `cd frontend && npm run build`.", status: :service_unavailable
    end
    send_file index_path, type: "text/html", disposition: "inline"
  end

  # POST /project_planning/create
  # Creates a new project plan
  #
  # Request body:
  #   {
  #     "goal": "string (required)",
  #     "path": "string (required)",
  #     "project_name": "string (required)",
  #     "context": {
  #       "known_files": ["array"],
  #       "constraints": "string"
  #     }
  #   }
  #
  # Response:
  #   {
  #     "success": true,
  #     "project_path": "string",
  #     "file_references_path": "string",
  #     "project_plan_path": "string",
  #     "research_summary": "string",
  #     "milestones": [{}]
  #   }
  def create
    goal = params[:goal]
    path = params[:path]
    project_name = params[:project_name]
    context = params[:context] || {}

    # Validate required parameters
    unless goal.present?
      return render json: { success: false, error: "goal is required" }, status: :unprocessable_entity
    end

    unless path.present?
      return render json: { success: false, error: "path is required" }, status: :unprocessable_entity
    end

    unless project_name.present?
      return render json: { success: false, error: "project_name is required" }, status: :unprocessable_entity
    end

    # Validate path exists
    expanded_path = File.expand_path(path)
    unless File.exist?(expanded_path) && File.readable?(expanded_path)
      return render json: { success: false, error: "path does not exist or is not readable" }, status: :unprocessable_entity
    end

    # Normalize context keys to symbols
    normalized_context = normalize_context(context)

    # Execute project planning
    result = execute_project_planning(
      goal: goal,
      path: expanded_path,
      project_name: project_name,
      context: normalized_context
    )

    if result[:success]
      render json: {
        success: true,
        project_path: result[:project_path],
        file_references_path: result[:file_references_path],
        project_plan_path: result[:project_plan_path],
        research_summary: result[:research_summary],
        milestones: result[:milestones],
        existing_files: result[:existing_files],
        planned_files: result[:planned_files]
      }, status: :ok
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :ok
    end
  rescue StandardError => e
    render json: {
      success: false,
      error: e.message
    }, status: :internal_server_error
  end

  def normalize_context(context)
    return {} if context.blank?

    context.to_h.deep_symbolize_keys
  end

  # Execute project planning using the worker
  # Logic is delegated to service object per project rules
  def execute_project_planning(goal:, path:, project_name:, context:)
    worker = ProjectPlannerWorker.new(
      goal: goal,
      path: path,
      project_name: project_name,
      context: context
    )

    worker.execute
  end
end

