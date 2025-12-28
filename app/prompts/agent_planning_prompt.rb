# frozen_string_literal: true

# Prompt for the agent planner to select the next action.
# Given the current state, goal, and available actions, the planner
# decides what action to take next (or composes a custom workflow).
# Uses general_llm because it may compose multi-step custom workflows.
class AgentPlanningPrompt < BasePrompt
  attr_reader :actions

  # @param actions [Array<Hash>] Available action definitions
  #   Each action should have :name, :description, and :parameters
  def initialize(actions: [])
    super()
    @actions = actions
  end

  def system_prompt
    <<~PROMPT
      You are an intelligent agent planner. Your role is to analyze the current state
      and decide what action to take next to achieve the goal.

      ## Available Actions

      #{format_actions}

      ## Special Actions

      - **stop**: Use this when the goal has been achieved or no further progress can be made.
      - **custom_workflow**: Use this to compose multiple actions in sequence when a single
        action isn't sufficient. Define steps as an array of actions.

      ## Decision Guidelines

      1. **Assess Progress**: Review what has been discovered so far and what's still unknown.
      2. **Choose Wisely**: Select the action most likely to make progress toward the goal.
      3. **Avoid Loops**: Don't repeat actions that have already been tried with the same inputs.
      4. **Be Specific**: Provide concrete arguments for the action based on current findings.
      5. **Know When to Stop**: If you have enough information to answer the goal, use "stop".

      ## Response Format

      Return a JSON object with:
      - action: The action name (or "stop" or "custom_workflow")
      - arguments: Object with action-specific arguments
      - rationale: Brief explanation of why this action was chosen
      - expected_outcome: What you expect to learn from this action

      For custom workflows, include:
      - steps: Array of {action, arguments} objects to execute in sequence
    PROMPT
  end

  def response_schema
    action_names = @actions.map { |a| a[:name] } + ["stop", "custom_workflow"]

    {
      type: "object",
      properties: {
        action: {
          type: "string",
          enum: action_names,
          description: "The action to execute"
        },
        arguments: {
          type: "object",
          additionalProperties: true,
          description: "Arguments for the action"
        },
        rationale: {
          type: "string",
          description: "Why this action was chosen"
        },
        expected_outcome: {
          type: "string",
          description: "What you expect to learn"
        },
        steps: {
          type: "array",
          items: {
            type: "object",
            properties: {
              action: { type: "string" },
              arguments: { type: "object", additionalProperties: true }
            },
            required: ["action"]
          },
          description: "Steps for custom_workflow action"
        }
      },
      required: ["action", "rationale"],
      additionalProperties: false
    }
  end

  def format_context(context, question: nil)
    context.format_for_prompt(question)
  end

  private

  def format_actions
    return "No actions available" if @actions.empty?

    @actions.map do |action|
      params = format_parameters(action[:parameters])
      "- **#{action[:name]}**: #{action[:description]}#{params}"
    end.join("\n")
  end

  def format_parameters(params)
    return "" if params.empty?

    param_list = params.map do |name, config|
      required = config[:required] ? " (required)" : ""
      "#{name}: #{config[:description] || config[:type]}#{required}"
    end.join(", ")

    "\n  Parameters: #{param_list}"
  end
end
