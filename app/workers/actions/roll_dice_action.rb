# frozen_string_literal: true

module Actions
  # Action that wraps DiceRollTool for dice rolling
  class RollDiceAction < BaseAction
    def execute(dice:, reason:)
      tool = DiceRollTool.new
      result = tool.execute(dice: dice, modifier: 0, mode: "normal")
      
      return error_result(result[:error]) unless result[:success]
      
      roll_data = result[:result]
      summary = "Rolled #{dice}: #{roll_data[:total]}"
      summary += " (#{roll_data[:rolls].join(', ')})" if roll_data[:rolls].size > 1
      summary += " - #{reason}" if reason.present?
      
      success_result(roll_data, summary: summary)
    end
  end
end
