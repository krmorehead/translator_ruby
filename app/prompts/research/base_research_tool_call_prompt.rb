# frozen_string_literal: true

module Research
  # Base class for simpler research prompts that use the tool_calling LLM.
  # Use this for structured tasks like relevance scoring, topic decomposition,
  # and leaf synthesis that don't require deep reasoning.
  #
  # For complex analysis (code understanding, documentation, multi-source synthesis),
  # use BaseResearchPrompt which uses the general_llm.
  class BaseResearchToolCallPrompt < ::ToolCallPrompt
    # Research prompts incorporate context into build_prompt, not format_context
    # @param context [Hash] The context hash (used internally, not formatted)
    # @param question [String] Ignored for research prompts
    # @return [String] Empty string - context is handled in build_prompt
    def format_context(context, question: nil)
      ""
    end
  end
end

