# frozen_string_literal: true

module Planning
  # Prompt that synthesizes the structured milestone data into final project_plan.md
  # markdown content. Formats the plan according to the create-project-plan.md template.
  class PlanSynthesisPrompt < BasePlanningPrompt
    def system_prompt
      <<~PROMPT
        #{PLANNING_CONTEXT}

        ## Your Task

        Generate the complete project_plan.md content as valid markdown. You will be given
        structured milestone and step data, and you must format it into the standard project
        plan format.

        ## Project Plan Format

        ```markdown
        # Project Plan: {Project Name}

        ## Overview

        Brief description of what this project accomplishes.

        ## Goals

        - Goal 1
        - Goal 2

        ---

        ## Milestone 1 - {Milestone Title}

        Brief description of what this milestone achieves.

        ### 1.1 - {Step Title}

        **Intent**: What this step accomplishes and why.

        **Details**:
        - Specific requirement 1
        - Specific requirement 2
        - Specific requirement 3

        **Tests**:
        - Test case 1
        - Test case 2

        ---

        ### 1.2 - {Step Title}

        ...continue pattern...

        ---

        ## Milestone 2 - {Milestone Title}

        ...continue pattern...
        ```

        ## Formatting Rules

        1. Use horizontal rules (---) between steps
        2. Use horizontal rules between milestones
        3. Steps numbered as {milestone}.{step}
        4. Intent is a single paragraph
        5. Details are bullet points
        6. Tests are bullet points
        7. No implementation code anywhere
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          markdown: { type: "string" }
        },
        required: ["markdown"],
        additionalProperties: false
      }
    end

    # Synthesize the project plan content
    # @param goal [String] The project goal
    # @param project_name [String] Name of the project
    # @param milestones [Array<Hash>] Structured milestones from PlanStructurePrompt
    # @param overview [String] Brief description from research
    # @param goals_list [Array<String>] List of high-level goals
    # @return [Hash] Result with :content key containing markdown
    def synthesize_plan(goal:, project_name:, milestones:, overview:, goals_list:)
      user_prompt = build_user_prompt(goal, project_name, milestones, overview, goals_list)
      execute(prompt: user_prompt)
    end

    
    def build_user_prompt(goal, project_name, milestones, overview, goals_list)
      prompt_parts = []

      prompt_parts << "## Project Name: #{project_name}"
      prompt_parts << "## Project Goal: #{goal}"
      prompt_parts << "## Overview\n#{overview}"

      prompt_parts << "## High-Level Goals"
      goals_list.each { |g| prompt_parts << "- #{g}" }

      prompt_parts << "## Milestones and Steps (Structured Data)"
      
      milestones.each do |milestone|
        num = milestone["number"] || milestone[:number]
        title = milestone["title"] || milestone[:title]
        desc = milestone["description"] || milestone[:description]
        
        prompt_parts << "### Milestone #{num}: #{title}"
        prompt_parts << "Description: #{desc}"
        
        (milestone["steps"] || milestone[:steps] || []).each do |step|
          step_num = step["number"] || step[:number]
          step_title = step["title"] || step[:title]
          intent = step["intent"] || step[:intent]
          details = step["details"] || step[:details] || []
          tests = step["tests"] || step[:tests] || []
          
          prompt_parts << "\n#### Step #{step_num}: #{step_title}"
          prompt_parts << "Intent: #{intent}"
          prompt_parts << "Details:"
          details.each { |d| prompt_parts << "  - #{d}" }
          prompt_parts << "Tests:"
          tests.each { |t| prompt_parts << "  - #{t}" }
        end
      end

      prompt_parts << "\nGenerate the complete project_plan.md content as properly formatted markdown."

      prompt_parts.join("\n\n")
    end
  end
end
