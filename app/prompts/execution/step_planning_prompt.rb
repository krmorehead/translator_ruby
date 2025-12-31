# frozen_string_literal: true

module Execution
  # Prompt that plans the sequence of tool calls needed to accomplish a step.
  # This enables validation before execution and improves execution quality.
  #
  # @example Basic usage
  #   prompt = Execution::StepPlanningPrompt.new(
  #     step: plan_step,
  #     available_tools: [tool1.schema, tool2.schema],
  #     assembled_context: {
  #       files_read: {"app/models/user.rb" => "class User..."},
  #       patterns_found: ["class User", "has_secure_password"]
  #     }
  #   )
  #   
  #   result = prompt.execute(
  #     prompt: "Plan the tool calls",
  #     context: {}
  #   )
  class StepPlanningPrompt < BasePrompt
    attr_reader :step, :available_tools, :assembled_context

    # @param step [Planning::Step] The step to plan
    # @param available_tools [Array<Hash>] Array of tool schemas
    # @param assembled_context [Hash] Context gathered from context assembly
    def initialize(step:, available_tools:, assembled_context:)
      validate_parameters!(step, available_tools, assembled_context)
      
      @step = step
      @available_tools = Array(available_tools)
      @assembled_context = assembled_context
      
      super()
    end

    def system_prompt
      <<~PROMPT
        You are planning the sequence of tool calls needed to accomplish a plan step.

        Your goal is to create a detailed, ordered plan of tool calls that will successfully
        complete this step while following best practices.

        ## Planning Guidelines

        - **Read Before Write**: Always read files before modifying them
        - **Validate Syntax**: Use syntax checkers after creating/modifying code
        - **Test After Changes**: Run tests to verify functionality
        - **Follow Patterns**: Use existing code patterns you observed in the context
        - **Be Explicit**: Include all parameters with specific values
        - **Handle Errors**: Plan for potential failures

        ## Tool Call Sequence Best Practices

        1. **Gather Additional Context** (if needed via read_file)
        2. **Create/Modify Files** (via write_file)
        3. **Verify Syntax** (via bash with syntax checkers)
        4. **Run Tests** (via bash with test commands)
        5. **Verify Results** (via read_file or grep)

        ## Available Tools

        #{format_tools}

        ## Response Format

        Return a JSON object with:
        - `tool_sequence`: Array of planned tool calls, each with:
          - `tool`: Tool name
          - `params`: Parameters for the tool (as an object)
          - `rationale`: Why this tool call is needed
        - `expected_outcome`: What you expect to achieve with this sequence
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          tool_sequence: {
            type: "array",
            items: {
              type: "object",
              properties: {
                tool: {
                  type: "string",
                  description: "Name of the tool to use"
                },
                params: {
                  type: "object",
                  description: "Parameters for the tool call"
                },
                rationale: {
                  type: "string",
                  description: "Why this tool call is needed"
                }
              },
              required: ["tool", "params", "rationale"],
              additionalProperties: false
            }
          },
          expected_outcome: {
            type: "string",
            description: "What you expect to achieve"
          }
        },
        required: ["tool_sequence", "expected_outcome"],
        additionalProperties: false
      }
    end

    def build_user_message
      message = []
      
      message << "## Step to Execute"
      message << ""
      message << "**Step #{@step.number}**: #{@step.title}"
      message << ""
      message << "**Intent**: #{@step.intent}"
      message << ""
      message << "**Details**:"
      @step.details.each { |detail| message << "- #{detail}" }
      message << ""
      message << "**Tests/Acceptance Criteria**:"
      @step.tests.each { |test| message << "- #{test}" }
      
      message << ""
      message << "## Assembled Context"
      message << ""
      message << format_context
      
      message << ""
      message << "## Your Task"
      message << ""
      message << "Plan the complete sequence of tool calls needed to accomplish this step."
      message << "Be thorough and follow best practices (read before write, test after changes)."
      
      message.join("\n")
    end

    private

    def validate_parameters!(step, available_tools, assembled_context)
      unless step.is_a?(Planning::Step)
        raise TypeError, "step must be a Planning::Step, got #{step.class}"
      end

      unless available_tools.is_a?(Array)
        raise ArgumentError, "available_tools must be an Array"
      end

      unless assembled_context.is_a?(Hash)
        raise ArgumentError, "assembled_context must be a Hash"
      end
    end

    def format_tools
      if @available_tools.empty?
        "No tools available."
      else
        @available_tools.map do |tool|
          "- **#{tool[:name] || tool['name']}**: #{tool[:description] || tool['description']}"
        end.join("\n")
      end
    end

    def format_context
      return "No context assembled." if @assembled_context.empty?

      parts = []
      
      if @assembled_context[:files_read]
        parts << "**Files Read**: #{@assembled_context[:files_read].keys.join(', ')}"
      end
      
      if @assembled_context[:patterns_found]
        parts << "**Patterns Found**: #{@assembled_context[:patterns_found].join(', ')}"
      end
      
      if @assembled_context[:directories_explored]
        parts << "**Directories Explored**: #{@assembled_context[:directories_explored].join(', ')}"
      end
      
      parts.join("\n")
    end
  end
end

