# frozen_string_literal: true

module Planning
  # Prompt that generates the file_references.md content.
  # Analyzes research findings to identify existing files and planned new files.
  class FileReferencesPrompt < BasePlanningPrompt
    def system_prompt
      <<~PROMPT
        #{PLANNING_CONTEXT}

        ## Your Task

        Generate the content for a file_references.md document that catalogs all files
        relevant to the project - both existing files that will be modified/referenced
        and new files that will be created.

        ## File References Format

        The output must be valid markdown with this structure:

        ```markdown
        # File References: {Project Name}

        ## Existing Files

        | File Path | Description | Relevance |
        |-----------|-------------|-----------|
        | `path/to/file.rb` | Brief description | How it relates to project |

        ## Planned Files

        | File Path | Description | Created In |
        |-----------|-------------|------------|
        | `path/to/new_file.rb` | What this file will do | Step reference |

        ## Document Tree

        ### Before

        project/
        ├── existing/
        │   └── file.rb
        └── other/
            └── existing.rb

        ### Added

        project/
        ├── new/
        │   └── new_file.rb
        └── tests/
            └── new_test.rb
        ```

        ## Guidelines

        1. List ALL existing files that will be read, modified, or referenced
        2. List ALL new files that will be created (including test files)
        3. Reference step numbers where planned files are created
        4. Keep descriptions concise (one line)
        5. Before tree shows existing relevant structure
        6. Added tree shows ONLY new files/directories
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

    # Generate file references content
    # @param goal [String] The project goal
    # @param project_name [String] Name of the project
    # @param existing_files [Array<Hash>] Existing files identified
    # @param planned_files [Array<Hash>] New files to be created
    # @param milestones [Array<Hash>] Milestone structure for step references
    # @return [Hash] Result with :content key containing markdown
    def generate_references(goal:, project_name:, existing_files:, planned_files:, milestones:)
      user_prompt = build_user_prompt(goal, project_name, existing_files, planned_files, milestones)
      execute(prompt: user_prompt)
    end

    
    def build_user_prompt(goal, project_name, existing_files, planned_files, milestones)
      prompt_parts = []

      prompt_parts << "## Project: #{project_name}"
      prompt_parts << "## Goal: #{goal}"

      # Existing files
      prompt_parts << "## Existing Files Identified"
      if existing_files.any?
        existing_files.each do |file|
          path = file[:path] || file["path"]
          desc = file[:description] || file["description"]
          relevance = file[:relevance] || file["relevance"]
          prompt_parts << "- `#{path}`: #{desc} (#{relevance})"
        end
      else
        prompt_parts << "- No existing files identified yet"
      end

      # Planned files
      prompt_parts << "## Planned New Files"
      if planned_files.any?
        planned_files.each do |file|
          path = file[:path] || file["path"]
          desc = file[:description] || file["description"]
          step = file[:created_in] || file["created_in"]
          prompt_parts << "- `#{path}`: #{desc} (Step #{step})"
        end
      else
        prompt_parts << "- Infer planned files from the milestones below"
      end

      # Milestones for context
      prompt_parts << "## Milestones"
      milestones.each do |milestone|
        num = milestone["number"] || milestone[:number]
        title = milestone["title"] || milestone[:title]
        prompt_parts << "### Milestone #{num}: #{title}"
        
        (milestone["steps"] || milestone[:steps] || []).each do |step|
          step_num = step["number"] || step[:number]
          step_title = step["title"] || step[:title]
          prompt_parts << "- Step #{step_num}: #{step_title}"
          
          (step["details"] || step[:details] || []).each do |detail|
            prompt_parts << "  - #{detail}"
          end
        end
      end

      prompt_parts << "\nGenerate the complete file_references.md content as markdown."

      prompt_parts.join("\n\n")
    end
  end
end
