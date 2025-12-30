# frozen_string_literal: true

module Planning
  # Prompt that generates the milestone and step structure for a project plan.
  # Takes the goal and research findings and outputs a structured breakdown.
  class PlanStructurePrompt < BasePlanningPrompt
    def system_prompt
      <<~PROMPT
        #{PLANNING_CONTEXT}

        ## Your Task

        Given a project goal and research context about the codebase, generate a structured
        breakdown of milestones and steps to accomplish the goal.

        ## Guidelines

        1. **Analyze the goal** to understand what needs to be built
        2. **Consider existing code** - leverage what's already there
        3. **Break into milestones** - logical groupings of 3-7 steps each
        4. **Define atomic steps** - each completable in one focused session
        5. **Specify tests** - every step must have test requirements

        ## Milestone Guidelines
        - Action-oriented titles (e.g., "Build the API Layer")
        - Brief description of what the milestone achieves
        - Should be demonstrable when complete

        ## Step Guidelines
        - Small and focused
        - Intent describes WHAT and WHY, not HOW
        - Details are specific but code-free
        - Tests cover happy path and edge cases

        ## Response Format

        Return a JSON object with this structure:
        {
          "milestones": [
            {
              "number": 1,
              "title": "Milestone title",
              "description": "What this milestone achieves",
              "steps": [
                {
                  "number": "1.1",
                  "title": "Step title",
                  "intent": "What this step accomplishes and why",
                  "details": [
                    "Specific requirement 1",
                    "Specific requirement 2"
                  ],
                  "tests": [
                    "Test case 1",
                    "Test case 2"
                  ]
                }
              ]
            }
          ]
        }
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          milestones: {
            type: "array",
            items: {
              type: "object",
              properties: {
                number: { type: "integer" },
                title: { type: "string" },
                description: { type: "string" },
                steps: {
                  type: "array",
                  items: {
                    type: "object",
                    properties: {
                      number: { type: "string" },
                      title: { type: "string" },
                      intent: { type: "string" },
                      details: { type: "array", items: { type: "string" } },
                      tests: { type: "array", items: { type: "string" } }
                    },
                    required: %w[number title intent details tests],
                    additionalProperties: false
                  }
                }
              },
              required: %w[number title description steps],
              additionalProperties: false
            }
          }
        },
        required: ["milestones"],
        additionalProperties: false
      }
    end

    # Generate the milestone/step structure
    # @param goal [String] The project goal
    # @param research_context [String] Formatted research findings
    # @param existing_files [Array<Hash>] List of existing relevant files
    # @param constraints [String, nil] Any constraints on the plan
    # @return [Hash] Result with :content key containing milestones
    def generate_structure(goal:, research_context:, existing_files: [], constraints: nil)
      user_prompt = build_user_prompt(goal, research_context, existing_files, constraints)
      execute(prompt: user_prompt)
    end

    
    def build_user_prompt(goal, research_context, existing_files, constraints)
      prompt_parts = []

      prompt_parts << "## Project Goal\n#{goal}"

      if research_context.present?
        prompt_parts << "## Codebase Research\n#{research_context}"
      end

      if existing_files.any?
        prompt_parts << "## Existing Relevant Files"
        existing_files.each do |file|
          path = file[:path] || file["path"]
          desc = file[:description] || file["description"]
          prompt_parts << "- `#{path}`: #{desc}"
        end
      end

      if constraints.present?
        prompt_parts << "## Constraints\n#{constraints}"
      end

      prompt_parts << "\nGenerate a structured project plan with milestones and steps to accomplish this goal."

      prompt_parts.join("\n\n")
    end
  end
end
