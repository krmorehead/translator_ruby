# frozen_string_literal: true

# Service that writes generated project plan files to the correct directory structure.
# Handles directory creation, file writing, and path management.
#
# @example
#   service = ProjectPlanOutputService.new(
#     project_name: "user_authentication",
#     base_path: "/path/to/codebase"
#   )
#   paths = service.write(
#     file_references_content: "# File References...",
#     project_plan_content: "# Project Plan..."
#   )
#   puts paths[:project_path]
#
class ProjectPlanOutputService
  attr_reader :project_name, :base_path, :output_base

  # @param project_name [String] Name of the project (will be slugified)
  # @param base_path [String] Path to the codebase (for context)
  # @param output_base [String] Base output directory (default: docs/projects/)
  def initialize(project_name:, base_path:, output_base: nil)
    @project_name = project_name
    @base_path = base_path
    @output_base = output_base || default_output_base
  end

  # Full path to the project directory
  # @return [String] Project directory path
  def project_directory
    @project_directory ||= File.join(output_base, directory_name)
  end

  # Write both files to the project directory
  # @param file_references_content [String] Content for file_references.md
  # @param project_plan_content [String] Content for project_plan.md
  # @return [Hash] Paths to created files
  def write(file_references_content:, project_plan_content:)
    ensure_directory!

    file_refs_path = write_file_references(file_references_content)
    plan_path = write_project_plan(project_plan_content)

    {
      project_path: project_directory,
      file_references_path: file_refs_path,
      project_plan_path: plan_path
    }
  end

  # Write file_references.md
  # @param content [String] Markdown content
  # @return [String] Path to created file
  def write_file_references(content)
    path = File.join(project_directory, "file_references.md")
    File.write(path, content)
    path
  end

  # Write project_plan.md
  # @param content [String] Markdown content
  # @return [String] Path to created file
  def write_project_plan(content)
    path = File.join(project_directory, "project_plan.md")
    File.write(path, content)
    path
  end

  
  # Generate directory name with date prefix
  # Format: MM-DD-YYYY_slugified_project_name
  def directory_name
    date_prefix = Time.now.strftime("%m-%d-%Y")
    slugified_name = slugify(project_name)
    "#{date_prefix}_#{slugified_name}"
  end

  # Slugify the project name for filesystem use
  # @param name [String] Project name
  # @return [String] Slugified name
  def slugify(name)
    name.to_s
        .downcase
        .strip
        .gsub(/[^a-z0-9\s_-]/, "")  # Remove special characters (keep underscores)
        .gsub(/[\s-]+/, "_")        # Replace spaces/hyphens with underscore
        .gsub(/^_|_$/, "")          # Remove leading/trailing underscores
  end

  # Default output base directory
  def default_output_base
    File.join(base_path, "docs", "projects")
  end

  # Ensure the project directory exists
  def ensure_directory!
    FileUtils.mkdir_p(project_directory)
  end
end

