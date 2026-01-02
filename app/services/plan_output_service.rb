# frozen_string_literal: true

# Service that writes execution plan files to the filesystem.
# Creates docs/plans/{timestamp}_{sanitized_goal}/ directory with plan files.
#
# @example
#   service = PlanOutputService.new(
#     execution_plan: plan,
#     base_path: "/path/to/codebase"
#   )
#   paths = service.write
#   puts paths[:plan_path]
#
class PlanOutputService
  attr_reader :execution_plan, :base_path

  # @param execution_plan [Planning::ExecutionPlan] The plan to write
  # @param base_path [String] Path to the codebase root
  def initialize(execution_plan:, base_path:)
    validate_parameters!(execution_plan, base_path)

    @execution_plan = execution_plan
    @base_path = base_path
  end

  # Write plan files to the filesystem
  # @return [Hash] Paths to created files
  def write
    ensure_directory!

    plan_path = write_plan_markdown
    json_path = write_plan_json
    metadata_path = write_metadata_json

    {
      plan_directory: plan_directory,
      plan_path: plan_path,
      json_path: json_path,
      metadata_path: metadata_path
    }
  end

  private

  # Full path to the plan directory
  def plan_directory
    @plan_directory ||= File.join(ENV.fetch("AGENT_DATA_PATH", base_path), ".agents/docs/plans", directory_name)
  end

  # Generate directory name with timestamp and sanitized goal
  # Format: MM-DD-YYYY_sanitized_goal
  def directory_name
    timestamp = Time.now.strftime("%m-%d-%Y")
    sanitized_goal = sanitize_goal(execution_plan.goal)
    "#{timestamp}_#{sanitized_goal}"
  end

  # Sanitize goal for use in directory name
  def sanitize_goal(goal)
    goal.to_s
        .downcase
        .strip
        .gsub(/[^a-z0-9\s_-]/, "")  # Remove special characters
        .gsub(/[\s-]+/, "_")        # Replace spaces/hyphens with underscore
        .gsub(/^_|_$/, "")          # Remove leading/trailing underscores
        .slice(0, 50)               # Limit length
  end

  # Ensure the plan directory exists
  def ensure_directory!
    FileUtils.mkdir_p(plan_directory)
  end

  # Write plan.md with markdown formatting
  def write_plan_markdown
    ensure_directory!
    path = File.join(plan_directory, "plan.md")
    content = format_plan_markdown
    File.write(path, content)
    path
  end

  # Write plan.json with full serialization
  def write_plan_json
    ensure_directory!
    path = File.join(plan_directory, "plan.json")
    content = JSON.pretty_generate(execution_plan.to_h)
    File.write(path, content)
    path
  end

  # Write metadata.json
  def write_metadata_json
    path = File.join(plan_directory, "metadata.json")
    metadata = {
      goal: execution_plan.goal,
      created_at: execution_plan.created_at,
      milestone_count: execution_plan.milestone_count,
      step_count: execution_plan.step_count
    }
    content = JSON.pretty_generate(metadata)
    File.write(path, content)
    path
  end

  # Format plan as markdown
  def format_plan_markdown
    lines = []
    lines << "# Execution Plan: #{execution_plan.goal}"
    lines << ""
    lines << "## Goal"
    lines << ""
    lines << execution_plan.goal
    lines << ""

    # Optional sections
    if execution_plan.constraints&.any?
      lines << "## Constraints"
      lines << ""
      execution_plan.constraints.each { |c| lines << "- #{c}" }
      lines << ""
    end

    if execution_plan.assumptions&.any?
      lines << "## Assumptions"
      lines << ""
      execution_plan.assumptions.each { |a| lines << "- #{a}" }
      lines << ""
    end

    if execution_plan.risks&.any?
      lines << "## Risks"
      lines << ""
      execution_plan.risks.each { |r| lines << "- #{r}" }
      lines << ""
    end

    # Milestones
    execution_plan.milestones.each_with_index do |milestone, m_idx|
      lines << "## Milestone #{m_idx + 1}: #{milestone.title}"
      lines << ""
      lines << milestone.description
      lines << ""

      # Steps
      milestone.steps.each_with_index do |step, s_idx|
        step_number = "#{m_idx + 1}.#{s_idx + 1}"
        lines << "### #{step_number} - #{step.title}"
        lines << ""
        lines << "**Intent**: #{step.intent}"
        lines << ""

        if step.details.any?
          lines << "**Details**:"
          step.details.each { |d| lines << "- #{d}" }
          lines << ""
        end

        if step.tests.any?
          lines << "**Tests**:"
          step.tests.each { |t| lines << "- #{t}" }
          lines << ""
        end

        if step.estimated_duration
          lines << "**Estimated Duration**: #{step.estimated_duration}"
          lines << ""
        end

        lines << "---"
        lines << ""
      end
    end

    lines.join("\n")
  end

  def validate_parameters!(execution_plan, base_path)
    unless execution_plan.is_a?(Planning::ExecutionPlan)
      raise ArgumentError, "execution_plan must be an ExecutionPlan, got #{execution_plan.class}"
    end
    unless base_path.is_a?(String)
      raise ArgumentError, "base_path must be a String, got #{base_path.class}"
    end
  end
end

