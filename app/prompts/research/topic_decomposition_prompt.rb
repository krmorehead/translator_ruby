# frozen_string_literal: true

module Research
  # Prompt that breaks research topics into focused sub-questions with base case detection.
  # Guides the LLM to produce actionable, specific questions and identify when questions
  # are "leaf" level (no further decomposition needed).
  class TopicDecompositionPrompt < BasePrompt
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
            items: {
              type: "object",
              properties: {
                question: {
                  type: "string",
                  description: "The sub-question text"
                },
                priority: {
                  type: "integer",
                  description: "Investigation priority (1 = highest priority)"
                },
                rationale: {
                  type: "string",
                  description: "Why this question is important for understanding the topic"
                },
                is_leaf: {
                  type: "boolean",
                  description: "True if no further decomposition is needed"
                },
                parent_id: {
                  type: "string",
                  description: "Optional ID of parent question for tree building"
                },
                aspects: {
                  type: "array",
                  items: { type: "string" },
                  description: "Which aspects this question addresses (architecture, implementation, etc.)"
                }
              },
              required: %w[question priority rationale is_leaf],
              additionalProperties: false
            }
          },
          topic_summary: {
            type: "string",
            description: "Brief summary of what the research topic encompasses"
          }
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

    private

    def build_prompt(topic, context)
      prompt_parts = ["Research Topic: #{topic}"]

      # Include codebase summary if provided
      if context[:codebase_summary]
        prompt_parts << "\nCodebase Context:\n#{context[:codebase_summary]}"
      end

      # Include file tree if provided
      if context[:file_tree]
        prompt_parts << "\nFile Structure:\n#{context[:file_tree]}"
      end

      # Include focus guidance from seed context
      if context[:focus_guidance]
        prompt_parts << "\n#{context[:focus_guidance]}"
      end

      # Include known relevant files
      if context[:known_relevant_files]&.any?
        prompt_parts << "\nKnown Relevant Files:"
        context[:known_relevant_files].each { |f| prompt_parts << "- #{f}" }
      end

      # Include prior knowledge from previous research
      if context[:prior_knowledge]
        prompt_parts << "\nPrior Knowledge:\n#{context[:prior_knowledge]}"
      end

      # Include any constraints
      if context[:constraints]
        constraints_text = context[:constraints].is_a?(Hash) ? context[:constraints].to_json : context[:constraints].to_s
        prompt_parts << "\nConstraints: #{constraints_text}"
      end

      # Handle parent question (recursive decomposition)
      if context[:parent_question]
        prompt_parts << "\nThis is a decomposition of: #{context[:parent_question]}"
        prompt_parts << "Focus on breaking this specific question into smaller, more actionable sub-questions."
      else
        prompt_parts << "\nBreak this topic into 3-7 focused sub-questions that would help understand this codebase."
        prompt_parts << "Start with high-level questions, marking specific questions as leaf nodes."
      end

      # Include previous questions at this level to avoid duplication
      if context[:previous_questions]&.any?
        prompt_parts << "\nAlready generated questions (avoid duplicating):"
        context[:previous_questions].each { |q| prompt_parts << "- #{q}" }
      end

      prompt_parts.join("\n")
    end
  end
end

