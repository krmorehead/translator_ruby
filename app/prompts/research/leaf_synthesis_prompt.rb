# frozen_string_literal: true

module Research
  # Prompt that synthesizes findings for a single leaf sub-question.
  # Designed for focused, small-context synthesis during iterative research.
  # Much simpler than global SynthesisPrompt since it handles one question at a time.
  class LeafSynthesisPrompt < BaseResearchPrompt
    def system_prompt
      <<~PROMPT
        You are a research synthesis expert. Your task is to synthesize findings
        from multiple analysis passes for a SINGLE focused research question.

        ## Synthesis Process

        1. **Cross-Validation**: Identify insights that appear in 2+ analysis passes
        2. **Conflict Detection**: Note any disagreements between passes
        3. **Key Takeaways**: Extract the most important findings
        4. **Confidence Assessment**: Rate confidence based on pass agreement

        ## Cross-Validation Rules

        - An insight is VALIDATED if it appears (even with different wording) in 2+ passes
        - Preserve key technical terms from the original findings
        - Note conflicts where passes disagree
        - Include unique insights from single passes with lower confidence

        ## Output Requirements

        - Provide a focused summary that directly answers the sub-question
        - Keep the summary concise (2-4 sentences for simple questions)
        - List key findings in order of confidence
        - Note any unresolved conflicts or gaps
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          summary: {
            type: "string",
            description: "Concise answer to the sub-question (2-4 sentences)"
          },
          key_findings: {
            type: "array",
            items: {
              type: "object",
              properties: {
                finding: { type: "string" },
                confidence: { type: "number", description: "Confidence 0-1 based on pass agreement" },
                supporting_passes: { type: "integer", description: "Number of passes supporting this" },
                source_files: {
                  type: "array",
                  items: { type: "string" }
                }
              },
              required: %w[finding confidence supporting_passes],
              additionalProperties: false
            }
          },
          conflicts: {
            type: "array",
            items: {
              type: "object",
              properties: {
                topic: { type: "string" },
                description: { type: "string" }
              },
              required: %w[topic description],
              additionalProperties: false
            }
          },
          confidence: {
            type: "number",
            description: "Overall confidence in the synthesis (0-1)"
          },
          gaps: {
            type: "array",
            items: { type: "string" },
            description: "Areas that could not be fully answered"
          }
        },
        required: %w[summary key_findings conflicts confidence gaps],
        additionalProperties: false
      }
    end

    # Synthesize findings for a single leaf sub-question
    # @param sub_question [String] The specific sub-question being answered
    # @param findings [Array<Hash>] Findings from analysis passes for this question
    # @return [Hash] Synthesized result with summary and key findings
    def synthesize_leaf(sub_question:, findings:)
      prompt = build_prompt(sub_question, findings)
      context = {
        sub_question: sub_question,
        finding_count: findings.size
      }

      execute(prompt: prompt, context: context)
    end

    private

    def build_prompt(sub_question, findings)
      prompt_parts = ["Sub-Question: #{sub_question}"]

      prompt_parts << "\n## Findings from Analysis Passes:"

      # Group findings by pass number
      by_pass = findings.group_by { |f| f[:pass_number] || 1 }

      by_pass.each do |pass_num, pass_findings|
        prompt_parts << "\n### Pass #{pass_num}:"
        pass_findings.each do |finding|
          text = finding[:text] || finding[:finding] || finding.to_s
          file = finding[:file_path] ? " (#{finding[:file_path]})" : ""
          prompt_parts << "- #{text}#{file}"
        end
      end

      prompt_parts << "\n## Instructions:"
      prompt_parts << "1. Cross-validate findings across passes"
      prompt_parts << "2. Create a focused summary answering the sub-question"
      prompt_parts << "3. List key findings with confidence levels"
      prompt_parts << "4. Note any conflicts or gaps"

      prompt_parts.join("\n")
    end
  end
end

