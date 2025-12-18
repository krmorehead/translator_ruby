# frozen_string_literal: true

module Research
  # Base class for research prompts.
  # Research prompts handle context differently - they incorporate context into
  # their prompt text via build_prompt, so format_context returns empty.
  # The context hash is used internally but not formatted separately.
  class BaseResearchPrompt < ::BasePrompt
    # Research prompts incorporate context into build_prompt, not format_context
    # @param context [Hash] The context hash (used internally, not formatted)
    # @param question [String] Ignored for research prompts
    # @return [String] Empty string - context is handled in build_prompt
    def format_context(context, question: nil)
      ""
    end
  end
end

