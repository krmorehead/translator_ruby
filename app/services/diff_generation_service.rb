# frozen_string_literal: true

# Service for generating visual diffs for file changes during execution.
# Provides unified diff format with configurable context lines and
# multiple output formats (plain, markdown, HTML).
#
# @example Basic usage
#   service = DiffGenerationService.new
#   diff = service.generate_diff(
#     file_path: "app/models/user.rb",
#     old_content: "class User\nend",
#     new_content: "class User\n  def name\n  end\nend"
#   )
#
# @example Workspace diff from ChangeSet
#   workspace_diff = service.generate_workspace_diff(change_set)
#   stats = service.diff_stats(workspace_diff)
class DiffGenerationService
  # Default number of context lines to show around changes
  DEFAULT_CONTEXT_LINES = 3

  # Format options for display
  FORMATS = [:plain, :markdown, :html].freeze

  def initialize
    # Service is stateless, no instance variables needed
  end

  # Generate a diff for a single file change
  #
  # @param file_path [String] Path to the file (required)
  # @param old_content [String, nil] Content before change (nil for creation)
  # @param new_content [String, nil] Content after change (nil for deletion)
  # @param context_lines [Integer] Number of context lines (default: 3)
  # @return [FileDiff] FileDiff object with structured diff information
  # @raise [ArgumentError] If file_path missing or invalid parameters
  def generate_diff(file_path:, old_content:, new_content:, context_lines: DEFAULT_CONTEXT_LINES)
    validate_diff_params!(file_path, old_content, new_content)

    # Check if binary
    is_binary = binary_content?(old_content) || binary_content?(new_content)

    # Determine change type
    change_type = if new_content.nil?
      FileDiff::DELETED
    elsif old_content.nil? || old_content.empty?
      FileDiff::ADDED
    else
      FileDiff::MODIFIED
    end

    # Generate diff content
    if is_binary
      diff_content = generate_binary_diff_content(file_path, old_content, new_content)
      insertions = 0
      deletions = 0
    else
      diff_content = case change_type
      when FileDiff::DELETED
        generate_deletion_diff(file_path, old_content)
      when FileDiff::ADDED
        generate_creation_diff(file_path, new_content)
      else
        generate_modification_diff(file_path, old_content, new_content, context_lines)
      end

      # Calculate stats
      stats = calculate_diff_stats(diff_content)
      insertions = stats[:insertions]
      deletions = stats[:deletions]
    end

    FileDiff.new(
      file_path: file_path,
      change_type: change_type,
      insertions: insertions,
      deletions: deletions,
      diff_content: diff_content,
      is_binary: is_binary
    )
  end

  # Generate a workspace-wide diff from a ChangeSet
  #
  # @param change_set [Execution::ChangeSet] ChangeSet containing file changes
  # @return [String] Combined diff for all files
  # @raise [ArgumentError] If change_set is nil
  # @raise [TypeError] If change_set is not a ChangeSet
  def generate_workspace_diff(change_set)
    raise ArgumentError, "change_set is required" if change_set.nil?
    raise TypeError, "change_set must be an Execution::ChangeSet, got #{change_set.class}" unless change_set.is_a?(Execution::ChangeSet)

    return "" if change_set.files.empty?

    # Combine all file diffs
    change_set.files.map do |file_path, file_info|
      file_info[:diff]
    end.join("\n")
  end
  
  # Calculate statistics for a diff, with special handling for workspace diffs from ChangeSets
  #
  # @param diff [String, FileDiff, Execution::ChangeSet, Array<FileDiff>] Diff content or objects
  # @return [Hash] Statistics with :lines_added, :lines_removed, :files_changed
  def diff_stats(diff)
    # Handle FileDiff object
    if diff.is_a?(FileDiff)
      return {
        lines_added: diff.insertions,
        lines_removed: diff.deletions,
        files_changed: 1
      }
    end
    
    # Handle Array of FileDiff objects
    if diff.is_a?(Array) && diff.all? { |d| d.is_a?(FileDiff) }
      return {
        lines_added: diff.sum(&:insertions),
        lines_removed: diff.sum(&:deletions),
        files_changed: diff.size
      }
    end
    
    # Handle ChangeSet directly
    if diff.is_a?(Execution::ChangeSet)
      files_changed = diff.files.size
      lines_added = 0
      lines_removed = 0
      
      diff.files.each do |_path, file_info|
        file_diff = file_info[:diff]
        lines_added += file_diff.scan(/^\+/).count { |m| !m.start_with?("+++") }
        lines_removed += file_diff.scan(/^-/).count { |m| !m.start_with?("---") }
      end
      
      return {
        lines_added: lines_added,
        lines_removed: lines_removed,
        files_changed: files_changed
      }
    end
    
    # Handle string diff
    return { lines_added: 0, lines_removed: 0, files_changed: 0 } if diff.nil? || diff.empty?

    lines = diff.split("\n")
    # Only count actual content lines (not headers like +++, ---, @@)
    added = lines.count do |line|
      line.start_with?("+") && !line.start_with?("+++")
    end
    removed = lines.count do |line|
      line.start_with?("-") && !line.start_with?("---")
    end
    files = count_files_in_diff(diff)

    {
      lines_added: added,
      lines_removed: removed,
      files_changed: files
    }
  end

  # Format a diff for display in different formats
  #
  # @param diff [String] Raw diff content
  # @param format [Symbol] Output format (:plain, :markdown, :html)
  # @return [String] Formatted diff
  def format_for_display(diff, format: :plain)
    raise ArgumentError, "Invalid format: #{format}. Must be one of: #{FORMATS.join(', ')}" unless FORMATS.include?(format)

    case format
    when :markdown
      format_markdown(diff)
    when :html
      format_html(diff)
    else
      diff # :plain returns as-is
    end
  end

  private

  # Validation
  def validate_diff_params!(file_path, old_content, new_content)
    raise ArgumentError, "file_path is required" if file_path.nil? || file_path.empty?

    # At least one content must be provided
    if old_content.nil? && new_content.nil?
      raise ArgumentError, "At least one of old_content or new_content must be provided"
    end

    # For deletion (new_content is nil), old_content is required
    if new_content.nil? && (old_content.nil? || old_content.empty?)
      raise ArgumentError, "new_content is required (unless this is a deletion with old_content)"
    end
  end

  # Binary detection
  def binary_content?(content)
    return false if content.nil? || content.empty?
    
    # Check for null bytes or non-printable characters
    content.encoding == Encoding::ASCII_8BIT || content.bytes.any? { |b| b < 9 || (b > 13 && b < 32 && b != 27) }
  end

  # Diff generation methods
  def generate_binary_diff_content(file_path, old_content, new_content)
    if new_content.nil?
      "Binary file #{file_path} deleted\n"
    elsif old_content.nil?
      "Binary file #{file_path} created\n"
    else
      "Binary file #{file_path} modified\n"
    end
  end
  
  def calculate_diff_stats(diff_content)
    lines = diff_content.split("\n")
    
    insertions = lines.count do |line|
      line.start_with?("+") && !line.start_with?("+++")
    end
    
    deletions = lines.count do |line|
      line.start_with?("-") && !line.start_with?("---")
    end
    
    { insertions: insertions, deletions: deletions }
  end

  def generate_deletion_diff(file_path, old_content)
    lines = old_content.split("\n", -1)
    
    diff_lines = [
      "--- a/#{file_path}",
      "+++ /dev/null",
      "@@ -1,#{lines.size} +0,0 @@"
    ]
    
    lines.each do |line|
      diff_lines << "-#{line}"
    end
    
    diff_lines.join("\n") + "\n"
  end

  def generate_creation_diff(file_path, new_content)
    lines = new_content.split("\n", -1)
    
    diff_lines = [
      "--- /dev/null",
      "+++ b/#{file_path}",
      "@@ -0,0 +1,#{lines.size} @@"
    ]
    
    lines.each do |line|
      diff_lines << "+#{line}"
    end
    
    diff_lines.join("\n") + "\n"
  end

  def generate_modification_diff(file_path, old_content, new_content, context_lines)
    # If content is identical, return minimal diff
    return "" if old_content == new_content
    
    old_lines = old_content.split("\n", -1)
    new_lines = new_content.split("\n", -1)

    # Simple line-by-line diff algorithm
    diff_lines = [
      "--- a/#{file_path}",
      "+++ b/#{file_path}"
    ]

    # Find differences
    changes = compute_changes(old_lines, new_lines)
    
    return diff_lines.join("\n") + "\n" if changes.empty?

    # Generate hunks with context
    hunks = generate_hunks(old_lines, new_lines, changes, context_lines)
    
    diff_lines.concat(hunks)
    diff_lines.join("\n") + "\n"
  end

  def compute_changes(old_lines, new_lines)
    changes = []
    max_len = [old_lines.size, new_lines.size].max
    
    (0...max_len).each do |i|
      old_line = old_lines[i]
      new_line = new_lines[i]
      
      if old_line != new_line
        changes << i
      end
    end
    
    changes
  end

  def generate_hunks(old_lines, new_lines, changes, context_lines)
    return [] if changes.empty?

    hunks = []
    
    # Group changes into hunks
    hunk_ranges = group_changes_into_hunks(changes, context_lines)
    
    hunk_ranges.each do |range_start, range_end|
      # Expand range to include context
      hunk_start = [range_start - context_lines, 0].max
      hunk_end = [range_end + context_lines, [old_lines.size, new_lines.size].max - 1].min
      
      old_start = hunk_start + 1
      old_count = [hunk_end - hunk_start + 1, old_lines.size - hunk_start].min
      new_start = hunk_start + 1
      new_count = [hunk_end - hunk_start + 1, new_lines.size - hunk_start].min
      
      hunks << "@@ -#{old_start},#{old_count} +#{new_start},#{new_count} @@"
      
      # Add lines in hunk
      (hunk_start..hunk_end).each do |i|
        old_line = old_lines[i]
        new_line = new_lines[i]
        
        if old_line == new_line && old_line
          # Context line (unchanged)
          hunks << " #{old_line}"
        elsif old_line && new_line && old_line != new_line
          # Modified line - show both removal and addition
          hunks << "-#{old_line}"
          hunks << "+#{new_line}"
        elsif old_line
          # Only in old (deletion)
          hunks << "-#{old_line}"
        elsif new_line
          # Only in new (addition)
          hunks << "+#{new_line}"
        end
      end
    end
    
    hunks
  end

  def group_changes_into_hunks(changes, context_lines)
    return [] if changes.empty?

    ranges = []
    current_start = changes.first
    current_end = changes.first
    
    changes.each_with_index do |change, idx|
      next if idx == 0
      
      # If this change is far from the last, start a new hunk
      if change - current_end > (context_lines * 2 + 1)
        ranges << [current_start, current_end]
        current_start = change
        current_end = change
      else
        current_end = change
      end
    end
    
    ranges << [current_start, current_end]
    ranges
  end

  # Formatting methods
  def format_markdown(diff)
    "```diff\n#{diff}```\n"
  end

  def format_html(diff)
    lines = diff.split("\n")
    html_lines = lines.map do |line|
      style = if line.start_with?("+") && !line.start_with?("+++")
        "color: green;"
      elsif line.start_with?("-") && !line.start_with?("---")
        "color: red;"
      elsif line.start_with?("@@")
        "color: cyan;"
      else
        ""
      end
      
      escaped = CGI.escapeHTML(line)
      if style.empty?
        escaped
      else
        "<span style=\"#{style}\">#{escaped}</span>"
      end
    end
    
    "<pre>#{html_lines.join("\n")}</pre>"
  end

  # Count files in a diff by looking for --- and +++ headers
  # If no headers found, count by number of file entries
  def count_files_in_diff(diff)
    header_count = diff.scan(/^---/).size
    # If we have file headers, use that count
    return header_count if header_count > 0
    
    # Otherwise try to count unique file mentions
    # This handles cases where diffs don't have proper headers
    0
  end
end

