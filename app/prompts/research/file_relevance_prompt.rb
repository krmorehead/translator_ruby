# frozen_string_literal: true

module Research
  # Prompt that scores file relevance to a research question.
  # Helps filter candidate files to focus on the most relevant ones.
  class FileRelevancePrompt < BasePrompt
    def system_prompt
      <<~PROMPT
        You are a code relevance expert. Your task is to evaluate how relevant a file is
        to a given research question.

        ## Scoring Criteria

        Score files from 0.0 to 1.0 based on:

        **High Relevance (0.8-1.0):**
        - File directly implements or defines the concept in question
        - File is a primary entry point for the functionality
        - File contains core business logic for the topic

        **Medium Relevance (0.5-0.79):**
        - File uses or references the concept
        - File provides supporting functionality
        - File contains relevant configuration or setup

        **Low Relevance (0.2-0.49):**
        - File has tangential connection to the topic
        - File might provide useful context
        - File references related concepts

        **Minimal/No Relevance (0.0-0.19):**
        - File has no meaningful connection
        - File is unrelated infrastructure
        - File is boilerplate or generated code

        ## Evaluation Approach

        1. Analyze the file path and name for clues
        2. Scan the preview content for relevant terms
        3. Consider the file's role in typical project structure
        4. Look for direct mentions of the research topic
        5. Identify indirect connections through dependencies
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          evaluations: {
            type: "array",
            items: {
              type: "object",
              properties: {
                file_path: {
                  type: "string",
                  description: "The file being evaluated"
                },
                relevance_score: {
                  type: "number",
                  description: "Relevance score from 0.0 to 1.0"
                },
                reasoning: {
                  type: "string",
                  description: "Brief explanation for the score"
                },
                key_terms_found: {
                  type: "array",
                  items: { type: "string" },
                  description: "Relevant terms found in the file"
                },
                recommended_priority: {
                  type: "string",
                  enum: %w[high medium low skip],
                  description: "Recommended investigation priority"
                }
              },
              required: %w[file_path relevance_score reasoning key_terms_found recommended_priority],
              additionalProperties: false
            }
          }
        },
        required: ["evaluations"],
        additionalProperties: false
      }
    end

    # Score a single file's relevance
    # @param file_path [String] Path to the file
    # @param preview [String] First N lines of the file
    # @param question [String] The research question
    # @return [Hash] Evaluation result
    def score_file(file_path:, preview:, question:)
      score_files(files: [{ path: file_path, preview: preview }], question: question)
    end

    # Score multiple files in batch
    # @param files [Array<Hash>] Array of { path:, preview: } hashes
    # @param question [String] The research question
    # @return [Hash] Batch evaluation results
    def score_files(files:, question:)
      prompt = build_prompt(files, question)
      execute(prompt: prompt, context: { question: question })
    end

    private

    def build_prompt(files, question)
      file_descriptions = files.map do |file|
        preview = file[:preview]&.lines&.first(30)&.join || "(empty file)"
        "## File: #{file[:path]}\n```\n#{preview}\n```"
      end.join("\n\n")

      <<~PROMPT
        Research Question: #{question}

        Evaluate the relevance of these files to the research question:

        #{file_descriptions}

        For each file, provide a relevance score and brief reasoning.
      PROMPT
    end
  end
end

