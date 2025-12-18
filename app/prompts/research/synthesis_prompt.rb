# frozen_string_literal: true

module Research
  # Prompt that synthesizes findings into unified understanding.
  # Designed to combine multiple parallel analyses and distill results through cross-validation.
  class SynthesisPrompt < BasePrompt
    def system_prompt
      <<~PROMPT
        You are a research synthesis expert. Your task is to combine findings from multiple
        analysis passes into a coherent, validated understanding.

        ## Synthesis Process

        1. **Cross-Validation**: Include insights that appear in 2+ analysis passes as validated
        2. **Conflict Detection**: Flag areas where passes disagree
        3. **Relevance Filtering**: Remove findings irrelevant to the original topic
        4. **Hierarchy Reconstruction**: Organize findings by the goal decomposition tree
        5. **Gap Identification**: Note areas that need further investigation

        ## Cross-Validation Rules

        - An insight is VALIDATED if it appears (even with slightly different wording) in at least 2 analysis passes
        - When validating, preserve the key terms from the original findings in your insight text
        - An insight is CONFLICTED if passes give contradictory information
        - Include unvalidated insights (appearing in only 1 pass) with lower confidence

        ## IMPORTANT: Preserving Finding Content

        When creating validated_insights, use the same key terms from the original findings.
        For example, if passes mention "addition", your validated insight MUST include the word "addition".

        ## Filtering Criteria

        Filter out findings that are:
        - Tangentially related but don't address the core question
        - Implementation details when researching architecture (or vice versa)
        - Generic observations that don't provide specific value

        ## Output Structure

        Create a coherent narrative that:
        - Addresses the original research goal directly
        - Organizes insights by sub-questions
        - Highlights key findings with confidence levels
        - Notes conflicts for human review
        - Identifies remaining open questions

        ALWAYS provide a non-empty summary field addressing the research goal.
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          validated_insights: {
            type: "array",
            items: {
              type: "object",
              properties: {
                insight: { type: "string" },
                sub_question: { type: "string", description: "Which sub-question this addresses" },
                confidence: { type: "number", description: "Validation confidence (0-1)" },
                supporting_passes: { type: "integer", description: "How many passes support this" },
                source_files: {
                  type: "array",
                  items: { type: "string" }
                }
              },
              required: %w[insight sub_question confidence supporting_passes],
              additionalProperties: false
            }
          },
          conflicts: {
            type: "array",
            items: {
              type: "object",
              properties: {
                topic: { type: "string" },
                pass_1_finding: { type: "string" },
                pass_2_finding: { type: "string" },
                resolution_suggestion: { type: "string" }
              },
              required: %w[topic pass_1_finding pass_2_finding],
              additionalProperties: false
            }
          },
          filtered_out: {
            type: "array",
            items: {
              type: "object",
              properties: {
                finding: { type: "string" },
                reason: { type: "string" }
              },
              required: %w[finding reason],
              additionalProperties: false
            }
          },
          summary: {
            type: "string",
            description: "Coherent narrative addressing the research goal"
          },
          detailed_sections: {
            type: "array",
            items: {
              type: "object",
              properties: {
                sub_question: { type: "string" },
                answer: { type: "string" },
                key_findings: {
                  type: "array",
                  items: { type: "string" }
                },
                confidence: { type: "number" }
              },
              required: %w[sub_question answer key_findings confidence],
              additionalProperties: false
            }
          },
          open_questions: {
            type: "array",
            items: {
              type: "object",
              properties: {
                question: { type: "string" },
                reason: { type: "string", description: "Why this remains unanswered" },
                suggested_investigation: { type: "string" }
              },
              required: %w[question reason],
              additionalProperties: false
            }
          }
        },
        required: %w[validated_insights conflicts filtered_out summary detailed_sections open_questions],
        additionalProperties: false
      }
    end

    # Synthesize findings from multiple analysis passes
    # @param findings [Array<Hash>] Findings from parallel analysis passes
    # @param goal [String] Original research goal
    # @param sub_questions [Array<Hash>] Decomposed sub-questions
    # @return [Hash] Synthesized results
    def synthesize(findings:, goal:, sub_questions:)
      prompt = build_prompt(findings, goal, sub_questions)
      context = {
        goal: goal,
        sub_question_count: sub_questions.size,
        pass_count: findings.size
      }

      execute(prompt: prompt, context: context)
    end

    # Combine pre-synthesized leaf summaries into a final synthesis
    # This is more efficient than synthesizing all raw findings at once
    # @param goal [String] Original research goal
    # @param leaf_syntheses [Array<Hash>] Pre-synthesized results from each leaf question
    # @return [Hash] Combined synthesis
    def combine_leaf_syntheses(goal:, leaf_syntheses:)
      prompt = build_combination_prompt(goal, leaf_syntheses)
      context = {
        goal: goal,
        leaf_count: leaf_syntheses.size
      }

      execute(prompt: prompt, context: context)
    end

    private

    def build_combination_prompt(goal, leaf_syntheses)
      prompt_parts = ["Research Goal: #{goal}"]

      prompt_parts << "\n## Pre-Synthesized Answers by Sub-Question:"

      leaf_syntheses.each_with_index do |synthesis, idx|
        sub_question = synthesis[:sub_question] || synthesis["sub_question"]
        summary = synthesis[:summary] || synthesis["summary"]
        confidence = synthesis[:confidence] || synthesis["confidence"] || 0.5
        key_findings = synthesis[:key_findings] || synthesis["key_findings"] || []

        prompt_parts << "\n### #{idx + 1}. #{sub_question}"
        prompt_parts << "**Summary**: #{summary}"
        prompt_parts << "**Confidence**: #{confidence}"

        if key_findings.any?
          prompt_parts << "**Key Findings**:"
          key_findings.first(5).each do |finding|
            text = finding[:finding] || finding["finding"] || finding.to_s
            prompt_parts << "- #{text}"
          end
        end

        gaps = synthesis[:gaps] || synthesis["gaps"] || []
        if gaps.any?
          prompt_parts << "**Gaps**: #{gaps.join(', ')}"
        end
      end

      prompt_parts << "\n## Instructions:"
      prompt_parts << "1. Combine the pre-synthesized answers into a unified understanding"
      prompt_parts << "2. Identify cross-cutting insights that span multiple sub-questions"
      prompt_parts << "3. Resolve any conflicts between sub-question answers"
      prompt_parts << "4. Create a coherent summary addressing the original research goal"
      prompt_parts << "5. Note remaining open questions"

      prompt_parts.join("\n")
    end

    def build_prompt(findings, goal, sub_questions)
      prompt_parts = ["Research Goal: #{goal}"]

      prompt_parts << "\n## Sub-Questions Investigated:"
      sub_questions.each_with_index do |q, idx|
        text = q[:text] || q[:question]
        prompt_parts << "#{idx + 1}. #{text}"
      end

      prompt_parts << "\n## Findings from Analysis Passes:"

      findings.each_with_index do |pass, idx|
        prompt_parts << "\n### Pass #{idx + 1}:"
        if pass.is_a?(Hash)
          prompt_parts << format_pass_findings(pass)
        else
          prompt_parts << pass.to_s
        end
      end

      prompt_parts << "\n## Instructions:"
      prompt_parts << "1. Cross-validate findings across passes (2+ confirmations = validated)"
      prompt_parts << "2. Identify conflicts between passes"
      prompt_parts << "3. Filter irrelevant findings with reasoning"
      prompt_parts << "4. Create a coherent summary addressing the goal"
      prompt_parts << "5. Organize detailed sections by sub-question"
      prompt_parts << "6. Note any open questions requiring further investigation"

      prompt_parts.join("\n")
    end

    def format_pass_findings(pass)
      if pass[:insights]
        pass[:insights].map { |i| "- #{i[:finding] || i}" }.join("\n")
      elsif pass[:findings]
        pass[:findings].map { |f| "- #{f}" }.join("\n")
      else
        pass.to_json
      end
    end
  end
end

