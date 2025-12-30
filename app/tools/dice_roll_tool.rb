# frozen_string_literal: true

# Tool for rolling dice with support for advantage/disadvantage and modifiers.
class DiceRollTool < BaseTool
  MAX_DICE = 20
  MAX_SIDES = 1000
  NAME = "dice_roll".freeze

  def initialize(rng: nil)
    super()
    @rng = rng || Random.new
  end

  def self.name_identifier
    NAME
  end

  def self.description
    "Roll dice (e.g., d20, 2d6) with optional modifier and advantage/disadvantage."
  end

  def self.parameters_schema
    {
      type: "object",
      properties: {
        dice: { type: "string", description: "Dice expression like d20 or 2d6" },
        modifier: { type: "integer", description: "Modifier to add to total", default: 0 },
        mode: {
          type: "string",
          description: "Roll mode: normal, advantage, or disadvantage",
          enum: %w[normal advantage disadvantage],
          default: "normal"
        }
      },
      required: [ "dice" ],
      additionalProperties: false
    }
  end

  def execute(dice:, modifier: 0, mode: "normal")
    mode = normalize_mode(mode)
    modifier = modifier || 0
    parsed = parse_dice(dice)
    return error_result(parsed[:error]) if parsed[:error]

    count = parsed[:count]
    sides = parsed[:sides]
    mode = mode || "normal"

    if %w[advantage disadvantage].include?(mode)
      unless count == 1 && sides == 20
        return error_result("Advantage/disadvantage only supported for a single d20")
      end
      rolls = [ roll_die(sides), roll_die(sides) ]
      kept = mode == "advantage" ? rolls.max : rolls.min
      total = kept + modifier.to_i
      return success_result({
        mode: mode,
        dice: dice,
        rolls: rolls,
        kept: kept,
        modifier: modifier.to_i,
        total: total
      })
    end

    rolls = Array.new(count) { roll_die(sides) }
    total = rolls.sum + modifier.to_i

    success_result({
      mode: mode,
      dice: dice,
      rolls: rolls,
      modifier: modifier.to_i,
      total: total
    })
  rescue => e
    error_result("Error rolling dice: #{e.message}")
  end

  
  def parse_dice(dice)
    match = /^([0-9]+)?d([0-9]+)$/i.match(dice.to_s.strip)
    return { error: "Invalid dice format. Use NdM like d20 or 2d6" } unless match

    count = (match[1] || "1").to_i
    sides = match[2].to_i

    return { error: "Dice count must be between 1 and #{MAX_DICE}" } if count < 1 || count > MAX_DICE
    return { error: "Dice sides must be between 2 and #{MAX_SIDES}" } if sides < 2 || sides > MAX_SIDES

    { count: count, sides: sides }
  end

  def roll_die(sides)
    (@rng.random_number(sides) + 1)
  end

  def normalize_mode(mode)
    return "advantage" if mode.to_s == "advantage" || mode == true && mode != false && mode != nil
    return "disadvantage" if mode.to_s == "disadvantage"
    "normal"
  end
end

# Register with ToolCallService
ToolCallService.register_tool(DiceRollTool)
