# frozen_string_literal: true

module Actions
  # Action that wraps SkillCheckTool for skill checks
  class SkillCheckAction < BaseAction
    def execute(skill:, dc:, modifier: 0)
      tool = SkillCheckTool.new
      result = tool.execute(
        skill: skill,
        ability_modifier: modifier,
        proficiency_bonus: 0,
        mode: "normal",
        dc: dc
      )
      
      return error_result(result[:error]) unless result[:success]
      
      check_data = result[:result]
      summary = "#{skill} check: #{check_data[:total]} vs DC #{dc}"
      summary += check_data[:success] ? " - Success!" : " - Failed"
      
      success_result(check_data, summary: summary)
    end
  end
end
