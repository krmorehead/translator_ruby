# frozen_string_literal: true

module Research
  module OutputTemplates
    # Abstract base class for output templates.
    # Templates provide render methods to transform structured data into markdown.
    class BaseOutputTemplate
      # Returns the template name identifier
      def template_name
        raise NotImplementedError, "#{self.class.name} must define #template_name"
      end

      # Render data to markdown string
      # @param data [Hash] The structured data to render
      # @return [String] Rendered markdown
      def render(data)
        raise NotImplementedError, "#{self.class.name} must define #render"
      end

      protected

      # Interpolate variables in a template string
      # @param template [String] Template with {variable} placeholders
      # @param variables [Hash] Variables to interpolate
      # @return [String] Interpolated string
      def interpolate(template, variables)
        result = template.dup
        variables.each do |key, value|
          result.gsub!("{#{key}}", value.to_s)
        end
        result
      end

      # Convert a code file path to its documentation path
      # @param code_path [String] Path to code file (e.g., "lib/calculator.rb")
      # @return [String] Documentation file path (e.g., "lib/calculator.md")
      def code_path_to_doc_path(code_path)
        # Replace the extension with .md
        code_path.sub(/\.[^.]+$/, ".md")
      end

      # Get current timestamp in ISO8601 format
      def timestamp
        Time.now.utc.iso8601
      end
    end
  end
end

