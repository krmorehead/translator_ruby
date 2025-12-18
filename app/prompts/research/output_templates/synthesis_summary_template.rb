# frozen_string_literal: true

module Research
  module OutputTemplates
    # Template for rendering synthesis_summary.md.
    # Produces a brief answer to the original research question with links to detailed docs.
    class SynthesisSummaryTemplate < BaseOutputTemplate
      def template_name
        "synthesis_summary"
      end

      # Render synthesis summary
      # @param data [Hash] Synthesis data with:
      #   - :research_goal [String] The original research question
      #   - :summary [String] Brief answer to the research question
      #   - :documented_files [Array<Hash>] Files that were documented with :path, :sub_questions
      #   - :sub_questions [Array<Hash>] Decomposed questions with :question, :answer
      #   - :open_questions [Array<Hash>] Questions that remain unanswered
      # @return [String] Rendered markdown
      def render(data)
        output = []

        research_goal = data[:research_goal] || "Research"
        summary = data[:summary] || "No summary available."
        documented_files = data[:documented_files] || []
        sub_questions = data[:sub_questions] || []
        open_questions = data[:open_questions] || []

        # Header
        output << "# Research Summary"
        output << ""
        output << "> **Goal:** #{research_goal}"
        output << ">"
        output << "> Generated: #{timestamp}"
        output << ""

        # Summary answer
        output << "## Answer"
        output << ""
        output << summary
        output << ""

        # Sub-questions addressed
        if sub_questions.any?
          output << "## Questions Investigated"
          output << ""
          sub_questions.each_with_index do |sq, idx|
            question = sq[:question] || sq[:text]
            answer = sq[:answer] || sq[:summary] || "See documented files."
            output << "### #{idx + 1}. #{question}"
            output << ""
            output << answer
            output << ""
          end
        end

        # Documented files index
        if documented_files.any?
          output << "## Documented Files"
          output << ""
          output << "The following files were analyzed and documented:"
          output << ""

          # Group by directory
          by_directory = documented_files.group_by { |f| File.dirname(f[:path]) }
          by_directory.each do |dir, files|
            output << "### #{dir}/"
            output << ""
            files.each do |file|
              filename = File.basename(file[:path])
              doc_path = file[:path].sub(/\.[^.]+$/, ".md")
              sub_qs = file[:sub_questions] || []
              if sub_qs.any?
                output << "- [#{filename}](#{doc_path}) - answers: #{sub_qs.join(', ')}"
              else
                output << "- [#{filename}](#{doc_path})"
              end
            end
            output << ""
          end
        end

        # Open questions
        if open_questions.any?
          output << "## Open Questions"
          output << ""
          output << "The following questions remain unanswered or need further investigation:"
          output << ""
          open_questions.each do |q|
            question = q[:question]
            reason = q[:reason]
            output << "- **#{question}**"
            output << "  - #{reason}" if reason
          end
          output << ""
        end

        output.join("\n")
      end
    end
  end
end

