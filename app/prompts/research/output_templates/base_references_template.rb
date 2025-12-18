# frozen_string_literal: true

module Research
  module OutputTemplates
    # Template for rendering base_references.md files.
    # Produces directory tree documentation matching docs/references/ structure.
    class BaseReferencesTemplate < BaseOutputTemplate
      def template_name
        "base_references"
      end

      # Render base_references.md for a directory
      # @param data [Hash] Directory data with:
      #   - :directory_path [String] Relative path to the directory
      #   - :files [Array<Hash>] Files in this directory with :path, :description
      #   - :subdirectories [Array<String>] Subdirectory names
      # @return [String] Rendered markdown
      def render(data)
        output = []

        directory_path = data[:directory_path] || "."
        files = data[:files] || []
        subdirectories = data[:subdirectories] || []

        # Header
        if directory_path == "." || directory_path.empty?
          output << "# Research References"
        else
          output << "# #{directory_path} Reference Index"
        end
        output << ""

        # Tree diagram
        output << "```"
        output << "#{File.basename(directory_path) || 'references'}/"

        # List subdirectories first
        subdirectories.each do |subdir|
          output << "├── #{subdir}/"
        end

        # List files
        files.each_with_index do |file, idx|
          prefix = idx == files.length - 1 && subdirectories.empty? ? "└──" : "├──"
          filename = File.basename(file[:path])
          description = file[:description] || ""
          if description.present?
            output << "#{prefix} #{filename.sub(/\.[^.]+$/, '.md')}    # #{description}"
          else
            output << "#{prefix} #{filename.sub(/\.[^.]+$/, '.md')}"
          end
        end

        output << "```"
        output << ""

        # Quick navigation links
        if files.any?
          output << "## Files"
          output << ""
          files.each do |file|
            filename = File.basename(file[:path])
            doc_filename = filename.sub(/\.[^.]+$/, ".md")
            description = file[:description] || "No description"
            output << "- [#{filename}](#{doc_filename}) - #{description}"
          end
          output << ""
        end

        # Subdirectory links
        if subdirectories.any?
          output << "## Subdirectories"
          output << ""
          subdirectories.each do |subdir|
            output << "- [#{subdir}/](#{subdir}/base_references.md)"
          end
          output << ""
        end

        output.join("\n")
      end
    end
  end
end

