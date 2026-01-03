# frozen_string_literal: true

# Domain model representing a chat message in an agent conversation.
# Can be from user or agent, includes thoughts if present.
#
# Strict OOP principles:
# - Immutable value object
# - Validation in constructor
# - No hash access patterns
class ChatMessage
  attr_reader :id, :session_id, :role, :content, :thoughts, :timestamp, :metadata

  ROLE_USER = "user"
  ROLE_AGENT = "agent"
  ROLE_SYSTEM = "system"

  VALID_ROLES = [ROLE_USER, ROLE_AGENT, ROLE_SYSTEM].freeze

  # Initialize a new chat message
  # @param id [String] Unique message identifier
  # @param session_id [String] Session this message belongs to
  # @param role [String] Message role (user, agent, system)
  # @param content [String] Message content
  # @param thoughts [String, nil] Agent's reasoning (extracted from <think> tags)
  # @param timestamp [Time, String] Message timestamp
  # @param metadata [Hash] Additional metadata
  def initialize(id:, session_id:, role:, content:, thoughts: nil, timestamp:, metadata: {})
    raise ArgumentError, "id is required" if id.nil? || id.to_s.empty?
    raise ArgumentError, "session_id is required" if session_id.nil? || session_id.to_s.empty?
    raise ArgumentError, "role is required" if role.nil? || role.to_s.empty?
    raise ArgumentError, "Invalid role: #{role}" unless VALID_ROLES.include?(role.to_s)
    raise ArgumentError, "content is required" if content.nil?
    raise ArgumentError, "timestamp is required" if timestamp.nil?
    raise ArgumentError, "metadata must be a Hash" unless metadata.nil? || metadata.is_a?(Hash)

    @id = id.to_s
    @session_id = session_id.to_s
    @role = role.to_s
    @content = content.to_s
    @thoughts = thoughts&.to_s
    @timestamp = parse_time(timestamp)
    @metadata = (metadata || {}).dup.freeze
    
    freeze
  end

  # Check if message is from user
  # @return [Boolean]
  def user?
    @role == ROLE_USER
  end

  # Check if message is from agent
  # @return [Boolean]
  def agent?
    @role == ROLE_AGENT
  end

  # Check if message is system message
  # @return [Boolean]
  def system?
    @role == ROLE_SYSTEM
  end

  # Check if message has thoughts
  # @return [Boolean]
  def has_thoughts?
    !@thoughts.nil? && !@thoughts.empty?
  end

  # Serialize to hash for API responses
  # @return [Hash]
  def to_h
    {
      id: @id,
      session_id: @session_id,
      role: @role,
      content: @content,
      thoughts: @thoughts,
      timestamp: @timestamp.iso8601,
      metadata: @metadata
    }
  end
  alias_method :to_json, :to_h

  # Create message from hash
  # @param data [Hash] Message data
  # @return [ChatMessage]
  def self.from_h(data)
    raise ArgumentError, "data must be a Hash" unless data.is_a?(Hash)
    
    new(
      id: data[:id] || data["id"],
      session_id: data[:session_id] || data["session_id"],
      role: data[:role] || data["role"],
      content: data[:content] || data["content"],
      thoughts: data[:thoughts] || data["thoughts"],
      timestamp: data[:timestamp] || data["timestamp"],
      metadata: data[:metadata] || data["metadata"] || {}
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








