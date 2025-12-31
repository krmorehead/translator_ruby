# frozen_string_literal: true

module Execution
  # Enhanced prompt for executing a plan step by generating and executing tool calls.
  # This is the main execution prompt that drives step implementation.
  #
  # Extends ToolCallPrompt to enable actual tool calling with the LLM.
  #
  # @example Basic usage
  #   prompt = Execution::StepExecutionPrompt.new(
  #     step: plan_step,
  #     context: assembled_context,
  #     available_tools: [tool1, tool2],
  #     planned_sequence: [...],
  #     validation_results: [...]
  #   )
  class StepExecutionPrompt < ToolCallPrompt
    attr_reader :step, :context, :planned_sequence, :validation_results

    # @param step [Planning::Step] The step to execute
    # @param context [Hash] Assembled context from context assembly phase
    # @param available_tools [Array] Array of tool objects
    # @param planned_sequence [Array<Hash>, nil] Optional planned tool sequence
    # @param validation_results [Array<Hash>, nil] Optional validation results
    def initialize(step:, context:, available_tools: [], planned_sequence: nil, validation_results: nil)
      validate_parameters!(step, context)
      
      @step = step
      @context = context
      @planned_sequence = planned_sequence
      @validation_results = validation_results || []
      
      super(tools: available_tools)
    end

    def system_prompt
      <<~PROMPT
        You are Sisyphus, executing a plan step by making tool calls.

        Your goal is to accomplish this step's objectives by calling the available tools in a logical sequence.

        ## Execution Guidelines

        1. **Follow the Plan**: If a planned sequence was provided, follow it closely
        2. **Address Warnings**: If validation warnings were provided, handle them appropriately
        3. **Follow Step Details**: Implement exactly what the step.details specify
        4. **Test-Driven**: If this is a test file, create tests first; otherwise, run tests after changes
        5. **Verify Syntax**: After creating/modifying code files, verify syntax
        6. **Read Before Write**: Read files before modifying to understand current state
        7. **Incremental Progress**: Make changes incrementally and verify each one

        ## Best Practices

        - Use existing patterns you observed in the assembled context
        - Follow the codebase's conventions and style
        - Add appropriate error handling
        - Include helpful comments for complex logic
        - Verify your changes work before finishing

        ## Anti-Patterns to Avoid

        - Don't modify files you haven't read first
        - Don't skip testing after making changes
        - Don't ignore validation warnings
        - Don't make assumptions about file structure

        ## Tool Usage

        You have access to these tools:
        #{format_tool_descriptions}

        Make tool calls to accomplish the step. The tools will be executed and their results returned to you.

        ## Response Guidelines

        - Make multiple tool calls in sequence as needed
        - Wait for results before proceeding to dependent operations
        - If a tool fails, diagnose the issue and try to recover
        - When the step is complete, explain what you accomplished
      PROMPT
    end

    # This prompt doesn't use a fixed response schema since it's using tool calling
    def response_schema
      nil
    end

    def build_parameters(messages)
      parameters = super(messages)
      
      # Add tools for tool calling
      if @tools.any?
        parameters[:tools] = serialize_tools
      end
      
      parameters
    end

    def build_user_message
      message = []
      
      message << "## Step to Execute"
      message << ""
      message << "**Step #{@step.number}**: #{@step.title}"
      message << ""
      message << "**Intent**: #{@step.intent}"
      message << ""
      message << "**Details** (implement these exactly):"
      @step.details.each { |detail| message << "- #{detail}" }
      message << ""
      message << "**Tests/Acceptance Criteria**:"
      @step.tests.each { |test| message << "- #{test}" }
      
      if @context && !@context.empty?
        message << ""
        message << "## Assembled Context"
        message << ""
        message << format_context
      end
      
      if @planned_sequence
        message << ""
        message << "## Planned Tool Sequence"
        message << ""
        message << "You should follow this sequence:"
        @planned_sequence.each_with_index do |call, i|
          message << "#{i + 1}. **#{call[:tool]}**: #{call[:rationale]}"
        end
      end
      
      if @validation_results.any?
        message << ""
        message << "## Validation Warnings to Address"
        message << ""
        @validation_results.each do |result|
          if result[:warnings]&.any?
            result[:warnings].each { |warn| message << "- #{warn}" }
          end
        end
      end
      
      message << ""
      message << "## Your Task"
      message << ""
      message << "Execute this step by making the appropriate tool calls."
      message << "Follow the planned sequence, address any warnings, and verify your work."
      
      message.join("\n")
    end

    private

    def validate_parameters!(step, context)
      unless step.is_a?(Planning::Step)
        raise TypeError, "step must be a Planning::Step, got #{step.class}"
      end

      unless context.is_a?(Hash)
        raise ArgumentError, "context must be a Hash"
      end
    end

    def format_tool_descriptions
      if @tools.empty?
        "No tools available."
      else
        @tools.map do |tool|
          "- **#{tool.name}**: #{tool.description}"
        end.join("\n")
      end
    end

    def format_context
      return "No context available." if @context.empty?

      parts = []
      
      if @context[:files_read]
        parts << "**Files Read** (#{@context[:files_read].size}):"
        @context[:files_read].keys.take(5).each do |path|
          parts << "  - #{path}"
        end
      end
      
      if @context[:patterns_found]
        parts << "**Key Patterns Found**: #{@context[:patterns_found].take(5).join(', ')}"
      end
      
      parts.join("\n")
    end
  end
end

