# frozen_string_literal: true

module Research
  module OutputTemplates
    # Template for rendering research reports.
    # Produces single or multi-file report documents organized by sub-question.
    class ReportTemplate < BaseOutputTemplate
      def template_name
        "report"
      end

      # Render synthesis results as a research report
      # @param data [Hash] Synthesis results with :summary, :detailed_sections, etc.
      # @return [String] Rendered markdown report
      def render(data)
        output = []

        # Header
        output << "# Research: #{data[:research_topic] || 'Untitled Research'}"
        output << ""
        output << "> Generated: #{timestamp}"
        output << ""

        # Summary
        if data[:summary]
          output << "## Summary"
          output << ""
          output << data[:summary]
          output << ""
        end

        # Table of Contents
        sections = data[:detailed_sections] || []
        if sections.any?
          output << "## Table of Contents"
          output << ""
          sections.each do |section|
            sub_q = section[:sub_question]
            anchor = slugify(sub_q).gsub("_", "-")
            output << "- [#{sub_q}](##{anchor})"
          end
          output << ""
        end

        # Detailed Sections
        sections.each do |section|
          sub_q = section[:sub_question]
          answer = section[:answer]
          findings = section[:key_findings] || []

          output << "## #{sub_q}"
          output << ""
          output << answer
          output << ""

          if findings.any?
            output << "### Key Findings"
            output << ""
            findings.each { |f| output << "- #{f}" }
            output << ""
          end
        end

        # Validated Insights
        insights = data[:validated_insights] || []
        if insights.any?
          output << "## Validated Insights"
          output << ""
          insights.each { |insight| output << "- #{insight}" }
          output << ""
        end

        # Open Questions
        open_qs = data[:open_questions] || []
        if open_qs.any?
          output << "## Open Questions"
          output << ""
          open_qs.each { |q| output << "- #{q}" }
          output << ""
        end

        # Conflicts
        conflicts = data[:conflicts] || []
        if conflicts.any?
          output << "## Conflicts Requiring Review"
          output << ""
          conflicts.each { |c| output << "- #{c}" }
          output << ""
        end

        output.join("\n")
      end

      # Render a section file for multi-file output
      # @param section [Hash] Section data with :sub_question, :answer, :key_findings
      # @return [String] Rendered section markdown
      def render_section(section)
        output = []
        sub_q = section[:sub_question]
        answer = section[:answer]
        findings = section[:key_findings] || []

        output << "# #{sub_q}"
        output << ""
        output << answer
        output << ""

        if findings.any?
          output << "## Key Findings"
          output << ""
          findings.each { |f| output << "- #{f}" }
        end

        output.join("\n")
      end

      # Render an index file for multi-file output
      # @param data [Hash] Synthesis data
      # @param base_name [String] Base filename for section files
      # @return [String] Rendered index markdown
      def render_index(data, base_name)
        output = []
        output << "# #{data[:research_topic] || 'Research'} - Index"
        output << ""
        output << "> Generated: #{timestamp}"
        output << ""
        output << "## Summary"
        output << ""
        output << (data[:summary] || "No summary available")
        output << ""
        output << "## Sections"
        output << ""

        sections = data[:detailed_sections] || []
        sections.each_with_index do |section, idx|
          sub_q = section[:sub_question]
          filename = "#{base_name}_#{idx + 1}_#{slugify(sub_q)}.md"
          output << "- [#{sub_q}](#{filename})"
        end

        output.join("\n")
      end

      private

      # Generate a slug from text for anchors/filenames
      # Only used in report template for anchor generation
      def slugify(text)
        text
          .to_s
          .downcase
          .gsub(/[^a-z0-9\s-]/, "")
          .gsub(/\s+/, "_")
          .gsub(/_+/, "_")
          .slice(0, 50)
          .gsub(/^_|_$/, "")
      end
    end
  end
end

