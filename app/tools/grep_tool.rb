# frozen_string_literal: true

# Tool for searching file contents for patterns.
# Enables finding files that mention specific terms, classes, or concepts.
class GrepTool < BaseTool
  # Default patterns to ignore when searching
  DEFAULT_IGNORE_DIRS = %w[
    .git
    node_modules
    vendor/bundle
    vendor/cache
    tmp
    log
    coverage
    dist
    build
  ].freeze

  def self.name_identifier
    "grep"
  end

  def self.description
    "Search file contents for patterns. Returns matching lines with file path, line number, and context."
  end

  def self.parameters_schema
    {
      type: "object",
      properties: {
        pattern: {
          type: "string",
          description: "The regex pattern to search for"
        },
        path: {
          type: "string",
          description: "The directory or file to search in"
        },
        extensions: {
          type: "array",
          items: { type: "string" },
          description: "File extensions to search (e.g., ['rb', 'py']). If not specified, searches all text files."
        },
        max_results: {
          type: "integer",
          description: "Maximum number of results to return (default: 100)"
        },
        case_insensitive: {
          type: "boolean",
          description: "Enable case-insensitive matching (default: false)"
        },
        whole_word: {
          type: "boolean",
          description: "Match whole words only (default: false)"
        },
        context_lines: {
          type: "integer",
          description: "Number of context lines to include before and after match (default: 0)"
        }
      },
      required: %w[pattern path],
      additionalProperties: false
    }
  end

  def execute(pattern:, path:, extensions: nil, max_results: 100, case_insensitive: false, whole_word: false, context_lines: 0)
    validate_sandbox_path!(path)

    unless File.exist?(path)
      return error_result("Path not found: #{path}")
    end

    # Build the regex
    regex_pattern = whole_word ? "\\b#{pattern}\\b" : pattern
    regex_options = case_insensitive ? Regexp::IGNORECASE : 0
    regex = Regexp.new(regex_pattern, regex_options)

    results = []
    files_searched = 0
    files_matched = 0

    files_to_search(path, extensions).each do |file_path|
      break if results.size >= max_results

      files_searched += 1
      file_results = search_file(file_path, regex, context_lines, max_results - results.size)

      if file_results.any?
        files_matched += 1
        results.concat(file_results)
      end
    end

    success_result({
      matches: results,
      match_count: results.size,
      files_searched: files_searched,
      files_matched: files_matched,
      pattern: pattern,
      truncated: results.size >= max_results
    })
  rescue RegexpError => e
    error_result("Invalid regex pattern: #{e.message}")
  rescue SecurityError => e
    error_result(e.message)
  rescue => e
    error_result("Error searching files: #{e.message}")
  end

  private

  def files_to_search(path, extensions)
    if File.file?(path)
      return [path]
    end

    glob_pattern = if extensions&.any?
      File.join(path, "**", "*.{#{extensions.join(',')}}")
    else
      File.join(path, "**", "*")
    end

    Dir.glob(glob_pattern).select do |file|
      next false unless File.file?(file)
      next false if should_ignore?(file)
      next false if binary_file?(file)

      true
    end
  end

  def should_ignore?(file_path)
    # Don't ignore paths within our sandbox (if configured)
    return false if sandbox_path && file_path.start_with?(File.expand_path(sandbox_path))

    DEFAULT_IGNORE_DIRS.any? do |dir|
      file_path.include?("/#{dir}/") || file_path.start_with?("#{dir}/")
    end
  end

  def binary_file?(file_path)
    # Check first 8KB for null bytes (binary indicator)
    sample = File.read(file_path, 8192) rescue nil
    return true if sample.nil?

    sample.include?("\x00")
  end

  def search_file(file_path, regex, context_lines, remaining_slots)
    results = []
    lines = File.readlines(file_path, chomp: true)

    lines.each_with_index do |line, idx|
      break if results.size >= remaining_slots

      next unless line.match?(regex)

      line_number = idx + 1
      context_before = context_lines > 0 ? get_context(lines, idx, -context_lines) : []
      context_after = context_lines > 0 ? get_context(lines, idx, context_lines) : []

      results << {
        file: file_path,
        line_number: line_number,
        line: line,
        context_before: context_before,
        context_after: context_after
      }
    end

    results
  rescue => e
    # Skip files that can't be read
    []
  end

  def get_context(lines, current_idx, offset)
    if offset.negative?
      start_idx = [0, current_idx + offset].max
      lines[start_idx...current_idx].map.with_index do |line, i|
        { line_number: start_idx + i + 1, line: line }
      end
    else
      end_idx = [lines.size - 1, current_idx + offset].min
      lines[(current_idx + 1)..end_idx].map.with_index do |line, i|
        { line_number: current_idx + i + 2, line: line }
      end
    end
  end
end

# Register with ToolCallService
ToolCallService.register_tool(GrepTool)

