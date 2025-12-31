# frozen_string_literal: true

module Planning
  # Base class for all planning-related prompts.
  # Provides common functionality and structure for project plan generation.
  # Planning prompts incorporate context into their prompt text, so format_context returns empty.
  class BasePlanningPrompt < BasePrompt
    # Planning prompts incorporate context into build_prompt, not format_context
    # @param context [Hash] The context hash (used internally, not formatted)
    # @param question [String] Ignored for planning prompts
    # @return [String] Empty string - context is handled in build_prompt
    def format_context(context, question: nil)
      ""
    end

    # Common system context for planning prompts
    PLANNING_CONTEXT = <<~CONTEXT
      You are an expert software architect and project planner. Your role is to create
      comprehensive, actionable project plans that guide developers through implementation.

      ## Project Plan Format Requirements

      Project plans must follow this structure:

      ### Milestones
      - Each milestone represents a logical grouping of related functionality
      - Milestones should be independently demonstrable when complete
      - A milestone typically contains 3-7 steps
      - Milestone titles should be action-oriented (e.g., "Build the Translation Service")

      ### Steps
      - Each step should be small and focused (completable in one session)
      - Steps must describe intent, not implementation code
      - Every step MUST include test requirements
      - Steps should build incrementally on previous steps
      - Steps are numbered as {milestone}.{step} (e.g., 1.1, 1.2, 2.1)

      ### Step Structure
      Each step must have:
      1. **Intent**: What is being created/modified, why it's needed, how it fits
      2. **Details**: Specific requirements, constraints, behaviors (NO code)
      3. **Tests**: Unit tests, integration tests, edge cases

      ## Key Rules
      - NO implementation code in plans
      - Every step needs tests defined
      - Keep steps atomic and focused
      - Reference specific files when relevant
    CONTEXT

    
    # Format research results for prompt context
    # @param research_results [Hash] Output from CodebaseResearcher
    # @return [String] Formatted context string
    def format_research_context(research_results)
      return "" if research_results.nil? || research_results.empty?

      parts = []

      # Add synthesis summary
      synthesis = research_results[:synthesis] || research_results["synthesis"] || {}
      summary = synthesis[:summary] || synthesis["summary"]
      parts << "## Research Summary\n#{summary}" if summary.present?

      # Add key findings
      findings = research_results[:findings] || research_results["findings"] || []
      if findings.any?
        parts << "## Key Findings"
        findings.first(10).each do |finding|
          text = finding[:text] || finding["text"]
          parts << "- #{text}" if text.present?
        end
      end

      parts.join("\n\n")
    end

    # Extract file paths from research results
    # @param research_results [Hash] Output from CodebaseResearcher
    # @return [Array<String>] List of file paths
    def extract_file_list(research_results)
      return [] if research_results.nil?

      files = Set.new

      # From relevant_files
      (research_results[:relevant_files] || []).each do |f|
        path = f[:file_path] || f["file_path"]
        files.add(path) if path.present?
      end

      # From file_analyses
      (research_results[:file_analyses] || []).each do |a|
        path = a[:file_path] || a["file_path"]
        files.add(path) if path.present?
      end

      files.to_a
    end

    # Generate date prefix in MM-DD-YYYY format
    # @return [String] Formatted date
    def generate_date_prefix
      Time.now.strftime("%m-%d-%Y")
    end

    # Override execute to provide empty context by default
    # Planning prompts don't use context objects
    def execute(prompt:, context: "")
      super(prompt: prompt, context: context)
    end
  end
end

