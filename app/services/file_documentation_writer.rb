# frozen_string_literal: true

# Service for writing per-file documentation.
# Handles the generation of mermaid diagrams and base_references.md files.
class FileDocumentationWriter
  attr_reader :output_base_path, :source_base_path

  def initialize(output_base_path:, source_base_path:)
    @output_base_path = output_base_path
    @source_base_path = source_base_path
    @documented_files = {}
    @file_doc_template = Research::OutputTemplates::FileDocTemplate.new
    @base_refs_template = Research::OutputTemplates::BaseReferencesTemplate.new
    @synthesis_template = Research::OutputTemplates::SynthesisSummaryTemplate.new
  end

  # Write documentation for a single file
  # @param file_analysis [Hash] Analysis from PerFileDocPrompt with :file_path, :summary, :methods, etc.
  # @return [String] Path to created documentation file
  def write_file_doc(file_analysis:)
    source_path = file_analysis[:file_path]
    relative_path = relative_to_source(source_path)
    doc_path = doc_path_for(relative_path)

    # Ensure directory exists
    FileUtils.mkdir_p(File.dirname(doc_path))

    # Render and write
    content = @file_doc_template.render(file_analysis.merge(file_path: relative_path))
    File.write(doc_path, content)

    # Track for base_references generation
    track_documented_file(relative_path, file_analysis)

    doc_path
  end

  # Write base_references.md for a directory
  # @param directory [String] Relative directory path
  # @param files [Array<Hash>] Files in this directory with :path, :description
  # @return [String] Path to created base_references.md
  def write_base_references(directory:, files:)
    doc_dir = File.join(output_base_path, directory)
    FileUtils.mkdir_p(doc_dir)

    # Find subdirectories that have documented files
    subdirectories = find_documented_subdirectories(directory)

    data = {
      directory_path: directory,
      files: files,
      subdirectories: subdirectories
    }

    content = @base_refs_template.render(data)
    output_path = File.join(doc_dir, "base_references.md")
    File.write(output_path, content)

    output_path
  end

  # Write synthesis_summary.md at the root
  # @param synthesis [Hash] Synthesis data with :research_goal, :summary, etc.
  # @return [String] Path to created synthesis_summary.md
  def write_synthesis_summary(synthesis:)
    FileUtils.mkdir_p(output_base_path)

    # Add documented files info to synthesis
    synthesis_with_files = synthesis.merge(
      documented_files: @documented_files.map do |path, info|
        { path: path, sub_questions: info[:sub_questions] || [] }
      end
    )

    content = @synthesis_template.render(synthesis_with_files)
    output_path = File.join(output_base_path, "synthesis_summary.md")
    File.write(output_path, content)

    output_path
  end

  # Generate all base_references.md files for documented directories
  # @return [Array<String>] Paths to created base_references.md files
  def generate_all_base_references
    created = []

    # Group files by directory
    by_directory = @documented_files.group_by { |path, _| File.dirname(path) }

    # Generate for each directory that has files
    by_directory.each do |dir, files_in_dir|
      files_data = files_in_dir.map do |path, info|
        { path: path, description: info[:summary] }
      end

      created << write_base_references(directory: dir, files: files_data)
    end

    # Generate root base_references.md
    root_files = by_directory["."] || []
    if @documented_files.any?
      root_data = root_files.map { |path, info| { path: path, description: info[:summary] } }
      root_subdirs = by_directory.keys.reject { |d| d == "." }.map { |d| d.split("/").first }.uniq

      data = {
        directory_path: ".",
        files: root_data,
        subdirectories: root_subdirs
      }

      content = @base_refs_template.render(data)
      root_path = File.join(output_base_path, "base_references.md")
      File.write(root_path, content)
      created << root_path
    end

    created
  end

  # Get all documented file paths
  # @return [Array<String>] Relative paths of documented files
  def documented_file_paths
    @documented_files.keys
  end

  
  # Convert absolute source path to relative path
  def relative_to_source(path)
    if path.start_with?(source_base_path)
      path.sub("#{source_base_path}/", "")
    else
      path
    end
  end

  # Get the documentation output path for a source file
  def doc_path_for(relative_source_path)
    doc_relative = relative_source_path.sub(/\.[^.]+$/, ".md")
    File.join(output_base_path, doc_relative)
  end

  # Track a documented file for base_references generation
  def track_documented_file(relative_path, analysis)
    @documented_files[relative_path] = {
      summary: analysis[:summary],
      sub_questions: analysis[:relevant_sub_questions] || []
    }
  end

  # Find subdirectories of a directory that contain documented files
  def find_documented_subdirectories(directory)
    prefix = directory == "." ? "" : "#{directory}/"

    @documented_files.keys
      .select { |path| path.start_with?(prefix) && path != prefix }
      .map { |path| path.sub(prefix, "").split("/").first }
      .uniq
      .sort
  end
end

