# frozen_string_literal: true

# Service that writes formatted research findings to the output directory.
# Manages file creation, naming, and organization.
# Supports output_modes array with any combination of:
# - :report - Traditional research report (single or multi-file)
# - :documentation - Per-file documentation mirroring codebase structure
class ResearchOutputService
  attr_reader :output_path, :research_topic, :source_path

  DEFAULT_OUTPUT_PATH = ".agents/references"
  VALID_OUTPUT_MODES = [:report, :documentation].freeze

  def initialize(research_topic:, base_path: nil)
    @research_topic = research_topic
    @source_path = base_path || "."
    @output_path = ENV["RESEARCH_OUTPUT_PATH"] || File.join(@source_path, DEFAULT_OUTPUT_PATH)
    @report_template = Research::OutputTemplates::ReportTemplate.new
  end

  # Write research results to output files
  # @param synthesis [Hash] Synthesis results
  # @param output_modes [Array<Symbol>] Array of output modes (e.g. [:report, :documentation])
  # @param file_analyses [Array<Hash>] Per-file analysis results (required for :documentation mode)
  # @param report_format [Symbol] Format for report mode (:single_file or :multi_file)
  # @return [Array<String>] List of created file paths
  def write(synthesis:, output_modes: [:report], file_analyses: [], report_format: :single_file)
    ensure_output_directory!

    modes = Array(output_modes).map(&:to_sym) & VALID_OUTPUT_MODES
    modes = [:report] if modes.empty? # Default fallback

    created_files = []

    # Generate each requested output type
    modes.each do |mode|
      case mode
      when :documentation
        created_files.concat(write_documentation(synthesis, file_analyses))
      when :report
        if report_format == :multi_file
          created_files.concat(write_multi_file(synthesis))
    else
          created_files.concat(write_single_file(synthesis))
        end
      end
    end

    created_files
  end

  # Write per-file documentation mirroring codebase structure
  # @param synthesis [Hash] Synthesis results
  # @param file_analyses [Array<Hash>] Per-file analysis results from PerFileDocPrompt
  # @return [Array<String>] List of created file paths
  def write_documentation(synthesis, file_analyses)
    created_files = []

    writer = FileDocumentationWriter.new(
      output_base_path: output_path,
      source_base_path: source_path
    )

    # Write per-file documentation
    file_analyses.each do |analysis|
      path = writer.write_file_doc(file_analysis: analysis)
      created_files << path
    end

    # Generate base_references.md for each directory
    created_files.concat(writer.generate_all_base_references)

    # Write synthesis summary
    synthesis_data = synthesis.merge(
      research_goal: research_topic,
      sub_questions: synthesis[:detailed_sections]&.map { |s| { question: s[:sub_question], answer: s[:answer] } } || []
    )
    created_files << writer.write_synthesis_summary(synthesis: synthesis_data)

    created_files
  end

  # Write a single consolidated file
  # @param synthesis [Hash] Synthesis results
  # @return [Array<String>] Single-element array with file path
  def write_single_file(synthesis)
    filename = generate_filename
    file_path = File.join(output_path, filename)

    content = format_as_markdown(synthesis)
    File.write(file_path, content)

    [file_path]
  end

  # Write multiple files organized by section
  # @param synthesis [Hash] Synthesis results
  # @return [Array<String>] Array of created file paths
  def write_multi_file(synthesis)
    created_files = []
    base_name = slugify(research_topic)

    # Create index file
    index_path = File.join(output_path, "#{base_name}_index.md")
    index_content = generate_index(synthesis, base_name)
    File.write(index_path, index_content)
    created_files << index_path

    # Create section files
    sections = synthesis[:detailed_sections] || []
    sections.each_with_index do |section, idx|
      section_filename = "#{base_name}_#{idx + 1}_#{slugify(section[:sub_question])}.md"
      section_path = File.join(output_path, section_filename)

      section_content = format_section(section)
      File.write(section_path, section_content)
      created_files << section_path
    end

    created_files
  end

  
  def ensure_output_directory!
    FileUtils.mkdir_p(output_path)
  end

  def generate_filename
    timestamp = Time.now.strftime("%Y-%m-%d")
    slug = slugify(research_topic)
    "#{timestamp}_#{slug}.md"
  end

  def slugify(text)
    text
      .to_s
      .downcase
      .gsub(/[^a-z0-9\s-]/, "")
      .gsub(/\s+/, "_")
      .gsub(/_+/, "_")
      .slice(0, 50)
      .gsub(/^_|_$/, "")
  end

  def format_as_markdown(synthesis)
    output = []

    # Header
    output << "# Research: #{research_topic}"
    output << ""
    output << "> Generated: #{Time.now.utc.iso8601}"
    output << ""

    # Summary
    summary = synthesis[:summary]
    if summary
      output << "## Summary"
      output << ""
      output << summary
      output << ""
    end

    # Table of Contents
    sections = synthesis[:detailed_sections] || []
    if sections.any?
      output << "## Table of Contents"
      output << ""
      sections.each_with_index do |section, idx|
        sub_q = section[:sub_question]
        anchor = slugify(sub_q).gsub("_", "-")
        output << "- [#{sub_q}](##{anchor})"
      end
      output << ""
    end

    # Detailed Sections
    sections.each do |section|
      sub_q = section[:sub_question]
      answer = section[:answer]
      findings = section[:key_findings] || []

      output << "## #{sub_q}"
      output << ""
      output << answer
      output << ""

      if findings.any?
        output << "### Key Findings"
        output << ""
        findings.each { |f| output << "- #{f}" }
        output << ""
      end
    end

    # Validated Insights
    insights = synthesis[:validated_insights] || []
    if insights.any?
      output << "## Validated Insights"
      output << ""
      insights.each { |insight| output << "- #{insight}" }
      output << ""
    end

    # Open Questions
    open_qs = synthesis[:open_questions] || []
    if open_qs.any?
      output << "## Open Questions"
      output << ""
      open_qs.each { |q| output << "- #{q}" }
      output << ""
    end

    # Conflicts (if any)
    conflicts = synthesis[:conflicts] || []
    if conflicts.any?
      output << "## Conflicts Requiring Review"
      output << ""
      conflicts.each { |c| output << "- #{c}" }
      output << ""
    end

    output.join("\n")
  end

  def generate_index(synthesis, base_name)
    output = []
    output << "# #{research_topic} - Index"
    output << ""
    output << "> Generated: #{Time.now.utc.iso8601}"
    output << ""
    output << "## Summary"
    output << ""
    output << (synthesis[:summary] || "No summary available")
    output << ""
    output << "## Sections"
    output << ""

    sections = synthesis[:detailed_sections] || []
    sections.each_with_index do |section, idx|
      sub_q = section[:sub_question]
      filename = "#{base_name}_#{idx + 1}_#{slugify(sub_q)}.md"
      output << "- [#{sub_q}](#{filename})"
    end

    output.join("\n")
  end

  def format_section(section)
    output = []
    sub_q = section[:sub_question]
    answer = section[:answer]
    findings = section[:key_findings] || []

    output << "# #{sub_q}"
    output << ""
    output << answer
    output << ""

    if findings.any?
      output << "## Key Findings"
      output << ""
      findings.each { |f| output << "- #{f}" }
    end

    output.join("\n")
  end
end

