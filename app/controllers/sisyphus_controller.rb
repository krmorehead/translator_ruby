# frozen_string_literal: true

# Controller for the Sisyphus Agent Worker interface.
# Provides RESTful API endpoints for execution management,
# configuration, and file system operations.
#
# Includes ActionController::Live and StreamableExecution for SSE support.
# Follows the same patterns as DndChatController and ProjectPlanningController.
class SisyphusController < ApplicationController
  include ActionController::Live
  include StreamableExecution
  # Serve the Sisyphus SPA from the built React app
  def index
    public_index = Rails.root.join("public", "index.html")
    built_index = Rails.root.join("frontend", "dist", "index.html")
    index_path = File.exist?(public_index) ? public_index : built_index

    unless File.exist?(index_path)
      return render plain: "Frontend not built. Run `cd frontend && npm run build`.", status: :service_unavailable
    end
    send_file index_path, type: "text/html", disposition: "inline"
  end

  # Execution management endpoints

  # POST /api/sisyphus/executions
  # Start a new execution
  def create_execution
    result = execution_service.start_execution(
      plan_path: params[:plan_path],
      project_path: params[:project_path],
      options: params[:options] || {}
    )

    if result[:success]
      render json: result, status: :created
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :bad_request
  rescue StandardError => e
    Rails.logger.error "Failed to create execution: #{e.message}\n#{e.backtrace.join("\n")}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  # GET /api/sisyphus/executions/:execution_id
  # Get execution state
  def show_execution
    result = execution_service.get_execution_state(
      execution_id: params[:execution_id]
    )

    if result[:success]
      render json: result
    else
      render json: { error: result[:error] }, status: :not_found
    end
  rescue StandardError => e
    Rails.logger.error "Failed to get execution state: #{e.message}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  # GET /api/sisyphus/executions
  # List recent executions
  def list_executions
    limit = params[:limit]&.to_i || 50
    result = execution_service.list_executions(limit: limit)

    if result[:success]
      render json: result
    else
      render json: { error: result[:error] }, status: :internal_server_error
    end
  rescue StandardError => e
    Rails.logger.error "Failed to list executions: #{e.message}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  # GET /api/sisyphus/executions/:execution_id/stream
  # Stream execution progress via Server-Sent Events (SSE)
  def stream_execution
    stream_execution_progress(params[:execution_id])
  end

  # DELETE /api/sisyphus/executions/:execution_id
  # Cancel an execution
  def cancel_execution
    result = execution_service.cancel_execution(
      execution_id: params[:execution_id]
    )

    if result[:success]
      render json: result
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "Failed to cancel execution: #{e.message}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  # Approval endpoints

  # GET /api/sisyphus/approvals/pending
  # Get pending approval requests
  def pending_approvals
    execution_id = params[:execution_id]

    if execution_id
      # Get pending approval for specific execution
      request = approval_store.get_pending_for_execution(execution_id)
      render json: { approval: request&.to_h }
    else
      # Get all pending approvals (future enhancement)
      render json: { error: "execution_id parameter required" }, status: :bad_request
    end
  rescue StandardError => e
    Rails.logger.error "Failed to get pending approvals: #{e.message}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  # POST /api/sisyphus/approvals/:request_id/approve
  # Approve an approval request
  def approve_request
    request_id = params[:request_id]
    resolved_by = params[:resolved_by] || "user"

    request = approval_store.approve(request_id: request_id, resolved_by: resolved_by)

    if request
      render json: { success: true, approval: request.to_h }
    else
      render json: { error: "Approval request not found" }, status: :not_found
    end
  rescue StandardError => e
    Rails.logger.error "Failed to approve request: #{e.message}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  # POST /api/sisyphus/approvals/:request_id/reject
  # Reject an approval request
  def reject_request
    request_id = params[:request_id]
    resolved_by = params[:resolved_by] || "user"

    request = approval_store.reject(request_id: request_id, resolved_by: resolved_by)

    if request
      render json: { success: true, approval: request.to_h }
    else
      render json: { error: "Approval request not found" }, status: :not_found
    end
  rescue StandardError => e
    Rails.logger.error "Failed to reject request: #{e.message}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  # GET /api/sisyphus/approvals/:request_id
  # Get approval request status
  def show_approval
    request_id = params[:request_id]

    request = approval_store.get(request_id)

    if request
      render json: { approval: request.to_h }
    else
      render json: { error: "Approval request not found" }, status: :not_found
    end
  rescue StandardError => e
    Rails.logger.error "Failed to get approval status: #{e.message}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  # File system endpoints

  # GET /api/sisyphus/filesystem/tree
  # List directory contents
  def file_tree
    result = tool_service.list_directory(
      path: params[:path],
      options: file_tree_options
    )

    if result[:success]
      render json: { data: result[:result] }
    else
      render json: { error: result[:error] }, status: :bad_request
    end
  rescue StandardError => e
    Rails.logger.error "Failed to list directory: #{e.message}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  # GET /api/sisyphus/filesystem/read
  # Read file contents
  def read_file
    result = tool_service.read_file(path: params[:path])

    if result[:success]
      render json: { data: result[:result] }
    else
      render json: { error: result[:error] }, status: :bad_request
    end
  rescue StandardError => e
    Rails.logger.error "Failed to read file: #{e.message}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  # GET /api/sisyphus/filesystem/search
  # Search files
  def search_files
    result = tool_service.search_files(
      pattern: params[:pattern],
      path: params[:path],
      options: search_options
    )

    if result[:success]
      render json: { data: result[:result] }
    else
      render json: { error: result[:error] }, status: :bad_request
    end
  rescue StandardError => e
    Rails.logger.error "Failed to search files: #{e.message}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  # Configuration endpoints

  # GET /api/sisyphus/config
  # Get current agent configuration
  def show_config
    config = config_service.get_current_config
    env_vars = config_service.get_environment_vars

    render json: {
      capabilities: config.to_h[:capabilities],
      environment: env_vars
    }
  rescue StandardError => e
    Rails.logger.error "Failed to get config: #{e.message}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  # POST /api/sisyphus/config/validate
  # Validate a capability configuration
  def validate_config
    result = config_service.validate_capability(capability_params)

    render json: result
  rescue StandardError => e
    Rails.logger.error "Failed to validate config: #{e.message}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  # POST /api/sisyphus/config/test
  # Test connection to an LLM capability
  def test_connection
    capability_name = params[:capability_name]&.to_sym

    unless capability_name
      return render json: { error: "capability_name is required" }, status: :bad_request
    end

    result = config_service.test_connection(capability_name)

    render json: result
  rescue StandardError => e
    Rails.logger.error "Failed to test connection: #{e.message}"
    render json: { error: "Internal server error" }, status: :internal_server_error
  end

  private

  def execution_service
    @execution_service ||= ExecutionOrchestrationService.new
  end

  def tool_service
    @tool_service ||= ToolExecutionService.new
  end

  def config_service
    @config_service ||= ConfigurationService.new
  end

  def approval_store
    @approval_store ||= ApprovalRequestStore.new
  end

  def file_tree_options
    {
      max_depth: params[:max_depth]&.to_i,
      extensions: params[:extensions],
      ignore_patterns: params[:ignore_patterns]
    }.compact
  end

  def search_options
    {
      extensions: params[:extensions],
      max_results: params[:max_results]&.to_i,
      case_insensitive: params[:case_insensitive] == "true",
      whole_word: params[:whole_word] == "true",
      context_lines: params[:context_lines]&.to_i
    }.compact
  end

  def capability_params
    params.permit(:name, :model_name, :port, :max_context, :base_url).to_h.deep_symbolize_keys
  end
end

