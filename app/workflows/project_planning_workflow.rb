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
    @existing_files = []  # Array of Planning::FileReference
    @planned_files = []   # Array of Planning::FileReference
    @milestones = []      # Array of Planning::Milestone
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

    # Build Planning::Result object with all domain objects
    planning_result = Planning::Result.new(
      goal: goal,
      project_name: project_name,
      milestones: @milestones,
      existing_files: @existing_files,
      planned_files: @planned_files,
      file_references_content: @file_references_content,
      project_plan_content: @project_plan_content
    )

    mark_complete(planning_result)

    result
  rescue StandardError => e
    mark_failed(e.message)
    nil
  end

  
  # Extract existing files from research results
  def extract_existing_files
    relevant_files = research_results[:relevant_files] || research_results["relevant_files"] || []
    
    seen_paths = Set.new

    relevant_files.each do |file_info|
      path = file_info[:file_path] || file_info["file_path"]
      next if path.nil? || seen_paths.include?(path)
      seen_paths.add(path)

      reasoning = file_info[:reasoning] || file_info["reasoning"] || "Relevant file"
      
      # Create Planning::FileReference object
      file_ref = Planning::FileReference.new(
        path: path,
        description: reasoning.to_s.truncate(50),
        relevance: "Research"
      )
      
      @existing_files << file_ref
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
    @milestones = milestones_data.first(4).map.with_index do |m, index|
      # Create Planning::Milestone object
      Planning::Milestone.new(
        number: index + 1,
        title: (m[:title] || m["title"]).to_s.truncate(50),
        description: (m[:description] || m["description"]).to_s.truncate(100)
      )
    end
  end

  # Phase 2: One call per milestone to generate steps
  def generate_steps
    prompt = Planning::StepBreakdownPrompt.new

    @milestones.each do |milestone|
      result = prompt.generate(
        milestone_title: milestone.title,
        milestone_description: milestone.description,
        goal: goal
      )

      steps_data = result.dig(:content, :steps) || result.dig(:content, "steps") || []
      steps_data.first(4).each_with_index do |s, index|
        # Create Planning::Step object with placeholder details/tests
        step = Planning::Step.new(
          milestone_number: milestone.number,
          step_number: index + 1,
          title: (s[:title] || s["title"]).to_s.truncate(50),
          intent: (s[:intent] || s["intent"]).to_s.truncate(100),
          details: [],  # Will be filled in add_step_details
          tests: []     # Will be filled in add_step_details
        )
        
        milestone.add_step(step)
      end
    end
  end

  # Phase 3: One call per step to add details
  def add_step_details
    prompt = Planning::StepDetailPrompt.new

    @milestones.each do |milestone|
      # Need to rebuild steps with details
      updated_steps = []
      
      milestone.steps.each do |step|
        result = prompt.generate(
          step_title: step.title,
          step_intent: step.intent,
          milestone_title: milestone.title,
          goal: goal
        )

        content = result[:content] || {}
        details = (content[:details] || content["details"] || []).first(3).map { |d| d.to_s.truncate(100) }
        tests = (content[:tests] || content["tests"] || []).first(2).map { |t| t.to_s.truncate(100) }

        # Create new step with details and tests
        updated_step = Planning::Step.new(
          milestone_number: step.milestone_number,
          step_number: step.step_number,
          title: step.title,
          intent: step.intent,
          details: details,
          tests: tests
        )
        
        updated_steps << updated_step

        # Extract planned files from details
        details.each do |detail|
          if detail =~ /[Cc]reate\s+[`']?([a-z_\/]+\.[a-z]+)[`']?/
            file_ref = Planning::FileReference.new(
              path: $1,
              description: detail.truncate(50),
              created_in_step: step.number
            )
            @planned_files << file_ref
          end
        end
      end
      
      # Replace milestone's steps with updated versions
      # Clear existing steps and add updated ones
      milestone.instance_variable_set(:@steps, updated_steps)
    end

    @planned_files = @planned_files.first(10)
  end

  # Phase 4: Quick validation (single call)
  def validate_plan
    prompt = Planning::ValidationPrompt.new
    # Convert milestones to hash format for the validation prompt
    milestones_for_validation = @milestones.map do |m|
      {
        "title" => m.title,
        "steps" => m.steps.map { |s| { "title" => s.title } }
      }
    end
    prompt.validate(goal: goal, milestones: milestones_for_validation)
    # We don't fail on validation issues, just record them
  end

  # Phase 5: Generate markdown output using formatters
  def synthesize_output
    # Use FileReferencesFormatter to generate file_references.md content
    file_refs_formatter = Planning::FileReferencesFormatter.new(
      existing_files: @existing_files,
      planned_files: @planned_files
    )
    @file_references_content = file_refs_formatter.generate

    # Use ProjectPlanFormatter to generate project_plan.md content
    plan_formatter = Planning::ProjectPlanFormatter.new(
      goal: goal,
      milestones: @milestones
    )
    @project_plan_content = plan_formatter.generate
  end

  def format_research_summary
    synthesis = research_results[:synthesis] || research_results["synthesis"] || {}
    summary = synthesis[:summary] || synthesis["summary"] || ""
    summary.to_s.truncate(150)
  end
end
