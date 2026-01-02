# frozen_string_literal: true

# Prompt for generating random D&D starting scenarios
class DndScenarioGenerationPrompt < BasePrompt
  def model
    ENV.fetch("DND_SCENARIO_MODEL", ENV.fetch("FAST_MODEL", GenericLlmClient.model_for(:general_llm)))
  end

  def system_prompt
    <<~PROMPT
      You are a creative D&D Dungeon Master creating starting scenarios for new adventures.
      Generate diverse, interesting scenarios with a clear goal, vivid scene, and hook.
    PROMPT
  end

  def user_prompt(prompt:)
    <<~PROMPT
      Generate a random D&D starting scenario. Include:
      - A compelling goal/objective for the party
      - A vivid opening scene description
      - A main quest or hook to get started
      
      Make it creative and varied - fantasy taverns, dungeon entrances, mysterious forests, 
      bustling cities, ancient ruins, etc. Keep it concise but evocative.
    PROMPT
  end

  def response_schema
    {
      type: "object",
      properties: {
        goal: { 
          type: "string",
          description: "The party's goal or objective"
        },
        scene: { 
          type: "string",
          description: "Opening scene description"
        },
        quest: { 
          type: "string",
          description: "The main quest or hook"
        }
      },
      required: ["goal", "scene", "quest"],
      additionalProperties: false
    }
  end
end

