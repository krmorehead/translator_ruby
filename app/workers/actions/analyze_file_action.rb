# frozen_string_literal: true

module Actions
  # Action to analyze a file's contents in the context of the research goal.
  # Uses an LLM to extract relevant information and insights.
  class AnalyzeFileAction < BaseAction
    class << self
      def description
        "Analyze a file's contents to extract information relevant to the research goal"
      end

      def parameters
        {
          file_path: {
            type: :string,
            required: true,
            description: "Path to the file to analyze (relative or absolute)"
          },
          focus: {
            type: :string,
            required: false,
            description: "Specific aspect to focus on (e.g., 'implementation details', 'dependencies')"
          },
          questions: {
            type: :array,
            required: false,
            description: "Specific questions to answer about the file"
          }
        }
      end

      def category
        :analysis
      end
    end

    # Execute the file analysis
    # @param file_path [String] Path to the file to analyze
    # @param focus [String] Specific focus area
    # @param questions [Array<String>] Specific questions to answer
    # @return [Hash] Analysis results
    def execute(file_path:, focus: nil, questions: nil)
      # Resolve the file path
      resolved_path = resolve_file_path(file_path)

      # Check if already analyzed (skip if so)
      if file_already_analyzed?(resolved_path)
        return success_result(
          file_path: resolved_path,
          skipped: true,
          reason: "File already analyzed",
          summary: "Previously analyzed - see existing findings"
        )
      end

      content = read_file(resolved_path)

      # Perform the analysis
      analysis = analyze_content(resolved_path, content, focus, questions)

      # Mark file as analyzed
      mark_file_analyzed(resolved_path)

      # Record findings
      analysis[:insights].each do |insight|
        record_finding(
          text: insight,
          source: resolved_path,
          confidence: analysis[:confidence],
          metadata: { focus: focus, file_type: File.extname(resolved_path) }
        )
      end

      success_result(
        file_path: resolved_path,
        relative_path: resolved_path.sub("#{path}/", ""),
        summary: analysis[:summary],
        insights: analysis[:insights],
        structure: analysis[:structure],
        dependencies: analysis[:dependencies],
        confidence: analysis[:confidence],
        findings: analysis[:insights].map { |i| { text: i, source: resolved_path } }
      )
    end

    
    def resolve_file_path(file_path)
      # Try absolute path first
      return file_path if file_path.start_with?("/") && File.exist?(file_path)

      # Try relative to codebase path
      full_path = File.join(path, file_path)
      return full_path if File.exist?(full_path)

      # Try searching for the file
      matches = Dir.glob(File.join(path, "**", File.basename(file_path)))
      raise ArgumentError, "File not found: #{file_path}" if matches.empty?

      matches.first
    end

    def analyze_content(file_path, content, focus, questions)
      # Use the code understanding prompt
      prompt = Research::CodeUnderstandingPrompt.new

      analysis_prompt = build_analysis_prompt(file_path, focus, questions)
      context = build_analysis_context(content)

      result = prompt.execute(prompt: analysis_prompt, context: context)
      response = result[:content]

      {
        summary: response[:summary] || extract_summary(content),
        insights: Array(response[:insights] || response[:findings]),
        structure: response[:structure] || analyze_structure(content),
        dependencies: response[:dependencies] || extract_dependencies(content),
        confidence: response[:confidence] || 0.8
      }
    end

    def build_analysis_prompt(file_path, focus, questions)
      parts = ["Analyze this file in the context of the research goal: #{goal}"]
      parts << "File: #{file_path}"
      parts << "Focus on: #{focus}" if focus

      if questions&.any?
        parts << "Answer these specific questions:"
        questions.each { |q| parts << "- #{q}" }
      end

      parts.join("\n")
    end

    def build_analysis_context(content)
      context = Contexts::BaseContext.new
      context.add(
        content: content.truncate(8000),
        topics: ["file_content"],
        source: "file"
      )
      context
    end

    def extract_summary(content)
      # Extract first meaningful comment or description
      lines = content.lines.first(20)

      # Look for module/class documentation
      doc_lines = []
      in_doc = false

      lines.each do |line|
        if line =~ /^\s*#\s*(.+)/
          doc_lines << $1.strip
          in_doc = true
        elsif in_doc && line !~ /^\s*#/
          break
        end
      end

      return doc_lines.join(" ").truncate(200) if doc_lines.any?

      # Fall back to first class/module name
      if content =~ /^\s*(class|module)\s+(\w+)/
        "#{$1.capitalize} #{$2}"
      else
        "Code file"
      end
    end

    def analyze_structure(content)
      structure = {
        classes: [],
        modules: [],
        methods: [],
        line_count: content.lines.count
      }

      content.scan(/^\s*class\s+(\S+)/) { |m| structure[:classes] << m[0] }
      content.scan(/^\s*module\s+(\S+)/) { |m| structure[:modules] << m[0] }
      content.scan(/^\s*def\s+(\w+)/) { |m| structure[:methods] << m[0] }

      structure
    end

    def extract_dependencies(content)
      dependencies = []

      # Require statements
      content.scan(/require\s+['"]([^'"]+)['"]/) do |match|
        dependencies << { type: "require", name: match[0] }
      end

      # Require_relative statements
      content.scan(/require_relative\s+['"]([^'"]+)['"]/) do |match|
        dependencies << { type: "require_relative", name: match[0] }
      end

      # Include/Extend statements
      content.scan(/(include|extend|prepend)\s+(\S+)/) do |type, name|
        dependencies << { type: type, name: name }
      end

      dependencies
    end
  end
end
