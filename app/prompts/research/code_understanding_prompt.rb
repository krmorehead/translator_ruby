# frozen_string_literal: true

module Research
  # Prompt that analyzes code content with two output modes:
  # - Language-agnostic: for research/planning (conceptual, cross-language)
  # - Language-specific: for debugging/fixes (exact syntax, line numbers)
  #
  # The mode is determined by analyzing the research goal.
  class CodeUnderstandingPrompt < BaseResearchPrompt
    def system_prompt
      <<~PROMPT
        You are a code analysis expert. Your task is to understand code files and extract
        insights relevant to a research goal.

        ## Analysis Approach

        First, determine the analysis mode based on the goal:

        **Language-Specific Mode** (for errors, bugs, implementation details):
        - Include exact method signatures and line references
        - Note specific language idioms and patterns
        - Track precise error traces and locations
        - Reference specific variable names and types

        **Language-Agnostic Mode** (for architecture, planning, documentation):
        - Focus on conceptual purpose and design patterns
        - Describe relationships and data flow abstractly
        - Emphasize design rationale and architectural role
        - Use cross-language concepts (e.g., "dependency injection" not "constructor params")

        ## Output Structure

        Always include:
        1. **Purpose**: What this code does and why it exists
        2. **Key Components**: Main classes, functions, or sections
        3. **Dependencies**: What this code relies on
        4. **Patterns**: Design patterns or idioms used
        5. **Insights**: Key findings relevant to the research goal

        For Language-Specific mode, add:
        - Exact signatures with line numbers
        - Language-specific patterns
        - Potential issues or code smells

        For Language-Agnostic mode, add:
        - Architectural role in the system
        - Design decisions and trade-offs
        - Conceptual relationships
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          mode: {
            type: "string",
            enum: %w[language_specific language_agnostic]
          },
          mode_rationale: {
            type: "string",
            maxLength: 100
          },
          purpose_summary: {
            type: "string",
            maxLength: 200
          },
          key_components: {
            type: "array",
            maxItems: 5,
            items: {
              type: "object",
              properties: {
                name: { type: "string", maxLength: 50 },
                type: { type: "string", maxLength: 30 },
                description: { type: "string", maxLength: 100 },
                line_reference: { type: "string", maxLength: 20 }
              },
              required: %w[name type description],
              additionalProperties: false
            }
          },
          dependencies: {
            type: "array",
            maxItems: 5,
            items: {
              type: "object",
              properties: {
                name: { type: "string", maxLength: 50 },
                relationship: { type: "string", maxLength: 30 },
                purpose: { type: "string", maxLength: 80 }
              },
              required: %w[name relationship purpose],
              additionalProperties: false
            }
          },
          patterns_identified: {
            type: "array",
            maxItems: 3,
            items: { type: "string", maxLength: 50 }
          },
          insights: {
            type: "array",
            maxItems: 3,
            items: {
              type: "object",
              properties: {
                finding: { type: "string", maxLength: 100 },
                relevance: { type: "string", maxLength: 80 },
                confidence: { type: "number" }
              },
              required: %w[finding relevance confidence],
              additionalProperties: false
            }
          },
          architectural_notes: {
            type: "string",
            maxLength: 150
          },
          specific_issues: {
            type: "array",
            maxItems: 3,
            items: { type: "string", maxLength: 80 }
          }
        },
        required: %w[mode mode_rationale purpose_summary key_components dependencies patterns_identified insights],
        additionalProperties: false
      }
    end

    # Analyze a code file
    # @param content [String] The file content
    # @param goal [String] The research goal (determines analysis mode)
    # @param file_path [String] Path to the file (for context)
    # @param previous_context [Hash] Context from previous analyses
    # @return [Hash] Analysis result
    def analyze(content:, goal:, file_path: nil, previous_context: nil)
      prompt = build_prompt(content, goal, file_path, previous_context)
      context = { goal: goal, file_path: file_path }
      context[:previous_findings] = previous_context if previous_context

      execute(prompt: prompt, context: context)
    end

    
    def build_prompt(content, goal, file_path, previous_context)
      prompt_parts = ["Research Goal: #{goal}"]
      prompt_parts << "File: #{file_path}" if file_path

      if previous_context
        # Include prior relevant findings from research context
        if previous_context[:prior_context].present?
          prompt_parts << "\nRelevant Prior Findings:"
          prompt_parts << previous_context[:prior_context]
        end

        # Include findings from earlier passes on THIS file
        if previous_context[:key_findings].present?
          prompt_parts << "\nFindings from Previous Pass on This File:"
          prompt_parts << previous_context[:key_findings].to_s
        end
      end

      # Truncate content if too long
      truncated = content.lines.first(500).join
      if content.lines.size > 500
        truncated += "\n... (#{content.lines.size - 500} more lines truncated)"
      end

      prompt_parts << "\nCode to Analyze:\n```\n#{truncated}\n```"
      prompt_parts << "\nAnalyze this code in the context of the research goal."
      prompt_parts << "Determine the appropriate analysis mode (specific vs agnostic) based on the goal."

      prompt_parts.join("\n")
    end
  end
end

