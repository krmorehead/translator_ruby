# frozen_string_literal: true

module Research
  # Prompt for generating per-file documentation.
  # Extracts method signatures, dependencies, and purposes from code files.
  class PerFileDocPrompt < BaseResearchPrompt
    def system_prompt
      <<~PROMPT
        You are a code documentation expert. Your task is to analyze a source code file
        and extract structured information for documentation.

        ## Documentation Goals

        1. **Summary**: Write a brief, clear description of the file's purpose
        2. **Dependencies**: Identify what external files/modules this file depends on
        3. **Methods**: Document each method's purpose, parameters, and return values
        4. **Method Relationships**: Identify which methods call other methods

        ## Output Format

        Produce structured output that can be used to generate markdown documentation.
        Focus on information that helps developers understand:
        - What this file does
        - How it relates to other files
        - What each method does and how to use it

        ## Guidelines

        - Be concise but complete
        - Focus on public interfaces over implementation details
        - Identify patterns and design decisions
        - Note any important side effects or dependencies
        - For method calls, only include calls to methods defined in this file or notable external calls
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          summary: {
            type: "string",
            description: "Brief description of the file's purpose (1-2 sentences)"
          },
          external_references: {
            type: "array",
            items: { type: "string" },
            description: "File paths this file depends on (requires, imports, inherits from)"
          },
          methods: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string", description: "Method name" },
                purpose: { type: "string", description: "What the method does" },
                parameters: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      name: { type: "string" },
                      type: { type: "string" },
                      description: { type: "string" }
                    },
                    required: %w[name],
                    additionalProperties: false
                  }
                },
                returns: { type: "string", description: "What the method returns" },
                calls: {
                  type: "array",
                  items: { type: "string" },
                  description: "Other methods this method calls"
                }
              },
              required: %w[name purpose],
              additionalProperties: false
            }
          },
          design_patterns: {
            type: "array",
            items: { type: "string" },
            description: "Design patterns used in this file"
          },
          key_classes: {
            type: "array",
            items: {
              type: "object",
              properties: {
                name: { type: "string" },
                purpose: { type: "string" },
                inherits_from: { type: "string" }
              },
              required: %w[name purpose],
              additionalProperties: false
            },
            description: "Classes defined in this file"
          }
        },
        required: %w[summary external_references methods],
        additionalProperties: false
      }
    end

    # Analyze a file and extract documentation information
    # @param content [String] The file content
    # @param file_path [String] Path to the file
    # @param goal_context [String] The research goal for context
    # @param sub_questions [Array<String>] Sub-questions this file may answer
    # @param prior_context [String, nil] Relevant prior findings for context
    # @return [Hash] Structured documentation data
    def analyze(content:, file_path:, goal_context: nil, sub_questions: [], prior_context: nil)
      prompt = build_prompt(content, file_path, goal_context, sub_questions, prior_context)
      context = {
        file_path: file_path,
        goal: goal_context,
        sub_questions: sub_questions
      }

      result = execute(prompt: prompt, context: context)

      # Add file path to result for downstream use
      analysis = result[:content] || {}
      analysis[:file_path] = file_path
      analysis[:relevant_sub_questions] = identify_relevant_questions(analysis, sub_questions)

      { content: analysis, thoughts: result[:thoughts] }
    end

    
    def build_prompt(content, file_path, goal_context, sub_questions, prior_context = nil)
      parts = []

      parts << "Analyze the following file and extract documentation information:"
      parts << ""
      parts << "**File:** `#{file_path}`"
      parts << ""

      if goal_context.present?
        parts << "**Research Context:** #{goal_context}"
        parts << ""
      end

      if prior_context.present?
        parts << "**Prior Relevant Findings:**"
        parts << prior_context
        parts << ""
      end

      if sub_questions.any?
        parts << "**Questions this file may help answer:**"
        sub_questions.each { |q| parts << "- #{q}" }
        parts << ""
      end

      parts << "**File Content:**"
      parts << "```"
      parts << content
      parts << "```"
      parts << ""
      parts << "Extract the summary, external references (imports/requires), and method documentation."

      parts.join("\n")
    end

    def identify_relevant_questions(analysis, sub_questions)
      return [] if sub_questions.empty?

      # Simple heuristic: a question is relevant if keywords from the analysis appear in it
      summary = analysis[:summary]&.downcase || ""
      method_names = (analysis[:methods] || []).map { |m| m[:name]&.downcase }.compact

      sub_questions.select do |question|
        q_lower = question.downcase
        # Check if summary terms appear in question
        summary_relevant = summary.split.any? { |word| word.length > 3 && q_lower.include?(word) }
        # Check if method names appear in question
        method_relevant = method_names.any? { |name| q_lower.include?(name) }

        summary_relevant || method_relevant
      end
    end
  end
end

