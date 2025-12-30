# frozen_string_literal: true

# Workflow that transforms codebase research results into a structured project plan.
# Uses simple, focused prompts with minimal context to avoid truncation.
#
class ProjectPlanningWorkflow < BaseWorkflow
  attr_reader :goal, :project_name, :research_results, :context

  initial_state :pending

  state :pending,      phase: nil,        description: "Workflow created"
  state :running,      phase: :setup,     description: "Initializing"
  state :milestones,   phase: :planning,  description: "Generating milestones"
  state :steps,        phase: :planning,  description: "Breaking into steps"
  state :detailing,    phase: :planning,  description: "Adding step details"
  state :validating,   phase: :validation, description: "Final validation"
  state :synthesizing, phase: :output,    description: "Generating output"
  state :complete,     phase: nil,        description: "Completed"
  state :failed,       phase: nil,        description: "Failed"

  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :milestones, on: :initialized
  transition from: :milestones, to: :steps, on: :milestones_done
  transition from: :steps, to: :detailing, on: :steps_done
  transition from: :detailing, to: :validating, on: :details_done
  transition from: :validating, to: :synthesizing, on: :validated
  transition from: :synthesizing, to: :complete, on: :finish
  transition from: [:running, :milestones, :steps, :detailing, :validating, :synthesizing],
             to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  def initialize(goal:, project_name:, owner_id:, research_results:, parent_memory: nil, output_path: nil)
    super(owner_id: owner_id, parent_memory: parent_memory)
    @goal = goal
    @project_name = project_name
    @research_results = research_results || {}
    @output_path = output_path || "docs/projects/"
    @existing_files = []
    @planned_files = []
    @milestones = []
    @file_references_content = nil
    @project_plan_content = nil
  end

  def setup(prompt: nil, conversation: nil)
    super
    self
  end

  def execute
    trigger(:start)

    # Extract existing files from research
    trigger(:initialized)
    extract_existing_files

    # Phase 1: Generate milestones (single call, simple)
    trigger(:milestones_done)
    generate_milestones

    # Phase 2: Generate steps for each milestone (one call per milestone)
    trigger(:steps_done)
    generate_steps

    # Phase 3: Add details to each step (one call per step)
    trigger(:details_done)
    add_step_details

    # Phase 4: Quick validation
    trigger(:validated)
    validate_plan

    # Phase 5: Generate output content (no LLM - just formatting)
    synthesize_output

    mark_complete({
      goal: goal,
      project_name: project_name,
      file_references_content: @file_references_content,
      project_plan_content: @project_plan_content,
      milestones: @milestones,
      existing_files: @existing_files,
      planned_files: @planned_files,
      workflow_memory_summary: memory_summary
    })

    result
  rescue StandardError => e
    mark_failed(e.message)
    nil
  end

  
  # Extract existing files from research results
  def extract_existing_files
    relevant_files = research_results[:relevant_files] || []
    file_analyses = research_results[:file_analyses] || []

    seen_paths = Set.new

    relevant_files.each do |file_info|
      path = file_info[:file_path] || file_info["file_path"]
      next if path.nil? || seen_paths.include?(path)
      seen_paths.add(path)

      @existing_files << {
        path: path,
        description: (file_info[:reasoning] || file_info["reasoning"] || "Relevant file").to_s.truncate(50),
        relevance: "Research"
      }
    end

    # Limit to 10 files to avoid context bloat
    @existing_files = @existing_files.first(10)
  end

  # Phase 1: Single call to generate milestones
  def generate_milestones
    research_summary = format_research_summary
    prompt = Planning::MilestoneConsensusPrompt.new

    result = prompt.generate(
      goal: goal,
      research_summary: research_summary
    )

    milestones_data = result.dig(:content, :milestones) || result.dig(:content, "milestones") || []
    @milestones = milestones_data.first(4).map do |m|
      {
        "title" => (m[:title] || m["title"]).to_s.truncate(50),
        "description" => (m[:description] || m["description"]).to_s.truncate(100),
        "steps" => []
      }
    end
  end

  # Phase 2: One call per milestone to generate steps
  def generate_steps
    prompt = Planning::StepBreakdownPrompt.new

    @milestones.each do |milestone|
      result = prompt.generate(
        milestone_title: milestone["title"],
        milestone_description: milestone["description"],
        goal: goal
      )

      steps_data = result.dig(:content, :steps) || result.dig(:content, "steps") || []
      milestone["steps"] = steps_data.first(4).map do |s|
        {
          "title" => (s[:title] || s["title"]).to_s.truncate(50),
          "intent" => (s[:intent] || s["intent"]).to_s.truncate(100),
          "details" => [],
          "tests" => []
        }
      end
    end
  end

  # Phase 3: One call per step to add details
  def add_step_details
    prompt = Planning::StepDetailPrompt.new

    @milestones.each_with_index do |milestone, mi|
      (milestone["steps"] || []).each_with_index do |step, si|
        result = prompt.generate(
          step_title: step["title"],
          step_intent: step["intent"],
          milestone_title: milestone["title"],
          goal: goal
        )

        content = result[:content] || {}
        step["number"] = "#{mi + 1}.#{si + 1}"
        step["details"] = (content[:details] || content["details"] || []).first(3).map { |d| d.to_s.truncate(100) }
        step["tests"] = (content[:tests] || content["tests"] || []).first(2).map { |t| t.to_s.truncate(100) }

        # Extract planned files
        step["details"].each do |detail|
          if detail =~ /[Cc]reate\s+[`']?([a-z_\/]+\.[a-z]+)[`']?/
            @planned_files << { path: $1, description: detail.truncate(50), created_in: step["number"] }
          end
        end
      end

      milestone["number"] = mi + 1
    end

    @planned_files = @planned_files.first(10)
  end

  # Phase 4: Quick validation (single call)
  def validate_plan
    prompt = Planning::ValidationPrompt.new
    prompt.validate(goal: goal, milestones: @milestones)
    # We don't fail on validation issues, just record them
  end

  # Phase 5: Generate markdown output (no LLM)
  def synthesize_output
    @file_references_content = generate_file_references_markdown
    @project_plan_content = generate_project_plan_markdown
  end

  def format_research_summary
    synthesis = research_results[:synthesis] || {}
    summary = synthesis[:summary] || synthesis["summary"] || ""
    summary.to_s.truncate(150)
  end

  def generate_file_references_markdown
    lines = ["# File References", ""]
    lines << "## Existing Files"
    lines << ""

    if @existing_files.any?
      @existing_files.each { |f| lines << "- `#{f[:path]}`: #{f[:description]}" }
    else
      lines << "_No existing files identified._"
    end

    lines << ""
    lines << "## Planned Files"
    lines << ""

    if @planned_files.any?
      @planned_files.each { |f| lines << "- `#{f[:path]}`: #{f[:description]}" }
    else
      lines << "_No new files planned._"
    end

    lines.join("\n")
  end

  def generate_project_plan_markdown
    lines = ["# Project Plan", "", "**Goal**: #{goal}", ""]

    @milestones.each do |m|
      lines << "## Milestone #{m['number']}: #{m['title']}"
      lines << ""
      lines << m["description"]
      lines << ""

      (m["steps"] || []).each do |s|
        lines << "### Step #{s['number']}: #{s['title']}"
        lines << ""
        lines << "**Intent**: #{s['intent']}"
        lines << ""
        lines << "**Details**:"
        (s["details"] || []).each { |d| lines << "- #{d}" }
        lines << ""
        lines << "**Tests**:"
        (s["tests"] || []).each { |t| lines << "- #{t}" }
        lines << ""
      end
    end

    lines.join("\n")
  end
end
