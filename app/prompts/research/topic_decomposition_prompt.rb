# frozen_string_literal: true

module Research
  # Prompt that breaks research topics into focused sub-questions with base case detection.
  # Guides the LLM to produce actionable, specific questions and identify when questions
  # are "leaf" level (no further decomposition needed).
  # Uses general_llm because it produces variable-length output with multiple sub-questions.
  class TopicDecompositionPrompt < BaseResearchPrompt
    def system_prompt
      <<~PROMPT
        You are a research planning expert specialized in codebase analysis.

        Your task is to decompose broad research topics into specific, actionable sub-questions.
        Each sub-question should be focused enough to guide targeted investigation of source code.

        ## Decomposition Guidelines

        1. **Specificity**: Each question should be answerable by examining a small set of files
        2. **Actionability**: Questions should guide concrete investigation steps
        3. **Coverage**: Together, sub-questions should cover all aspects of the original topic
        4. **Independence**: Sub-questions should be relatively independent of each other
        5. **Priority**: Order questions by investigation priority (what to explore first)

        ## Base Case Detection

        For each sub-question, determine if it's a "leaf" (no further decomposition needed):

        A question is a LEAF when:
        - It's answerable by examining 1-3 files
        - It's specific enough to have a concrete, verifiable answer
        - It doesn't require further context-setting to investigate

        A question is NOT a leaf when:
        - It spans multiple subsystems or modules
        - It requires understanding broader context first
        - It can be meaningfully broken into smaller questions

        ## Aspects to Consider

        When decomposing, consider these codebase aspects:
        - Architecture and structure
        - Implementation details
        - Data flow and dependencies
        - Configuration and setup
        - Entry points and interfaces
        - Error handling and edge cases
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          questions: {
            type: "array",
            maxItems: 5,
            items: {
              type: "object",
              properties: {
                question: { type: "string", maxLength: 100 },
                priority: { type: "integer" },
                rationale: { type: "string", maxLength: 80 },
                is_leaf: { type: "boolean" },
                parent_id: { type: "string", maxLength: 50 },
                aspects: {
                  type: "array",
                  maxItems: 3,
                  items: { type: "string", maxLength: 30 }
                }
              },
              required: %w[question priority rationale is_leaf],
              additionalProperties: false
            }
          },
          topic_summary: { type: "string", maxLength: 150 }
        },
        required: %w[questions topic_summary],
        additionalProperties: false
      }
    end

    # Execute topic decomposition
    # @param topic [String] The research topic to decompose
    # @param context [Hash] Optional context including codebase info
    # @return [Hash] Decomposition result with questions array
    def decompose(topic:, context: {})
      prompt = build_prompt(topic, context)
      execute(prompt: prompt, context: context)
    end

    
    def build_prompt(topic, context)
      prompt_parts = ["Research Topic: #{topic.to_s.truncate(200)}"]

      # Include truncated codebase summary if provided
      if context[:codebase_summary]
        prompt_parts << "\nCodebase Context:\n#{context[:codebase_summary].to_s.truncate(300)}"
      end

      # Include truncated file tree if provided (limit to avoid context overflow)
      if context[:file_tree]
        prompt_parts << "\nFile Structure:\n#{context[:file_tree].to_s.truncate(400)}"
      end

      # Include focus guidance from seed context
      if context[:focus_guidance]
        prompt_parts << "\n#{context[:focus_guidance].to_s.truncate(200)}"
      end

      # Include known relevant files (limit to 5)
      if context[:known_relevant_files]&.any?
        prompt_parts << "\nKnown Relevant Files:"
        context[:known_relevant_files].first(5).each { |f| prompt_parts << "- #{f}" }
      end

      # Handle parent question (recursive decomposition)
      if context[:parent_question]
        prompt_parts << "\nDecomposing: #{context[:parent_question].to_s.truncate(100)}"
      else
        prompt_parts << "\nBreak into 3-5 focused sub-questions."
      end

      # Include previous questions to avoid duplication (limit to 3)
      if context[:previous_questions]&.any?
        prompt_parts << "\nAvoid duplicating:"
        context[:previous_questions].first(3).each { |q| prompt_parts << "- #{q.to_s.truncate(50)}" }
      end

      prompt_parts.join("\n")
    end
  end
end

