# frozen_string_literal: true

module Planning
  # Formats file references into a markdown document.
  # Generates the file_references.md content with tables for existing and planned files.
  #
  # @example
  #   formatter = Planning::FileReferencesFormatter.new(
  #     existing_files: [existing_ref1, existing_ref2],
  #     planned_files: [planned_ref1, planned_ref2]
  #   )
  #   markdown = formatter.generate
  class FileReferencesFormatter
    attr_reader :existing_files, :planned_files

    # @param existing_files [Array<Planning::FileReference>] Existing files from research
    # @param planned_files [Array<Planning::FileReference>] Files to be created
    def initialize(existing_files:, planned_files:)
      validate_inputs!(existing_files, planned_files)
      
      @existing_files = existing_files
      @planned_files = planned_files
    end

    # Generate the markdown content for file_references.md
    # @return [String] Markdown-formatted file references document
    def generate
      lines = []
      lines << "# File References"
      lines << ""
      
      lines.concat(generate_existing_files_section)
      lines << ""
      lines.concat(generate_planned_files_section)
      
      lines.join("\n")
    end

    private

    def validate_inputs!(existing_files, planned_files)
      unless existing_files.is_a?(Array)
        raise ArgumentError, "existing_files must be an Array, got #{existing_files.class}"
      end
      
      unless planned_files.is_a?(Array)
        raise ArgumentError, "planned_files must be an Array, got #{planned_files.class}"
      end
      
      if existing_files.any? { |f| !f.is_a?(FileReference) }
        raise TypeError, "all existing_files must be Planning::FileReference objects"
      end
      
      if planned_files.any? { |f| !f.is_a?(FileReference) }
        raise TypeError, "all planned_files must be Planning::FileReference objects"
      end
    end

    def generate_existing_files_section
      lines = []
      lines << "## Existing Files"
      lines << ""
      
      if @existing_files.any?
        lines << "| File Path | Description | Relevance |"
        lines << "|-----------|-------------|-----------|"
        
        @existing_files.each do |file|
          lines << "| `#{file.path}` | #{file.description} | #{file.relevance} |"
        end
      else
        lines << "_No existing files identified._"
      end
      
      lines
    end

    def generate_planned_files_section
      lines = []
      lines << "## Planned Files"
      lines << ""
      
      if @planned_files.any?
        lines << "| File Path | Description | Created In |"
        lines << "|-----------|-------------|------------|"
        
        @planned_files.each do |file|
          lines << "| `#{file.path}` | #{file.description} | #{file.created_in_step} |"
        end
      else
        lines << "_No new files planned._"
      end
      
      lines
    end
  end
end

