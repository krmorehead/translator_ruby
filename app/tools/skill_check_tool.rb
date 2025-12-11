# frozen_string_literal: true


# Tool for performing d20-based skill checks using DiceRollTool.
class SkillCheckTool < BaseTool
  NAME = "skill_check".freeze

  def initialize(sandbox_path: nil, rng: nil)
    super(sandbox_path: sandbox_path)
    @rng = rng
  end

  def self.name_identifier
    NAME
  end

  def self.description
    "Perform a d20 skill check with ability and proficiency modifiers."
  end

  def self.parameters_schema
    {
      type: "object",
      properties: {
        skill: { type: "string", description: "Skill name" },
        ability_modifier: { type: "integer", description: "Ability modifier", default: 0 },
        proficiency_bonus: { type: "integer", description: "Proficiency bonus", default: 0 },
        mode: {
          type: "string",
          description: "Roll mode: normal, advantage, or disadvantage",
          enum: %w[normal advantage disadvantage],
          default: "normal"
        },
        dc: { type: "integer", description: "Difficulty class to check success" }
      },
      required: [ "skill", "ability_modifier" ],
      additionalProperties: false
    }
  end

  def execute(skill:, ability_modifier:, proficiency_bonus: 0, mode: "normal", dc: nil)
    mode ||= "normal"
    unless %w[normal advantage disadvantage].include?(mode)
      return error_result("Invalid mode. Use normal, advantage, or disadvantage")
    end
    dice_tool = DiceRollTool.new(rng: @rng)
    dice_result = dice_tool.execute(dice: "d20", modifier: 0, mode: mode)
    return dice_result unless dice_result[:success]

    roll_info = dice_result[:result]
    total = roll_info[:total] + ability_modifier.to_i + proficiency_bonus.to_i
    success = dc.nil? ? nil : total >= dc.to_i

    success_result({
      skill: skill,
      mode: mode,
      dice: roll_info,
      ability_modifier: ability_modifier.to_i,
      proficiency_bonus: proficiency_bonus.to_i,
      total: total,
      dc: dc,
      success: success
    })
  rescue => e
    error_result("Error performing skill check: #{e.message}")
  end
end

# Register with ToolCallService
ToolCallService.register_tool(SkillCheckTool)
