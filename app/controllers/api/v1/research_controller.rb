# frozen_string_literal: true

module Api
  module V1
    # API controller for triggering codebase research.
    class ResearchController < ApplicationController
      VALID_OUTPUT_MODES = %w[report documentation].freeze

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
      #     options: {
      #       max_depth: int,
      #       output_modes: ["report", "documentation"]  # Array of output types
      #     }
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

        # Parse and validate output_modes (array of modes)
        # Default to both if not specified
        raw_modes = options[:output_modes] || options[:output_mode] || ["report", "documentation"]
        raw_modes = Array(raw_modes).map(&:to_s)
        output_modes = raw_modes & VALID_OUTPUT_MODES
        if output_modes.empty?
          return render json: { error: "output_modes must include at least one of: #{VALID_OUTPUT_MODES.join(', ')}" }, status: :unprocessable_entity
        end
        output_modes_sym = output_modes.map(&:to_sym)

        # Normalize context keys to symbols
        normalized_context = normalize_context(context)

        # Execute research
        worker = CodebaseResearcher.new(
          goal: goal,
          path: expanded_path,
          context: normalized_context,
          max_depth: options[:max_depth]&.to_i || 4,
          output_modes: output_modes_sym
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

            output_files = output_service.write(
              synthesis: result[:synthesis],
              output_modes: output_modes_sym,
              file_analyses: result[:file_analyses] || []
            )
          end

          render json: {
            status: "complete",
            owner_id: result[:owner_id],
            findings: result[:findings],
            file_analyses: result[:file_analyses],
            sub_questions: result[:sub_questions],
            output_files: output_files,
            output_modes: output_modes,
            summary: result[:synthesis]&.dig(:summary),
            errors: []
          }, status: :ok
        else
          render json: {
            status: "failed",
            owner_id: result[:owner_id],
            findings: result[:findings] || [],
            file_analyses: result[:file_analyses] || [],
            output_files: [],
            output_modes: output_modes,
            errors: [result[:error]]
          }, status: :ok
        end
      rescue StandardError => e
        render json: {
          status: "error",
          findings: [],
          file_analyses: [],
          output_files: [],
          output_modes: Array(params.dig(:options, :output_modes) || params.dig(:options, :output_mode) || ["report"]),
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

