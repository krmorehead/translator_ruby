# frozen_string_literal: true

module Api
  module V1
    # API controller for triggering codebase research.
    class ResearchController < ApplicationController
      # POST /api/v1/research
      # Request body:
      #   {
      #     goal: string,
      #     path: string,
      #     context: {
      #       known_files: array,
      #       prior_findings: string,
      #       focus_areas: array,
      #       codebase_summary: string,
      #       constraints: object
      #     },
      #     options: { max_depth: int }
      #   }
      def create
        goal = params[:goal]
        path = params[:path]
        context = params[:context] || {}
        options = params[:options] || {}

        # Validate required parameters
        unless goal.present?
          return render json: { error: "goal is required" }, status: :unprocessable_entity
        end

        unless path.present?
          return render json: { error: "path is required" }, status: :unprocessable_entity
        end

        # Validate path exists
        expanded_path = File.expand_path(path)
        unless File.exist?(expanded_path) && File.readable?(expanded_path)
          return render json: { error: "path does not exist or is not readable" }, status: :unprocessable_entity
        end

        # Normalize context keys to symbols
        normalized_context = normalize_context(context)

        # Execute research
        worker = CodebaseResearcher.new(
          goal: goal,
          path: expanded_path,
          context: normalized_context,
          max_depth: options[:max_depth]&.to_i || 4
        )

        result = worker.execute

        if result[:success]
          # Write output if synthesis is available
          output_files = []
          if result[:synthesis]
            output_service = ResearchOutputService.new(
              research_topic: goal,
              base_path: expanded_path
            )
            output_files = output_service.write(synthesis: result[:synthesis])
          end

          render json: {
            status: "complete",
            owner_id: result[:owner_id],
            findings: result[:findings],
            output_files: output_files,
            summary: result[:synthesis]&.dig(:summary),
            errors: []
          }, status: :ok
        else
          render json: {
            status: "failed",
            owner_id: result[:owner_id],
            findings: result[:findings] || [],
            output_files: [],
            errors: [result[:error]]
          }, status: :ok
        end
      rescue StandardError => e
        render json: {
          status: "error",
          findings: [],
          output_files: [],
          errors: [e.message]
        }, status: :internal_server_error
      end

      private

      def normalize_context(context)
        return {} if context.blank?

        context.to_h.deep_symbolize_keys
      end
    end
  end
end

