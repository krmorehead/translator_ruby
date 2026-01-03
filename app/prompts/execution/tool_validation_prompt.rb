# frozen_string_literal: true

module Execution
  # Prompt that validates tool call parameters before execution.
  # Catches errors early and prevents invalid operations.
  #
  # @example Basic usage
  #   prompt = Execution::ToolValidationPrompt.new(
  #     tool_call: {
  #       tool: "write_file",
  #       params: { path: "app/models/user.rb", content: "class User..." },
  #       rationale: "Create user model"
  #     },
  #     context: {
  #       codebase_path: "/path/to/code",
  #       existing_files: ["app/models/post.rb"],
  #       current_state: {}
  #     }
  #   )
  class ToolValidationPrompt < BasePrompt
    attr_reader :tool_call, :context

    # @param tool_call [Hash] The tool call to validate (tool, params, rationale)
    # @param context [Hash] Current execution context
    def initialize(tool_call:, context:)
      validate_parameters!(tool_call, context)
      
      @tool_call = tool_call
      @context = context
      
      super()
    end

    def system_prompt
      <<~PROMPT
        You are validating a tool call before execution to catch potential errors early.

        Your goal is to check whether the tool call parameters are valid, safe, and likely to succeed.

        ## Validation Checks

        ### File Operations
        - Do target files/directories exist (when they should)?
        - Are file paths valid and safe?
        - Will the operation overwrite existing work?
        - Are file permissions likely to be correct?

        ### Parameter Types
        - Are all parameters the correct type?
        - Are values within valid ranges?
        - Are required parameters present?
        - Are there any unexpected/extra parameters?

        ### Logical Consistency
        - Does this operation make sense given the current state?
        - Are there missing prerequisites?
        - Will this achieve the stated rationale?
        - Are there better alternatives?

        ### Safety
        - Could this operation cause data loss?
        - Could this break existing functionality?
        - Are there dangerous operations (delete, overwrite)?
        - Should the user be warned?

        ## Severity Levels

        - **ok**: No issues, proceed
        - **warning**: Minor concerns, but can proceed
        - **error**: Critical issues, should not proceed

        ## Response Format

        Return a JSON object with:
        - `valid`: boolean (true if can proceed)
        - `severity`: string ("ok", "warning", or "error")
        - `warnings`: array of warning messages
        - `errors`: array of error messages
        - `suggestions`: array of improvement suggestions
        - `should_proceed`: boolean (final recommendation)
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          valid: {
            type: "boolean",
            description: "Whether the tool call is valid"
          },
          severity: {
            type: "string",
            enum: ["ok", "warning", "error"],
            description: "Severity level of any issues"
          },
          warnings: {
            type: "array",
            items: { type: "string" },
            description: "Warning messages"
          },
          errors: {
            type: "array",
            items: { type: "string" },
            description: "Error messages"
          },
          suggestions: {
            type: "array",
            items: { type: "string" },
            description: "Suggestions for improvement"
          },
          should_proceed: {
            type: "boolean",
            description: "Final recommendation whether to proceed"
          }
        },
        required: ["valid", "severity", "warnings", "errors", "suggestions", "should_proceed"],
        additionalProperties: false
      }
    end

    def build_user_message
      message = []
      
      message << "## Tool Call to Validate"
      message << ""
      message << "**Tool**: #{@tool_call[:tool]}"
      message << ""
      message << "**Parameters**:"
      @tool_call[:params].each do |key, value|
        message << "- `#{key}`: #{format_value(value)}"
      end
      message << ""
      message << "**Rationale**: #{@tool_call[:rationale]}"
      
      message << ""
      message << "## Current Context"
      message << ""
      message << "**Codebase Path**: #{@context[:codebase_path]}" if @context[:codebase_path]
      
      if @context[:existing_files]
        message << "**Existing Files**: #{@context[:existing_files].size} files"
      end
      
      if @context[:current_state]
        message << "**Current State**: #{format_state(@context[:current_state])}"
      end
      
      message << ""
      message << "## Your Task"
      message << ""
      message << "Validate this tool call thoroughly. Check for errors, potential issues, and safety concerns."
      message << "Provide clear warnings or errors if you find problems."
      
      message.join("\n")
    end

    private

    def validate_parameters!(tool_call, context)
      unless tool_call.is_a?(Hash)
        raise TypeError, "tool_call must be a Hash, got #{tool_call.class}"
      end

      unless tool_call.key?(:tool) && tool_call.key?(:params) && tool_call.key?(:rationale)
        raise ArgumentError, "tool_call must contain :tool, :params, and :rationale keys"
      end

      unless context.is_a?(Hash)
        raise ArgumentError, "context must be a Hash"
      end
    end

    def format_value(value)
      case value
      when String
        value.length > 100 ? "#{value[0..97]}..." : value.inspect
      when Array
        "Array(#{value.size})"
      when Hash
        "Hash(#{value.keys.join(', ')})"
      else
        value.inspect
      end
    end

    def format_state(state)
      return "empty" if state.empty?
      state.keys.take(3).join(", ") + (state.size > 3 ? "..." : "")
    end
  end
end


