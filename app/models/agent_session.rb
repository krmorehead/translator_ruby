# frozen_string_literal: true

# Domain model representing an agent's conversation session.
# Tracks chat messages, thoughts, memory state, and context.
#
# Strict OOP principles:
# - Immutable value object
# - Validation in constructor
# - No hash access patterns
class AgentSession
  attr_reader :session_id, :owner_id, :agent_type, :project_path, :started_at, :last_activity_at, :status, :config_overrides

  STATUS_ACTIVE = "active"
  STATUS_PAUSED = "paused"
  STATUS_COMPLETE = "complete"
  STATUS_FAILED = "failed"

  VALID_STATUSES = [STATUS_ACTIVE, STATUS_PAUSED, STATUS_COMPLETE, STATUS_FAILED].freeze
  
  AGENT_TYPE_DAEDALUS = "daedalus"
  AGENT_TYPE_SISYPHUS = "sisyphus"
  AGENT_TYPE_RESEARCHER = "researcher"
  
  VALID_AGENT_TYPES = [AGENT_TYPE_DAEDALUS, AGENT_TYPE_SISYPHUS, AGENT_TYPE_RESEARCHER].freeze

  # Initialize a new agent session
  # @param session_id [String] Unique session identifier
  # @param owner_id [String] Owner/user identifier
  # @param agent_type [String] Type of agent (daedalus, sisyphus, etc.)
  # @param project_path [String, nil] Path to the project/codebase
  # @param started_at [Time, String] Session start time
  # @param last_activity_at [Time, String] Last activity timestamp
  # @param status [String] Current session status
  # @param config_overrides [Hash] LLM configuration overrides for this session
  def initialize(session_id:, owner_id:, agent_type:, started_at:, last_activity_at:, status:, project_path: nil, config_overrides: {})
    raise ArgumentError, "session_id is required" if session_id.nil? || session_id.to_s.empty?
    raise ArgumentError, "owner_id is required" if owner_id.nil? || owner_id.to_s.empty?
    raise ArgumentError, "agent_type is required" if agent_type.nil? || agent_type.to_s.empty?
    raise ArgumentError, "Invalid agent_type: #{agent_type}" unless VALID_AGENT_TYPES.include?(agent_type.to_s)
    raise ArgumentError, "Invalid status: #{status}" unless VALID_STATUSES.include?(status.to_s)
    raise ArgumentError, "started_at is required" if started_at.nil?
    raise ArgumentError, "last_activity_at is required" if last_activity_at.nil?
    raise ArgumentError, "project_path must be a String or nil" if !project_path.nil? && !project_path.is_a?(String)
    raise ArgumentError, "config_overrides must be a Hash" unless config_overrides.is_a?(Hash)

    @session_id = session_id.to_s
    @owner_id = owner_id.to_s
    @agent_type = agent_type.to_s
    @project_path = project_path&.to_s
    @started_at = parse_time(started_at)
    @last_activity_at = parse_time(last_activity_at)
    @status = status.to_s
    @config_overrides = config_overrides.deep_dup.freeze
    
    freeze
  end

  # Check if session is active
  # @return [Boolean]
  def active?
    @status == STATUS_ACTIVE
  end

  # Check if session is complete
  # @return [Boolean]
  def complete?
    @status == STATUS_COMPLETE
  end

  # Check if session is paused
  # @return [Boolean]
  def paused?
    @status == STATUS_PAUSED
  end

  # Check if session failed
  # @return [Boolean]
  def failed?
    @status == STATUS_FAILED
  end

  # Update last activity timestamp
  # Returns a NEW instance (immutable)
  # @param timestamp [Time, String] New timestamp
  # @return [AgentSession] New instance with updated timestamp
  def touch(timestamp = Time.now.utc)
    self.class.new(
      session_id: @session_id,
      owner_id: @owner_id,
      agent_type: @agent_type,
      project_path: @project_path,
      started_at: @started_at,
      last_activity_at: timestamp,
      status: @status,
      config_overrides: @config_overrides
    )
  end

  # Update session status
  # Returns a NEW instance (immutable)
  # @param new_status [String] New status
  # @return [AgentSession] New instance with updated status
  def with_status(new_status)
    raise ArgumentError, "Invalid status: #{new_status}" unless VALID_STATUSES.include?(new_status.to_s)
    
    self.class.new(
      session_id: @session_id,
      owner_id: @owner_id,
      agent_type: @agent_type,
      project_path: @project_path,
      started_at: @started_at,
      last_activity_at: Time.now.utc,
      status: new_status,
      config_overrides: @config_overrides
    )
  end

  # Update config overrides
  # Returns a NEW instance (immutable)
  # @param overrides [Hash] New config overrides
  # @return [AgentSession] New instance with updated config
  def with_config_overrides(overrides)
    raise ArgumentError, "overrides must be a Hash" unless overrides.is_a?(Hash)
    
    self.class.new(
      session_id: @session_id,
      owner_id: @owner_id,
      agent_type: @agent_type,
      project_path: @project_path,
      started_at: @started_at,
      last_activity_at: Time.now.utc,
      status: @status,
      config_overrides: overrides
    )
  end

  # Update project path
  # Returns a NEW instance (immutable)
  # @param new_path [String, nil] New project path
  # @return [AgentSession] New instance with updated project path
  def with_project_path(new_path)
    raise ArgumentError, "project_path must be a String or nil" if !new_path.nil? && !new_path.is_a?(String)
    
    self.class.new(
      session_id: @session_id,
      owner_id: @owner_id,
      agent_type: @agent_type,
      project_path: new_path,
      started_at: @started_at,
      last_activity_at: Time.now.utc,
      status: @status,
      config_overrides: @config_overrides
    )
  end

  # Serialize to hash for API responses
  # @return [Hash]
  def to_h
    {
      session_id: @session_id,
      owner_id: @owner_id,
      agent_type: @agent_type,
      project_path: @project_path,
      started_at: @started_at.iso8601,
      last_activity_at: @last_activity_at.iso8601,
      status: @status,
      config_overrides: @config_overrides
    }
  end
  alias_method :to_json, :to_h

  # Create session from hash
  # @param data [Hash] Session data
  # @return [AgentSession]
  def self.from_h(data)
    raise ArgumentError, "data must be a Hash" unless data.is_a?(Hash)
    
    new(
      session_id: data[:session_id] || data["session_id"],
      owner_id: data[:owner_id] || data["owner_id"],
      agent_type: data[:agent_type] || data["agent_type"],
      project_path: data[:project_path] || data["project_path"],
      started_at: data[:started_at] || data["started_at"],
      last_activity_at: data[:last_activity_at] || data["last_activity_at"],
      status: data[:status] || data["status"],
      config_overrides: data[:config_overrides] || data["config_overrides"] || {}
    )
  end

  private

  # Parse time from various formats
  # @param value [Time, String, Integer] Time value
  # @return [Time]
  def parse_time(value)
    return value if value.is_a?(Time)
    return Time.at(value) if value.is_a?(Integer)
    return Time.parse(value) if value.is_a?(String)
    raise ArgumentError, "Invalid time value: #{value}"
  end
end








