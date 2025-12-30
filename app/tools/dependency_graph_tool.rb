# frozen_string_literal: true

# Tool for analyzing code dependencies across different programming languages.
# Uses file extensions to determine import patterns, with LLM fallback for unknown languages.
class DependencyGraphTool < BaseTool
  # JavaScript/TypeScript import patterns
  JS_PATTERNS = [
    /import\s+.*\s+from\s+["']([^"']+)["']/,
    /import\s+["']([^"']+)["']/,
    /require\(["']([^"']+)["']\)/,
    /export\s+.*\s+from\s+["']([^"']+)["']/
  ].freeze

  # Language detection patterns by file extension
  LANGUAGE_PATTERNS = {
    # Ruby
    ".rb" => {
      language: "ruby",
      patterns: [
        /require\s+["']([^"']+)["']/,
        /require_relative\s+["']([^"']+)["']/,
        /include\s+([A-Z][A-Za-z0-9:]*)/,
        /extend\s+([A-Z][A-Za-z0-9:]*)/,
        /prepend\s+([A-Z][A-Za-z0-9:]*)/,
        /class\s+\w+\s*<\s*([A-Z][A-Za-z0-9:]*)/
      ]
    },
    # Python
    ".py" => {
      language: "python",
      patterns: [
        /^import\s+(\S+)/,
        /^from\s+(\S+)\s+import/
      ]
    },
    # JavaScript/TypeScript
    ".js" => { language: "javascript", patterns: JS_PATTERNS },
    ".jsx" => { language: "javascript", patterns: JS_PATTERNS },
    ".ts" => { language: "typescript", patterns: JS_PATTERNS },
    ".tsx" => { language: "typescript", patterns: JS_PATTERNS },
    # Go
    ".go" => {
      language: "go",
      patterns: [
        /import\s+"([^"]+)"/,
        /import\s+\(\s*"([^"]+)"/
      ]
    },
    # Java
    ".java" => {
      language: "java",
      patterns: [
        /import\s+([\w.]+)/,
        /extends\s+(\w+)/,
        /implements\s+([\w,\s]+)/
      ]
    },
    # Rust
    ".rs" => {
      language: "rust",
      patterns: [
        /use\s+([\w:]+)/,
        /mod\s+(\w+)/,
        /pub\s+use\s+([\w:]+)/
      ]
    }
  }.freeze

  def self.name_identifier
    "dependency_graph"
  end

  def self.description
    "Analyze file dependencies to understand code relationships. Returns nodes (files) and edges (dependencies)."
  end

  def self.parameters_schema
    {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: "The file or directory to analyze"
        },
        depth: {
          type: "integer",
          description: "How deep to follow dependencies (default: 3)"
        },
        language_hint: {
          type: "string",
          description: "Override language detection (e.g., 'ruby', 'python')"
        }
      },
      required: ["path"],
      additionalProperties: false
    }
  end

  def execute(path:, depth: 3, language_hint: nil)
    unless File.exist?(path)
      return error_result("Path not found: #{path}")
    end

    nodes = {}
    edges = []
    visited = Set.new
    @llm_pattern_cache = {}

    if File.file?(path)
      analyze_file(path, nodes, edges, visited, depth, language_hint)
    else
      # Analyze all files in directory
      Dir.glob(File.join(path, "**", "*")).each do |file_path|
        next unless File.file?(file_path)
        next if binary_file?(file_path)

        analyze_file(file_path, nodes, edges, visited, depth, language_hint)
      end
    end

    success_result({
      nodes: nodes.values,
      edges: edges.uniq,
      node_count: nodes.size,
      edge_count: edges.uniq.size,
      root: path
    })
  end

  
  def analyze_file(file_path, nodes, edges, visited, remaining_depth, language_hint)
    return if visited.include?(file_path)
    return if remaining_depth <= 0

    visited.add(file_path)

    # Add file as a node
    nodes[file_path] ||= create_node(file_path)

    # Extract dependencies
    deps = extract_dependencies(file_path, language_hint)

    deps.each do |dep|
      edges << {
        source: file_path,
        target: dep[:reference],
        type: dep[:type],
        resolved_path: dep[:resolved_path]
      }

      # If we resolved to a real file, analyze it too
      if dep[:resolved_path] && File.exist?(dep[:resolved_path])
        nodes[dep[:resolved_path]] ||= create_node(dep[:resolved_path])

        if remaining_depth > 1
          analyze_file(dep[:resolved_path], nodes, edges, visited, remaining_depth - 1, language_hint)
        end
      end
    end
  end

  def create_node(file_path)
    {
      path: file_path,
      name: File.basename(file_path),
      extension: File.extname(file_path),
      size: File.size(file_path),
      language: detect_language(file_path)
    }
  end

  def detect_language(file_path)
    ext = File.extname(file_path)
    pattern_info = LANGUAGE_PATTERNS[ext]
    pattern_info ? pattern_info[:language] : "unknown"
  end

  def extract_dependencies(file_path, language_hint)
    content = File.read(file_path)
    ext = File.extname(file_path)
    base_dir = File.dirname(file_path)

    # Determine patterns to use
    patterns = if language_hint && LANGUAGE_PATTERNS.values.find { |v| v[:language] == language_hint }
      LANGUAGE_PATTERNS.values.find { |v| v[:language] == language_hint }[:patterns]
    elsif LANGUAGE_PATTERNS[ext]
      LANGUAGE_PATTERNS[ext][:patterns]
    else
      # Use LLM fallback for unknown language
      get_llm_patterns(file_path, content)
    end

    return [] if patterns.nil? || patterns.empty?

    dependencies = []

    patterns.each do |pattern|
      content.scan(pattern) do |match|
        ref = match.is_a?(Array) ? match.first : match
        next if ref.nil? || ref.empty?

        dependencies << {
          reference: ref.strip,
          type: classify_dependency_type(pattern),
          resolved_path: resolve_path(ref.strip, base_dir, ext)
        }
      end
    end

    dependencies
  end

  def classify_dependency_type(pattern)
    pattern_str = pattern.source
    case pattern_str
    when /require|import|use/i
      "import"
    when /include|extend|prepend/
      "mixin"
    when /class.*<|extends/
      "inheritance"
    when /implements/
      "interface"
    else
      "reference"
    end
  end

  def resolve_path(reference, base_dir, ext)
    # Try to resolve to an actual file path
    candidates = [
      File.join(base_dir, reference),
      File.join(base_dir, "#{reference}#{ext}"),
      File.join(base_dir, reference, "index#{ext}"),
      File.join(base_dir, "..", reference),
      File.join(base_dir, "..", "#{reference}#{ext}")
    ]

    # For Ruby require_relative style
    if ext == ".rb"
      candidates << File.join(base_dir, "#{reference}.rb")
    end

    candidates.find { |path| File.exist?(path) }
  end

  def get_llm_patterns(file_path, content)
    ext = File.extname(file_path)

    # Check cache first
    return @llm_pattern_cache[ext] if @llm_pattern_cache.key?(ext)

    # Use LLM to identify import patterns
    sample = content.lines.first(50).join("\n")

    begin
      prompt = LlmPatternPrompt.new
      result = prompt.execute(
        prompt: "Analyze this code sample and identify the import/dependency patterns used. Return regex patterns that would match import statements.",
        context: { file_extension: ext, sample: sample }
      )

      patterns = result[:content]["patterns"]&.map { |p| Regexp.new(p) } || []
      @llm_pattern_cache[ext] = patterns
      patterns
    rescue => e
      # If LLM fails, return empty patterns
      @llm_pattern_cache[ext] = []
      []
    end
  end

  def binary_file?(file_path)
    sample = File.read(file_path, 8192) rescue nil
    return true if sample.nil?

    sample.include?("\x00")
  end

  # Simple prompt for pattern detection
  class LlmPatternPrompt < BasePrompt
    def system_prompt
      <<~PROMPT
        You are a code analysis expert. Given a code sample from an unknown language,
        identify the patterns used for importing/including dependencies.

        Return a JSON object with a "patterns" array containing regex patterns that
        would match import statements in this language.
      PROMPT
    end

    def response_schema
      {
        type: "object",
        properties: {
          patterns: {
            type: "array",
            items: { type: "string" },
            description: "Regex patterns for matching import statements"
          },
          language_guess: {
            type: "string",
            description: "Best guess at the programming language"
          }
        },
        required: %w[patterns language_guess],
        additionalProperties: false
      }
    end
  end
end

# Register with ToolCallService
ToolCallService.register_tool(DependencyGraphTool)

