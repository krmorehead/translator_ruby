# frozen_string_literal: true

# Domain object representing changes to a single file.
# Provides structured diff information instead of raw strings.
#
# @example Creating a file diff
#   diff = FileDiff.new(
#     file_path: "app/models/user.rb",
#     change_type: :modified,
#     insertions: 5,
#     deletions: 3,
#     diff_content: "--- a/app/models/user.rb\n+++ b/app/models/user.rb\n..."
#   )
#
# @example Checking changes
#   diff.changed?         # => true
#   diff.lines_changed    # => 8
#   diff.change_summary   # => "+5 -3"
class FileDiff
  # Valid change types for file modifications
  CHANGE_TYPES = [
    ADDED = :added,
    MODIFIED = :modified,
    DELETED = :deleted
  ].freeze

  attr_reader :file_path, :change_type, :insertions, :deletions, :diff_content, :is_binary

  # Initialize a new FileDiff
  #
  # @param file_path [String] Path to the file
  # @param change_type [Symbol] Type of change (:added, :modified, :deleted)
  # @param insertions [Integer] Number of lines added
  # @param deletions [Integer] Number of lines removed
  # @param diff_content [String, nil] Unified diff content
  # @param is_binary [Boolean] Whether file is binary
  # @raise [ArgumentError] If required parameters are invalid
  def initialize(file_path:, change_type:, insertions: 0, deletions: 0, diff_content: nil, is_binary: false)
    validate_params!(file_path, change_type, insertions, deletions, diff_content, is_binary)
    
    @file_path = file_path
    @change_type = change_type
    @insertions = insertions
    @deletions = deletions
    @diff_content = diff_content
    @is_binary = is_binary
  end

  # Check if file has changes
  # @return [Boolean] True if any lines added or removed
  def changed?
    insertions > 0 || deletions > 0
  end

  # Calculate total lines changed
  # @return [Integer] Sum of insertions and deletions
  def lines_changed
    insertions + deletions
  end

  # Generate human-readable change summary
  # @return [String] Summary like "+5 -3" or "Binary file"
  def change_summary
    return "Binary file" if is_binary
    return "No changes" unless changed?
    
    "+#{insertions} -#{deletions}"
  end

  # Check if file was added
  # @return [Boolean] True if change_type is :added
  def added?
    change_type == ADDED
  end

  # Check if file was modified
  # @return [Boolean] True if change_type is :modified
  def modified?
    change_type == MODIFIED
  end

  # Check if file was deleted
  # @return [Boolean] True if change_type is :deleted
  def deleted?
    change_type == DELETED
  end

  # Convert to hash for serialization
  # @return [Hash] Hash representation
  def to_h
    {
      file_path: file_path,
      change_type: change_type,
      insertions: insertions,
      deletions: deletions,
      diff_content: diff_content,
      is_binary: is_binary
    }
  end

  # Reconstruct FileDiff from hash
  # @param hash [Hash] Hash with file diff data
  # @return [FileDiff] New FileDiff instance
  # @raise [ArgumentError] If hash is invalid
  def self.from_h(hash)
    raise ArgumentError, "hash is required" if hash.nil?
    raise ArgumentError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)
    
    # Symbolize keys if needed
    hash = hash.transform_keys(&:to_sym) if hash.keys.first.is_a?(String)
    
    new(
      file_path: hash[:file_path],
      change_type: hash[:change_type]&.to_sym,
      insertions: hash[:insertions] || 0,
      deletions: hash[:deletions] || 0,
      diff_content: hash[:diff_content],
      is_binary: hash[:is_binary] || false
    )
  end

  # Parse git diff output into FileDiff object
  # @param diff_output [String] Git diff output
  # @param file_path [String] Path to the file
  # @return [FileDiff] Parsed FileDiff object
  def self.from_git_diff(diff_output, file_path: nil)
    raise ArgumentError, "diff_output is required" if diff_output.nil?
    raise ArgumentError, "diff_output must be a String, got #{diff_output.class}" unless diff_output.is_a?(String)
    
    # Extract file path from diff if not provided
    file_path ||= extract_file_path(diff_output)
    
    # Determine change type
    change_type = determine_change_type(diff_output)
    
    # Check if binary
    is_binary = diff_output.include?("Binary files")
    
    # Calculate stats if not binary
    if is_binary
      insertions = 0
      deletions = 0
    else
      stats = calculate_stats(diff_output)
      insertions = stats[:insertions]
      deletions = stats[:deletions]
    end
    
    new(
      file_path: file_path,
      change_type: change_type,
      insertions: insertions,
      deletions: deletions,
      diff_content: diff_output,
      is_binary: is_binary
    )
  end

  private

  def validate_params!(file_path, change_type, insertions, deletions, diff_content, is_binary)
    # Validate file_path
    raise ArgumentError, "file_path must be a String, got #{file_path.class}" unless file_path.is_a?(String)
    raise ArgumentError, "file_path cannot be empty" if file_path.empty?
    
    # Validate change_type
    raise ArgumentError, "change_type must be a Symbol, got #{change_type.class}" unless change_type.is_a?(Symbol)
    unless CHANGE_TYPES.include?(change_type)
      raise ArgumentError, "Invalid change_type: #{change_type}. Must be one of: #{CHANGE_TYPES.join(', ')}"
    end
    
    # Validate insertions
    raise ArgumentError, "insertions must be an Integer, got #{insertions.class}" unless insertions.is_a?(Integer)
    raise ArgumentError, "insertions cannot be negative" if insertions < 0
    
    # Validate deletions
    raise ArgumentError, "deletions must be an Integer, got #{deletions.class}" unless deletions.is_a?(Integer)
    raise ArgumentError, "deletions cannot be negative" if deletions < 0
    
    # Validate diff_content
    unless diff_content.nil? || diff_content.is_a?(String)
      raise TypeError, "diff_content must be a String or nil, got #{diff_content.class}"
    end
    
    # Validate is_binary
    unless [true, false].include?(is_binary)
      raise ArgumentError, "is_binary must be a Boolean, got #{is_binary.class}"
    end
  end

  def self.extract_file_path(diff_output)
    # Look for +++ b/path or --- a/path
    if diff_output =~ /^\+\+\+ b\/(.+)$/
      $1
    elsif diff_output =~ /^--- a\/(.+)$/
      $1
    else
      "unknown"
    end
  end

  def self.determine_change_type(diff_output)
    if diff_output.include?("+++ /dev/null")
      DELETED
    elsif diff_output.include?("--- /dev/null")
      ADDED
    else
      MODIFIED
    end
  end

  def self.calculate_stats(diff_output)
    lines = diff_output.split("\n")
    
    insertions = lines.count do |line|
      line.start_with?("+") && !line.start_with?("+++")
    end
    
    deletions = lines.count do |line|
      line.start_with?("-") && !line.start_with?("---")
    end
    
    { insertions: insertions, deletions: deletions }
  end
end

