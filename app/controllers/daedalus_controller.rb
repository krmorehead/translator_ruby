# frozen_string_literal: true

# Controller for Daedalus (execution plan generation) functionality.
# Handles both the SPA entry point and API endpoints for plan generation.
class DaedalusController < ApplicationController
  # GET /daedalus
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

  # POST /daedalus/create
  # Creates a new execution plan using the Daedalus worker
  #
  # Request body:
  #   {
  #     "goal": "string (required)",
  #     "path": "string (required)",
  #     "context": {
  #       "hint": "string (optional)",
  #       "additional_context": "string (optional)"
  #     }
  #   }
  #
  # Response:
  #   {
  #     "success": true,
  #     "execution_plan": { ... },
  #     "output_paths": {
  #       "plan_directory": "string",
  #       "plan_path": "string",
  #       "json_path": "string",
  #       "metadata_path": "string"
  #     },
  #     "analysis_summary": {
  #       "relevant_files": ["array"],
  #       "patterns": ["array"],
  #       "constraints": ["array"]
  #     },
  #     "metadata": { ... }
  #   }
  def create
    # Extract values from parameters
    goal = params.fetch(:goal, nil)
    path = params.fetch(:path, nil)
    context_hint = params.dig(:context, :hint)
    additional_context = params.dig(:context, :additional_context)

    # Validate required parameters
    unless goal.present?
      return render json: { success: false, error: "goal is required" }, status: :unprocessable_entity
    end

    unless path.present?
      return render json: { success: false, error: "path is required" }, status: :unprocessable_entity
    end

    # Validate path exists
    expanded_path = File.expand_path(path)
    unless File.exist?(expanded_path) && File.readable?(expanded_path)
      return render json: { success: false, error: "path does not exist or is not readable" }, status: :unprocessable_entity
    end

    # Create Contexts::BaseContext object (translation at API boundary)
    base_context = build_context(
      hint: context_hint,
      additional_context: additional_context
    )

    # Execute Daedalus worker
    result = execute_daedalus(
      goal: goal,
      path: expanded_path,
      context: base_context
    )

    # Check if worker completed successfully
    if result[:error]
      render json: {
        success: false,
        error: result[:error]
      }, status: :ok
    else
      render json: {
        success: true,
        **result
      }, status: :ok
    end
  rescue StandardError => e
    Rails.logger.error("Daedalus controller error: #{e.message}\n#{e.backtrace.join("\n")}")
    render json: {
      success: false,
      error: e.message
    }, status: :internal_server_error
  end

  private

  # Build Contexts::BaseContext from extracted parameter values
  # Translation at API boundary - converts request params to domain object
  # ALWAYS returns a BaseContext object (no fallbacks, no optionals)
  def build_context(hint:, additional_context:)
    base_context = Contexts::BaseContext.new
    
    # Add hint if provided
    if hint.present?
      base_context.add(
        content: hint,
        topics: ["planning", "context"],
        source: "user_input",
        metadata: { type: "hint" }
      )
    end
    
    # Add additional_context if provided
    if additional_context.present?
      base_context.add(
        content: additional_context,
        topics: ["planning", "context"],
        source: "user_input",
        metadata: { type: "additional_context" }
      )
    end
    
    base_context
  end

  # Execute Daedalus worker
  # Logic is delegated to worker per project rules
  def execute_daedalus(goal:, path:, context:)
    worker = DaedalusWorker.new(
      goal: goal,
      path: path,
      context: context
    )

    result = worker.execute

    # Convert execution_plan to hash for JSON serialization
    if result[:execution_plan]
      result[:execution_plan] = result[:execution_plan].to_h
    end

    result
  end
end

