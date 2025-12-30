# frozen_string_literal: true

module Actions
  # Action to synthesize current findings into a partial answer.
  # Useful for checkpointing progress and providing intermediate summaries.
  class SynthesizePartialAction < BaseAction
    class << self
      def description
        "Synthesize current findings into a partial answer or summary"
      end

      def parameters
        {
          focus: {
            type: :string,
            required: false,
            description: "Specific aspect to focus the synthesis on"
          },
          include_unknowns: {
            type: :boolean,
            required: false,
            description: "Whether to include unknown aspects (default: true)"
          }
        }
      end

      def category
        :synthesis
      end
    end

    # Execute the partial synthesis
    # @param focus [String] Specific focus area
    # @param include_unknowns [Boolean] Include unknown aspects
    # @return [Hash] Synthesis results
    def execute(focus: nil, include_unknowns: true)
      findings = gather_findings(focus)

      if findings.empty?
        return success_result(
          summary: "No findings to synthesize yet",
          findings_count: 0,
          synthesis: nil
        )
      end

      # Synthesize using LLM
      synthesis = llm_synthesize(findings, focus, include_unknowns)

      # Record the synthesis as a finding
      record_finding(
        text: synthesis[:summary],
        source: "partial_synthesis",
        confidence: synthesis[:confidence],
        metadata: { focus: focus, findings_count: findings.size }
      )

      success_result(
        summary: synthesis[:summary],
        key_points: synthesis[:key_points],
        unknowns: include_unknowns ? synthesis[:unknowns] : [],
        confidence: synthesis[:confidence],
        findings_used: findings.size,
        findings: [{ text: synthesis[:summary], source: "partial_synthesis" }]
      )
    end

    
    def gather_findings(focus)
      findings = memory_store.get_section(:findings)

      if focus.present?
        # Filter to relevant findings
        focus_lower = focus.downcase
        findings = findings.select do |f|
          f[:text].downcase.include?(focus_lower)
        end
      end

      findings
    end

    def llm_synthesize(findings, focus, include_unknowns)
      prompt = Research::LeafSynthesisPrompt.new

      context = build_synthesis_context(findings)
      synthesis_prompt = build_synthesis_prompt(focus, include_unknowns)

      result = prompt.execute(prompt: synthesis_prompt, context: context)
      response = result[:content]

      {
        summary: response[:summary] || summarize_findings(findings),
        key_points: response[:key_points] || extract_key_points(findings),
        unknowns: response[:unknowns] || [],
        confidence: response[:confidence] || 0.7
      }
    end

    def build_synthesis_context(findings)
      context = Contexts::BaseContext.new

      Array(findings).each do |finding|
        content_text = finding.is_a?(Hash) ? (finding[:text] || finding.to_s) : finding.to_s
        source = finding.is_a?(Hash) ? (finding[:source] || "finding") : "finding"
        context.add(
          content: content_text,
          topics: ["finding", source].compact,
          source: source
        )
      end

      context
    end

    def build_synthesis_prompt(focus, include_unknowns)
      parts = ["Synthesize the following findings related to: #{goal}"]
      parts << "Focus specifically on: #{focus}" if focus.present?
      parts << "Identify what remains unknown or unclear." if include_unknowns
      parts.join("\n")
    end

    def summarize_findings(findings)
      return "No findings available" if findings.empty?

      # Group findings by source
      by_source = findings.group_by { |f| f[:source] || "unknown" }

      summaries = by_source.map do |source, source_findings|
        texts = source_findings.map { |f| f[:text] }.compact
        "From #{source}: #{texts.first(3).join('; ')}"
      end

      summaries.join("\n\n")
    end

    def extract_key_points(findings)
      # Extract unique key statements
      findings.map { |f| f[:text] }
              .compact
              .uniq
              .first(10)
    end
  end
end
