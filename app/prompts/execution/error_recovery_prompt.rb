# frozen_string_literal: true

module Execution
  # Prompt that diagnoses failures and suggests recovery strategies.
  # Enhanced with common error patterns and previous successful recoveries.
  #
  # @example Basic usage
  #   prompt = Execution::ErrorRecoveryPrompt.new(
  #     step: plan_step,
  #     error: error_object,
  #     step_result: partial_result,
  #     previous_attempts: [
  #       { attempt_number: 1, error: "Syntax error", actions_taken: [...] }
  #     ],
  #     recovery_patterns: {
  #       "LoadError" => "Check Gemfile for missing dependencies",
  #       "SyntaxError" => "Run syntax checker"
  #     }
  #   )
  class ErrorRecoveryPrompt < BasePrompt
    attr_reader :step, :error, :step_result, :previous_attempts, :recovery_patterns

    # @param step [Planning::Step] The step that failed
    # @param error [StandardError, String] The error that occurred
    # @param step_result [Hash] Partial execution result
    # @param previous_attempts [Array<Hash>] Previous recovery attempts
    # @param recovery_patterns [Hash] Common error patterns and solutions
    def initialize(step:, error:, step_result:, previous_attempts: [], recovery_patterns: {})
      validate_parameters!(step, step_result)
      
      @step = step
      @error = error
      @step_result = step_result
      @previous_attempts = Array(previous_attempts)
      @recovery_patterns = recovery_patterns || {}
      
      super()
    end

    def system_prompt
      <<~PROMPT
        You are diagnosing a step execution failure and planning recovery.

        Your goal is to identify the root cause and suggest specific actions to recover and retry.

        ## Diagnosis Process

        1. **Understand the Error**: What specifically failed and why?
        2. **Check Error Patterns**: Does this match any known error patterns?
        3. **Review Previous Attempts**: What was already tried? (Don't repeat failures)
        4. **Identify Root Cause**: What is the underlying issue?
        5. **Plan Recovery**: What specific actions will fix it?

        ## Common Error Patterns

        #{format_recovery_patterns}

        ## Recovery Guidelines

        - **Be Specific**: Provide exact tool calls to fix the issue
        - **Avoid Repetition**: Don't suggest what was already tried
        - **Address Root Cause**: Fix the underlying problem, not symptoms
        - **Consider Alternatives**: If direct fix won't work, suggest different approach
        - **Limit Retries**: After 2-3 attempts, suggest alternative approach or skip

        ## Recovery Actions

        Suggest specific tool calls that will resolve the error. For example:
        - Add missing dependency to Gemfile
        - Fix syntax error in specific file
        - Create missing directory
        - Update file permissions
        - Install missing package

        ## Response Format

        Return a JSON object with:
        - `diagnosis`: string (what went wrong)
        - `error_pattern`: string (known error pattern if matched)
        - `root_cause`: string (underlying issue)
        - `recovery_actions`: array of objects with {tool, params, rationale}
        - `should_retry`: boolean (whether retry is worth attempting)
        - `confidence`: number (0.0 to 1.0, confidence in this diagnosis)
        - `alternative_approach`: string or null (alternative if recovery unlikely to work)
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          diagnosis: {
            type: "string",
            description: "What went wrong"
          },
          error_pattern: {
            type: "string",
            description: "Known error pattern if matched"
          },
          root_cause: {
            type: "string",
            description: "Underlying issue causing the failure"
          },
          recovery_actions: {
            type: "array",
            items: {
              type: "object",
              properties: {
                tool: { type: "string" },
                params: { type: "object" },
                rationale: { type: "string" }
              },
              required: ["tool", "params", "rationale"],
              additionalProperties: false
            },
            description: "Specific tool calls to fix the issue"
          },
          should_retry: {
            type: "boolean",
            description: "Whether retry is worth attempting"
          },
          confidence: {
            type: "number",
            minimum: 0.0,
            maximum: 1.0,
            description: "Confidence in this diagnosis"
          },
          alternative_approach: {
            type: ["string", "null"],
            description: "Alternative approach if recovery unlikely"
          }
        },
        required: ["diagnosis", "error_pattern", "root_cause", "recovery_actions",
                   "should_retry", "confidence", "alternative_approach"],
        additionalProperties: false
      }
    end

    def build_user_message
      message = []
      
      message << "## Step That Failed"
      message << ""
      message << "**Step #{@step.number}**: #{@step.title}"
      message << ""
      message << "**Intent**: #{@step.intent}"
      message << ""
      message << "**Details**:"
      @step.details.each { |detail| message << "- #{detail}" }
      
      message << ""
      message << "## Error Information"
      message << ""
      
      if @error.is_a?(StandardError)
        message << "**Error Type**: #{@error.class.name}"
        message << "**Error Message**: #{@error.message}"
        if @error.backtrace
          message << ""
          message << "**Stack Trace** (first 5 lines):"
          @error.backtrace.take(5).each { |line| message << "  #{line}" }
        end
      else
        message << "**Error**: #{@error}"
      end
      
      if @step_result[:actions_taken]&.any?
        message << ""
        message << "## Partial Execution"
        message << ""
        message << "**Actions Taken Before Failure**: #{@step_result[:actions_taken].size}"
        @step_result[:actions_taken].each do |action|
          message << "  - #{action[:tool] || action['tool']}: #{action[:rationale] || action['rationale']}"
        end
      end
      
      if @previous_attempts.any?
        message << ""
        message << "## Previous Recovery Attempts"
        message << ""
        message << "**Important**: Don't repeat these failed attempts!"
        message << ""
        @previous_attempts.each do |attempt|
          message << "**Attempt #{attempt[:attempt_number]}**:"
          message << "  Error: #{attempt[:error]}"
          if attempt[:actions_taken]
            message << "  Actions tried: #{attempt[:actions_taken].map { |a| a[:tool] }.join(', ')}"
          end
        end
      end
      
      message << ""
      message << "## Your Task"
      message << ""
      message << "Diagnose this failure and provide specific recovery actions."
      message << "Be careful not to repeat previous failed attempts."
      if @previous_attempts.size >= 2
        message << ""
        message << "⚠️  This is attempt #{@previous_attempts.size + 1}. Consider alternative approach if direct fix unlikely."
      end
      
      message.join("\n")
    end

    private

    def validate_parameters!(step, step_result)
      unless step.is_a?(Planning::Step)
        raise TypeError, "step must be a Planning::Step, got #{step.class}"
      end

      unless step_result.is_a?(Hash)
        raise TypeError, "step_result must be a Hash"
      end
    end

    def format_recovery_patterns
      if @recovery_patterns.empty?
        "No specific patterns provided."
      else
        @recovery_patterns.map do |pattern, solution|
          "- **#{pattern}**: #{solution}"
        end.join("\n")
      end
    end
  end
end

