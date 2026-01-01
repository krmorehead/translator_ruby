# frozen_string_literal: true

# Domain object representing a Git checkpoint (commit) with metadata.
# Provides a structured interface to checkpoint data instead of raw hashes.
#
# @example Creating a checkpoint
#   checkpoint = Checkpoint.new(
#     id: "abc123...",
#     message: "Milestone 1 complete",
#     created_at: Time.now.utc,
#     metadata: { milestone_id: "m1", step_ids: ["s1", "s2"] },
#     files_changed: ["app/models/user.rb"]
#   )
#
# @example Accessing metadata
#   checkpoint.short_id       # => "abc123"
#   checkpoint.milestone_id   # => "m1"
#   checkpoint.file_count     # => 1
#   checkpoint.age            # => 3600.5 (seconds)
class Checkpoint
  attr_reader :id, :message, :created_at, :metadata, :files_changed, :author

  # Initialize a new Checkpoint
  #
  # @param id [String] Git commit hash (SHA-1)
  # @param message [String] Commit message
  # @param created_at [Time] When checkpoint was created
  # @param metadata [Hash] Additional metadata (milestone_id, step_ids, etc)
  # @param files_changed [Array<String>] List of file paths changed in this checkpoint
  # @param author [String, nil] Git author name
  # @raise [ArgumentError] If required parameters are invalid
  def initialize(id:, message:, created_at:, metadata: {}, files_changed: [], author: nil)
    validate_params!(id, message, created_at, metadata, files_changed)
    
    @id = id
    @message = message
    @created_at = created_at
    @metadata = metadata
    @files_changed = files_changed
    @author = author
  end

  # Get shortened commit hash (first 7 characters)
  # @return [String] Short ID
  def short_id
    id[0..6]
  end

  # Calculate time since checkpoint creation
  # @return [Float] Seconds since creation
  def age
    Time.now.utc - created_at
  end

  # Count of files changed in this checkpoint
  # @return [Integer] Number of files
  def file_count
    files_changed.size
  end

  # Extract milestone ID from metadata
  # @return [String, nil] Milestone ID if present
  def milestone_id
    metadata[:milestone_id]
  end

  # Extract step IDs from metadata
  # @return [Array<String>] Array of step IDs
  def step_ids
    metadata[:step_ids] || []
  end

  # Extract worker ID from metadata
  # @return [String, nil] Worker ID if present
  def worker_id
    metadata[:worker_id]
  end

  # Extract execution ID from metadata
  # @return [String, nil] Execution ID if present
  def execution_id
    metadata[:execution_id]
  end

  # Check if this is a backup checkpoint
  # @return [Boolean] True if backup
  def backup?
    metadata[:backup] == true
  end

  # Convert to hash for serialization
  # @return [Hash] Hash representation
  def to_h
    {
      id: id,
      message: message,
      created_at: created_at.iso8601,
      metadata: metadata,
      files_changed: files_changed,
      author: author
    }
  end

  # Reconstruct checkpoint from hash
  # @param hash [Hash] Hash with checkpoint data
  # @return [Checkpoint] New checkpoint instance
  # @raise [ArgumentError] If hash is invalid
  def self.from_h(hash)
    raise ArgumentError, "hash is required" if hash.nil?
    raise ArgumentError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)
    
    # Symbolize keys if needed
    hash = hash.transform_keys(&:to_sym) if hash.keys.first.is_a?(String)
    
    new(
      id: hash[:id],
      message: hash[:message],
      created_at: parse_time(hash[:created_at]),
      metadata: hash[:metadata] || {},
      files_changed: hash[:files_changed] || [],
      author: hash[:author]
    )
  end

  private

  def validate_params!(id, message, created_at, metadata, files_changed)
    # Validate id
    raise ArgumentError, "id must be a String, got #{id.class}" unless id.is_a?(String)
    raise ArgumentError, "id cannot be empty" if id.empty?
    
    # Validate message
    raise ArgumentError, "message must be a String, got #{message.class}" unless message.is_a?(String)
    
    # Validate created_at
    raise ArgumentError, "created_at must be a Time, got #{created_at.class}" unless created_at.is_a?(Time)
    
    # Validate metadata
    raise TypeError, "metadata must be a Hash, got #{metadata.class}" unless metadata.is_a?(Hash)
    
    # Validate files_changed
    raise TypeError, "files_changed must be an Array, got #{files_changed.class}" unless files_changed.is_a?(Array)
    unless files_changed.all? { |f| f.is_a?(String) }
      raise TypeError, "files_changed must contain only Strings, got #{files_changed.map(&:class).uniq.join(', ')}"
    end
  end

  def self.parse_time(time_value)
    case time_value
    when Time
      time_value
    when String
      Time.parse(time_value)
    else
      raise ArgumentError, "created_at must be a Time or String, got #{time_value.class}"
    end
  end
end

