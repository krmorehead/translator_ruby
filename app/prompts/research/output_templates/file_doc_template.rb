# frozen_string_literal: true

module Research
  module OutputTemplates
    # Template for rendering per-file documentation.
    # Produces markdown files matching the docs/references/ structure.
    class FileDocTemplate < BaseOutputTemplate
      def template_name
        "file_doc"
      end

      # Render per-file documentation
      # @param data [Hash] File analysis data with:
      #   - :file_path [String] Path to the source file
      #   - :summary [String] Brief description of file purpose
      #   - :external_references [Array<String>] Files this file depends on
      #   - :methods [Array<Hash>] Method details with :name, :purpose, :parameters, :returns, :calls
      #   - :relevant_sub_questions [Array<String>] Which research questions this file answers
      # @return [String] Rendered markdown
      def render(data)
        output = []

        file_path = data[:file_path]
        summary = data[:summary] || "No summary available."
        external_refs = data[:external_references] || []
        methods = data[:methods] || []

        # Header
        output << "# #{file_path}"
        output << ""

        # Summary
        output << "## Summary"
        output << ""
        output << summary
        output << ""

        # Source link
        output << "## Source"
        output << ""
        output << "- [View Code](#{file_path})"
        output << ""

        # External References diagram
        output << "## External References"
        output << ""
        if external_refs.any?
          output << "```mermaid"
          output << "graph LR"
          file_name = File.basename(file_path)
          external_refs.each_with_index do |ref, idx|
            ref_name = File.basename(ref)
            output << "    #{sanitize_mermaid_id(file_name)}[#{file_name}] --> #{sanitize_mermaid_id(ref_name)}_#{idx}[#{ref_name}]"
          end
          output << "```"
        else
          output << "*No external file references detected.*"
        end
        output << ""

        # Method Architecture diagram
        output << "## Method Architecture"
        output << ""
        if methods.any? && methods.any? { |m| m[:calls]&.any? }
          output << "```mermaid"
          output << "flowchart TD"
          methods.each do |method|
            method_name = method[:name]
            calls = method[:calls] || []
            calls.each do |called_method|
              output << "    #{sanitize_mermaid_id(method_name)}[#{method_name}] --> #{sanitize_mermaid_id(called_method)}[#{called_method}]"
            end
          end
          # Add standalone methods that don't call anything
          methods.each do |method|
            if method[:calls].nil? || method[:calls].empty?
              output << "    #{sanitize_mermaid_id(method[:name])}[#{method[:name]}]"
            end
          end
          output << "```"
        else
          output << "*No method call relationships detected.*"
        end
        output << ""

        # Methods documentation
        output << "## Methods"
        output << ""
        if methods.any?
          methods.each do |method|
            output << "### #{method[:name]}"
            output << ""
            output << method[:purpose] if method[:purpose]
            output << ""

            if method[:parameters]&.any?
              output << "**Parameters:**"
              method[:parameters].each do |param|
                output << "- `#{param[:name]}`: #{param[:description] || param[:type] || 'No description'}"
              end
              output << ""
            end

            if method[:returns]
              output << "**Returns:** #{method[:returns]}"
              output << ""
            end
          end
        else
          output << "*No methods documented.*"
          output << ""
        end

        output.join("\n")
      end

      private

      # Sanitize a string for use as a mermaid node ID
      # Mermaid IDs can't have spaces or special characters
      def sanitize_mermaid_id(name)
        name.to_s.gsub(/[^a-zA-Z0-9_]/, "_")
      end
    end
  end
end

