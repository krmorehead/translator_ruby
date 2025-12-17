# frozen_string_literal: true

# Tool for listing directory structure recursively.
# Essential for discovering what files exist in a codebase.
class FileTreeTool < BaseTool
  # Default patterns to ignore
  DEFAULT_IGNORE_PATTERNS = %w[
    .git
    node_modules
    vendor/bundle
    vendor/cache
    tmp
    log
    .bundle
    coverage
    .DS_Store
    __pycache__
    .pytest_cache
    .mypy_cache
    dist
    build
    .next
    .nuxt
  ].freeze

  def self.name_identifier
    "file_tree"
  end

  def self.description
    "List directory structure recursively to discover files in a codebase"
  end

  def self.parameters_schema
    {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: "The directory path to list"
        },
        max_depth: {
          type: "integer",
          description: "Maximum depth to recurse (default: 10)"
        },
        extensions: {
          type: "array",
          items: { type: "string" },
          description: "Filter to only show files with these extensions (e.g., ['rb', 'py'])"
        },
        ignore_patterns: {
          type: "array",
          items: { type: "string" },
          description: "Additional patterns to ignore"
        }
      },
      required: ["path"],
      additionalProperties: false
    }
  end

  def execute(path:, max_depth: 10, extensions: nil, ignore_patterns: nil)
    validate_sandbox_path!(path)

    unless File.exist?(path)
      return error_result("Path not found: #{path}")
    end

    unless File.directory?(path)
      return error_result("Path is not a directory: #{path}")
    end

    all_ignore = DEFAULT_IGNORE_PATTERNS + (ignore_patterns || [])
    tree = build_tree(path, max_depth, extensions, all_ignore, 0)
    formatted = format_tree(tree)

    success_result({
      tree: tree,
      formatted: formatted,
      root: path,
      file_count: count_files(tree),
      directory_count: count_directories(tree)
    })
  rescue SecurityError => e
    error_result(e.message)
  rescue => e
    error_result("Error listing directory: #{e.message}")
  end

  private

  def build_tree(dir_path, max_depth, extensions, ignore_patterns, current_depth)
    return nil if current_depth > max_depth

    name = File.basename(dir_path)

    # Check if this path matches any ignore pattern (unless within sandbox)
    effective_patterns = effective_ignore_patterns(dir_path, ignore_patterns)
    return nil if should_ignore?(name, effective_patterns)

    if File.directory?(dir_path)
      children = Dir.children(dir_path).sort.filter_map do |child|
        child_path = File.join(dir_path, child)
        build_tree(child_path, max_depth, extensions, ignore_patterns, current_depth + 1)
      end

      {
        name: name,
        path: dir_path,
        type: :directory,
        children: children
      }
    else
      # Check extension filter
      if extensions
        ext = File.extname(name).delete(".")
        return nil unless extensions.include?(ext)
      end

      {
        name: name,
        path: dir_path,
        type: :file,
        size: File.size(dir_path)
      }
    end
  end

  def should_ignore?(name, patterns)
    # Hidden files are still ignored
    return true if name.start_with?(".")

    patterns.any? do |pattern|
      if pattern.include?("/")
        name == pattern
      else
        name == pattern || File.fnmatch?(pattern, name)
      end
    end
  end

  # Returns effective ignore patterns, being less aggressive for sandbox paths
  def effective_ignore_patterns(dir_path, patterns)
    # If the directory is within our sandbox, be less aggressive with ignores
    if sandbox_path && File.expand_path(dir_path).start_with?(File.expand_path(sandbox_path))
      # Only keep truly harmful patterns
      patterns.select { |p| %w[.git node_modules vendor/bundle].include?(p) }
    else
      patterns
    end
  end

  def format_tree(node, prefix = "", is_last = true)
    return "" if node.nil?

    connector = is_last ? "└── " : "├── "
    line = "#{prefix}#{connector}#{node[:name]}"

    if node[:type] == :file
      size_str = format_size(node[:size])
      line += " (#{size_str})"
    end

    result = [line]

    if node[:type] == :directory && node[:children]&.any?
      new_prefix = prefix + (is_last ? "    " : "│   ")
      node[:children].each_with_index do |child, idx|
        is_child_last = idx == node[:children].size - 1
        result << format_tree(child, new_prefix, is_child_last)
      end
    end

    result.join("\n")
  end

  def format_size(bytes)
    return "0 B" if bytes.nil? || bytes.zero?

    units = ["B", "KB", "MB", "GB"]
    unit_index = 0

    size = bytes.to_f
    while size >= 1024 && unit_index < units.size - 1
      size /= 1024
      unit_index += 1
    end

    if unit_index.zero?
      "#{size.to_i} #{units[unit_index]}"
    else
      "#{size.round(1)} #{units[unit_index]}"
    end
  end

  def count_files(node)
    return 0 if node.nil?
    return 1 if node[:type] == :file

    (node[:children] || []).sum { |child| count_files(child) }
  end

  def count_directories(node)
    return 0 if node.nil?
    return 0 if node[:type] == :file

    1 + (node[:children] || []).sum { |child| count_directories(child) }
  end
end

# Register with ToolCallService
ToolCallService.register_tool(FileTreeTool)

