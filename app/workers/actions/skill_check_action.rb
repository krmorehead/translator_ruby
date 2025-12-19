# frozen_string_literal: true

module Actions
  # Action to perform a skill check against a difficulty class (DC).
  # Rolls 1d20, adds modifier, compares to DC.
  class SkillCheckAction < BaseAction
    def execute(skill:, dc:, modifier: 0)
      dc = dc.to_i
      modifier = modifier.to_i

      roll = rand(1..20)
      total = roll + modifier
      success = total >= dc

      natural_20 = roll == 20
      natural_1 = roll == 1

      result_text = build_result_text(skill, roll, modifier, total, dc, success, natural_20, natural_1)

      success_result(
        result: result_text,
        summary: "#{skill} check #{success ? 'succeeded' : 'failed'} (#{total} vs DC #{dc})",
        findings: [{ text: result_text, source: "skill_check" }],
        metadata: {
          skill: skill,
          roll: roll,
          modifier: modifier,
          total: total,
          dc: dc,
          success: success,
          natural_20: natural_20,
          natural_1: natural_1
        }
      )
    end

    private

    def build_result_text(skill, roll, modifier, total, dc, success, natural_20, natural_1)
      parts = ["#{skill} check: d20(#{roll})"]
      parts << (modifier >= 0 ? "+#{modifier}" : modifier.to_s) if modifier != 0
      parts << "= #{total} vs DC #{dc}"

      if natural_20
        "CRITICAL SUCCESS! #{parts.join(' ')}"
      elsif natural_1
        "CRITICAL FAILURE! #{parts.join(' ')}"
      elsif success
        "SUCCESS! #{parts.join(' ')}"
      else
        "FAILURE. #{parts.join(' ')}"
      end
    end
  end
end

