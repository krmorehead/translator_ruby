# frozen_string_literal: true

module Research
  # Prompt that formats synthesis output as documentation.
  # Ensures output conforms to project documentation standards.
  class OutputFormattingPrompt < BasePrompt
    def system_prompt
      <<~PROMPT
        You are a technical documentation expert. Your task is to format research findings
        into clear, well-structured documentation.

        ## Documentation Standards

        1. **Structure**: Use clear hierarchical headings (##, ###, ####)
        2. **Clarity**: Write for developers who need to understand the codebase quickly
        3. **Code References**: Include file paths and relevant code snippets
        4. **Visual Aids**: Use lists, tables, and diagrams (mermaid) where helpful
        5. **Actionability**: Make findings useful for future development decisions

        ## Markdown Formatting Rules

        - Use ## for main sections
        - Use ### for subsections
        - Use bullet points for lists of items
        - Use numbered lists for sequential steps
        - Use code blocks with language tags for code snippets
        - Use tables for structured comparisons
        - Use > blockquotes for important notes

        ## Section Templates

        A well-structured document includes:
        1. **Overview**: Brief summary of findings
        2. **Architecture**: How the researched area fits in the system
        3. **Key Components**: Main classes/modules with descriptions
        4. **Data Flow**: How data moves through the system
        5. **Dependencies**: What the area depends on
        6. **Recommendations**: Suggested next steps or improvements
        7. **Open Questions**: Areas needing further investigation
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          title: {
            type: "string",
            description: "Document title"
          },
          sections: {
            type: "array",
            items: {
              type: "object",
              properties: {
                heading: { type: "string" },
                level: { type: "integer", description: "Heading level (2-4)" },
                content: { type: "string", description: "Markdown content" }
              },
              required: %w[heading level content],
              additionalProperties: false
            }
          },
          table_of_contents: {
            type: "array",
            items: {
              type: "object",
              properties: {
                title: { type: "string" },
                anchor: { type: "string" }
              },
              required: %w[title anchor],
              additionalProperties: false
            }
          },
          metadata: {
            type: "object",
            properties: {
              research_goal: { type: "string" },
              codebase_path: { type: "string" },
              generated_at: { type: "string" },
              confidence_level: { type: "string" }
            },
            required: %w[research_goal],
            additionalProperties: false
          }
        },
        required: %w[title sections metadata],
        additionalProperties: false
      }
    end

    # Format synthesis results as documentation
    # @param synthesis [Hash] Synthesis results from SynthesisPrompt
    # @param format_spec [Hash] Format specification (single_file, multi_file, etc.)
    # @return [Hash] Formatted documentation
    def format(synthesis:, format_spec: {})
      prompt = build_prompt(synthesis, format_spec)
      context = {
        output_format: format_spec[:format] || "single_file",
        include_toc: format_spec[:include_toc] != false
      }

      execute(prompt: prompt, context: context)
    end

    # Render the formatted output to markdown string
    # @param formatted [Hash] Result from format()
    # @return [String] Rendered markdown
    def render_markdown(formatted)
      content = formatted[:content] || formatted
      output = []

      # Title
      output << "# #{content['title'] || content[:title]}"
      output << ""

      # Table of contents
      toc = content['table_of_contents'] || content[:table_of_contents]
      if toc&.any?
        output << "## Table of Contents"
        output << ""
        toc.each do |item|
          title = item['title'] || item[:title]
          anchor = item['anchor'] || item[:anchor]
          output << "- [#{title}](##{anchor})"
        end
        output << ""
      end

      # Sections
      sections = content['sections'] || content[:sections] || []
      sections.each do |section|
        heading = section['heading'] || section[:heading]
        level = section['level'] || section[:level] || 2
        section_content = section['content'] || section[:content]

        output << "#{'#' * level} #{heading}"
        output << ""
        output << section_content
        output << ""
      end

      output.join("\n")
    end

    private

    def build_prompt(synthesis, format_spec)
      prompt_parts = ["Format the following research findings into documentation:"]

      prompt_parts << "\n## Summary:"
      prompt_parts << (synthesis[:summary] || synthesis["summary"] || "No summary provided")

      prompt_parts << "\n## Detailed Sections:"
      sections = synthesis[:detailed_sections] || synthesis["detailed_sections"] || []
      sections.each do |section|
        sub_q = section[:sub_question] || section["sub_question"]
        answer = section[:answer] || section["answer"]
        prompt_parts << "### #{sub_q}"
        prompt_parts << answer
      end

      prompt_parts << "\n## Validated Insights:"
      insights = synthesis[:validated_insights] || synthesis["validated_insights"] || []
      insights.each do |insight|
        text = insight[:insight] || insight["insight"]
        conf = insight[:confidence] || insight["confidence"]
        prompt_parts << "- #{text} (confidence: #{conf})"
      end

      if (open_qs = synthesis[:open_questions] || synthesis["open_questions"])&.any?
        prompt_parts << "\n## Open Questions:"
        open_qs.each do |q|
          question = q[:question] || q["question"]
          prompt_parts << "- #{question}"
        end
      end

      prompt_parts << "\n## Format Specifications:"
      prompt_parts << "- Format: #{format_spec[:format] || 'single_file'}"
      prompt_parts << "- Include TOC: #{format_spec[:include_toc] != false}"

      prompt_parts.join("\n")
    end
  end
end

