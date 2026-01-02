# frozen_string_literal: true

module Api
  module V1
    # API controller for Git checkpoint management.
    # Provides endpoints for creating, listing, querying, and rolling back to checkpoints.
    class CheckpointsController < ApplicationController
      before_action :validate_path_param, only: [:create, :index, :show, :diff, :rollback, :candidates]

      # POST /api/v1/checkpoints
      # Create a new checkpoint
      #
      # Request body:
      #   {
      #     path: string (required),
      #     message: string (required),
      #     metadata: {
      #       milestone_id: string,
      #       execution_id: string,
      #       workflow_id: string,
      #       is_backup: boolean
      #     }
      #   }
      def create
        service = CheckpointService.new(path: @path)
        
        unless params[:message].present?
          render json: { success: false, error: "message parameter is required" }, status: :bad_request
          return
        end
        
        metadata = params[:metadata] || {}
        checkpoint = service.create_checkpoint(
          params[:message],
          milestone_id: metadata[:milestone_id],
          execution_id: metadata[:execution_id],
          worker_id: metadata[:workflow_id],
          backup: metadata[:is_backup]
        )

        render json: {
          success: true,
          checkpoint: serialize_checkpoint(checkpoint)
        }, status: :created
      rescue ArgumentError => e
        render json: { success: false, error: e.message }, status: :bad_request
      rescue => e
        render json: { success: false, error: e.message }, status: :internal_server_error
      end

      # GET /api/v1/checkpoints
      # List checkpoints with optional filtering
      #
      # Query params:
      #   path: string (required)
      #   limit: integer
      #   milestone_id: string
      #   execution_id: string
      #   workflow_id: string
      #   is_backup: boolean
      def index
        service = CheckpointService.new(path: @path)
        
        checkpoints = if params[:milestone_id]
          service.checkpoints_for_milestone(params[:milestone_id])
        elsif params[:execution_id]
          service.checkpoints_for_execution(params[:execution_id])
        elsif params[:workflow_id]
          service.checkpoints_for_workflow(params[:workflow_id])
        elsif params[:is_backup] == "true"
          service.backup_checkpoints
        else
          service.list_checkpoints(limit: params[:limit]&.to_i)
        end

        render json: {
          success: true,
          count: checkpoints.size,
          checkpoints: checkpoints.map { |cp| serialize_checkpoint(cp) }
        }
      rescue => e
        render json: { success: false, error: e.message }, status: :internal_server_error
      end

      # GET /api/v1/checkpoints/:id
      # Get a specific checkpoint
      #
      # Query params:
      #   path: string (required)
      def show
        service = CheckpointService.new(path: @path)
        checkpoint = service.get_checkpoint(params[:id])

        if checkpoint
          render json: {
            success: true,
            checkpoint: serialize_checkpoint(checkpoint)
          }
        else
          render json: {
            success: false,
            error: "Checkpoint not found: #{params[:id]}"
          }, status: :not_found
        end
      rescue => e
        render json: { success: false, error: e.message }, status: :internal_server_error
      end

      # GET /api/v1/checkpoints/:id/diff
      # Get diff between checkpoint and current state
      #
      # Query params:
      #   path: string (required)
      #   target_checkpoint_id: string (optional, defaults to current)
      def diff
        service = CheckpointService.new(path: @path)
        
        target_id = params[:target_checkpoint_id] || service.current_checkpoint_id
        diff = service.diff_checkpoint(
          from_checkpoint_id: params[:id],
          to_checkpoint_id: target_id
        )

        render json: {
          success: true,
          from_checkpoint_id: params[:id],
          to_checkpoint_id: target_id,
          changes: diff[:changes],
          summary: {
            files_added: diff[:files_added],
            files_modified: diff[:files_modified],
            files_deleted: diff[:files_deleted],
            total_changes: diff[:total_changes]
          }
        }
      rescue ArgumentError => e
        render json: { success: false, error: e.message }, status: :bad_request
      rescue => e
        render json: { success: false, error: e.message }, status: :internal_server_error
      end

      # POST /api/v1/checkpoints/:id/rollback
      # Rollback to a specific checkpoint
      #
      # Request body:
      #   {
      #     path: string (required),
      #     force: boolean (default: false)
      #   }
      def rollback
        rollback_service = GitRollbackService.new(path: @path)
        
        result = rollback_service.rollback_to_checkpoint(
          checkpoint_id: params[:id],
          force: params[:force] == true
        )

        render json: {
          success: result[:success],
          message: result[:message],
          checkpoint_id: params[:id],
          files_restored: result[:files_restored]
        }
      rescue ArgumentError => e
        render json: { success: false, error: e.message }, status: :bad_request
      rescue => e
        render json: { success: false, error: e.message }, status: :internal_server_error
      end

      # GET /api/v1/checkpoints/candidates
      # List rollback candidates (reachable checkpoints)
      #
      # Query params:
      #   path: string (required)
      #   limit: integer
      def candidates
        rollback_service = GitRollbackService.new(path: @path)
        
        candidates = rollback_service.list_rollback_candidates(limit: params[:limit]&.to_i)

        render json: {
          success: true,
          count: candidates.size,
          candidates: candidates.map { |cp| serialize_checkpoint(cp) }
        }
      rescue => e
        render json: { success: false, error: e.message }, status: :internal_server_error
      end

      # GET /api/v1/checkpoints/current
      # Get current checkpoint ID
      #
      # Query params:
      #   path: string (required)
      def current
        validate_path_param
        
        checkpoint_id = CheckpointTracker.instance.current_id(path: @path)

        render json: {
          success: true,
          checkpoint_id: checkpoint_id
        }
      rescue => e
        render json: { success: false, error: e.message }, status: :internal_server_error
      end

      private

      def validate_path_param
        @path = params[:path] || params[:checkpoints]&.[](:path)
        
        if @path.blank?
          render json: {
            success: false,
            error: "path parameter is required"
          }, status: :bad_request
          return
        end

        unless File.directory?(@path)
          render json: {
            success: false,
            error: "path does not exist: #{@path}"
          }, status: :bad_request
        end
      end

      def checkpoint_metadata
        metadata = params[:metadata] || {}
        {
          milestone_id: metadata[:milestone_id],
          execution_id: metadata[:execution_id],
          workflow_id: metadata[:workflow_id],
          is_backup: metadata[:is_backup] || false
        }.compact
      end

      def serialize_checkpoint(checkpoint)
        {
          id: checkpoint.id,
          message: checkpoint.message,
          created_at: checkpoint.created_at.iso8601,
          files_changed: checkpoint.files_changed.size,
          metadata: checkpoint.metadata,
          milestone_id: checkpoint.milestone_id,
          execution_id: checkpoint.execution_id,
          workflow_id: checkpoint.metadata[:worker_id],
          is_backup: checkpoint.backup?
        }
      end
    end
  end
end

