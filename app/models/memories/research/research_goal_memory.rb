# frozen_string_literal: true

module Memories
  module Research
    # Memory for tracking the main research objective.
    # Inherits goal tracking capabilities from GoalBasedMemory.
    class ResearchGoalMemory < Memories::GoalBasedMemory
      SECTION = ResearchMemoryKinds::RESEARCH_GOAL

      def self.section_name
        SECTION
      end

      # Research goal is highest priority
      def self.weight
        1.0
      end

      # Summarize the research goal
      def self.summarize(store:)
        entries = store.get_section(section_name) || []
        goal = entries.first

        if goal
          text = goal[:text] || goal["text"]
          status = goal[:status] || goal["status"] || "active"
          {
            section: section_name,
            summary: "Research goal: #{text} (#{status})",
            goal: text,
            status: status
          }
        else
          {
            section: section_name,
            summary: "No research goal set",
            goal: nil,
            status: nil
          }
        end
      end
    end
  end
end

