# frozen_string_literal: true

module Actions
  # Action to roll dice for checks, damage, or random outcomes.
  # Supports standard dice notation (2d6+3, 1d20, etc.)
  class RollDiceAction < BaseAction
    DICE_PATTERN = /^(\d+)?d(\d+)([+-]\d+)?$/i

    def execute(dice:, reason: "roll")
      match = dice.to_s.strip.match(DICE_PATTERN)
      return failure_result(error: "Invalid dice notation: #{dice}. Use format like 2d6+3") unless match

      count = (match[1] || "1").to_i
      sides = match[2].to_i
      modifier = (match[3] || "0").to_i

      rolls = count.times.map { rand(1..sides) }
      total = rolls.sum + modifier

      result_text = if modifier != 0
        "#{dice}: [#{rolls.join(', ')}] #{modifier.positive? ? '+' : ''}#{modifier} = #{total}"
      else
        "#{dice}: [#{rolls.join(', ')}] = #{total}"
      end

      success_result(
        result: result_text,
        summary: "Rolled #{total} for #{reason}",
        findings: [{ text: "#{reason}: rolled #{total}", source: "dice" }],
        metadata: {
          dice: dice,
          rolls: rolls,
          modifier: modifier,
          total: total,
          reason: reason
        }
      )
    end
  end
end

