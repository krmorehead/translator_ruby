# frozen_string_literal: true

# Prompt for the D&D agent to select the next action based on player intent.
# Uses a tight context format optimized for quick decision making.
class DndPlanningPrompt < ToolCallPrompt
  def initialize(actions:)
    super()
    @actions = actions
  end

  def system_prompt
    <<~PROMPT
      You are a D&D game master assistant that selects the best action to fulfill the player's intent.
      
      Given the player's message and current scene context, select ONE action to execute.
      If the player's intent is already satisfied or requires no action, respond with action: "narrate".
      If the message is purely conversational, respond with action: "narrate".
      
      Available actions:
      #{format_actions}
      
      Be decisive. Pick the single most appropriate action for the player's intent.
      For complex requests, actions can be chained - just pick the FIRST action needed.
    PROMPT
  end

  def response_schema
    action_names = @actions.map { |a| a[:name].to_s } + ["narrate", "stop"]

    {
      type: "object",
      properties: {
        action: { type: "string", enum: action_names },
        arguments: { type: "object", additionalProperties: true },
        rationale: { type: "string" },
        expected_outcome: { type: "string" }
      },
      required: %w[action rationale],
      additionalProperties: false
    }
  end

  def format_context(context, question: nil)
    # Use brief format for tight, fast context
    context.format_for_prompt(question || "", format: :brief)
  end

  private

  def format_actions
    @actions.map do |action|
      params = action[:parameters]&.map { |k, v| "#{k}: #{v}" }&.join(", ") || "none"
      "- #{action[:name]}: #{action[:description]} (params: #{params})"
    end.join("\n")
  end
end

