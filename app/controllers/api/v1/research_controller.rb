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

        # Build proper context object from parameters (OOP pattern: use context objects, not hashes)
        research_context = build_research_context(goal, context)

        # Execute research
        worker = CodebaseResearcher.new(
          goal: goal,
          path: expanded_path,
          context: research_context,
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


      def build_research_context(goal, context_params)
        research_context = Contexts::ResearchContext.new(research_goal: goal)

        # Populate from parameters if provided
        if context_params.present?
          normalized = context_params.to_h.deep_symbolize_keys

          # Add known files if provided
          if normalized[:known_files].present?
            Array(normalized[:known_files]).each do |file_path|
              research_context.add_file_summary(
                file_path: file_path,
                summary: "Known file from context",
                methods: []
              )
            end
          end

          # Add prior findings if provided
          if normalized[:prior_findings].present?
            research_context.add_finding(
              text: normalized[:prior_findings],
              source: "context"
            )
          end
        end

        research_context
      end
    end
  end
end

