# frozen_string_literal: true

# Service for managing agent sessions, conversations, and memory access.
# All data stored in-memory by session_id.
# No filesystem persistence needed.
#
# Follows service object pattern with real domain objects (no hashes).
class AgentSessionService
  attr_reader :owner_id

  # Class-level storage for sessions and messages
  @@sessions = {}      # session_id => AgentSession
  @@messages = {}      # session_id => Array<Hash>
  @@lock = Mutex.new

  # Initialize service for a specific owner
  # @param owner_id [String] Owner identifier
  def initialize(owner_id:)
    raise ArgumentError, "owner_id is required" if owner_id.nil? || owner_id.to_s.empty?
    
    @owner_id = owner_id.to_s
  end

  # Create new session
  # @param agent_type [String] Agent type
  # @return [AgentSession]
  def create_session(agent_type:)
    raise ArgumentError, "Invalid agent_type" unless AgentSession::VALID_AGENT_TYPES.include?(agent_type.to_s)
    
    session_id = SecureRandom.uuid
    now = Time.now.utc
    session = AgentSession.new(
      session_id: session_id,
      owner_id: @owner_id,
      agent_type: agent_type.to_s,
      status: AgentSession::STATUS_ACTIVE,
      started_at: now,
      last_activity_at: now
    )
    
    @@lock.synchronize do
      @@sessions[session_id] = session
      @@messages[session_id] = []
    end
    
    session
  end
  
  # Get session by ID
  # @param session_id [String] Session identifier
  # @return [AgentSession, nil]
  def get_session(session_id:)
    @@sessions[session_id]
  end

  # Get conversation history for a session
  # @param session_id [String] Session identifier
  # @param limit [Integer] Maximum number of messages to return
  # @return [Array<ChatMessage>]
  def get_conversation(session_id:, limit: 100)
    raise ArgumentError, "session_id is required" if session_id.nil? || session_id.to_s.empty?
    raise ArgumentError, "limit must be positive" unless limit.positive?
    
    messages = @@messages[session_id] || []
    messages.last(limit).map { |data| ChatMessage.from_h(data) }
  end

  # Add message to conversation
  # @param session_id [String] Session identifier
  # @param role [String] Message role
  # @param content [String] Message content
  # @param thoughts [String, nil] Agent thoughts
  # @param metadata [Hash] Additional metadata
  # @return [ChatMessage]
  def add_message(session_id:, role:, content:, thoughts: nil, metadata: {})
    message = ChatMessage.new(
      id: SecureRandom.uuid,
      session_id: session_id,
      role: role,
      content: content,
      thoughts: thoughts,
      timestamp: Time.now.utc,
      metadata: metadata
    )
    
    @@lock.synchronize do
      @@messages[session_id] ||= []
      @@messages[session_id] << message.to_h
    end
    
    update_session_activity(session_id)
    
    message
  end

  # Get memory sections for an owner
  # @param agent_type [String] Agent type
  # @return [Array<MemorySection>]
  def get_memory_sections(agent_type:)
    # Memory can still be file-based or in-memory depending on implementation
    # For now, return empty array
    []
  end

  # Get specific memory section
  # @param agent_type [String] Agent type
  # @param section_name [String, Symbol] Section name
  # @return [MemorySection, nil]
  def get_memory_section(agent_type:, section_name:)
    nil
  end

  # Clear memory section
  # @param agent_type [String] Agent type
  # @param section_name [String, Symbol] Section name
  # @return [Boolean] Success status
  def clear_memory_section(agent_type:, section_name:)
    true
  end

  # Get thoughts timeline (extracted reasoning from agent messages)
  # @param session_id [String] Session identifier
  # @param limit [Integer] Maximum number of thoughts to return
  # @return [Array<Hash>] Thought entries with timestamps
  def get_thoughts_timeline(session_id:, limit: 50)
    messages = @@messages[session_id] || []
    
    messages
      .select { |msg| msg[:role] == ChatMessage::ROLE_AGENT && msg[:thoughts].present? }
      .last(limit)
      .map do |msg|
        {
          id: msg[:id],
          timestamp: msg[:timestamp],
          thoughts: msg[:thoughts],
          message_content: msg[:content]
        }
      end
  end

  # Get action history for an agent
  # @param agent_type [String] Agent type
  # @param limit [Integer] Maximum number of actions to return
  # @return [Array<Hash>] Action entries
  def get_action_history(agent_type:, limit: 100)
    []
  end

  private

  # Update session activity timestamp
  # @param session_id [String]
  def update_session_activity(session_id)
    @@lock.synchronize do
      session = @@sessions[session_id]
      return unless session
      
      # Create new session with updated timestamp (immutable)
      updated_session = session.touch
      @@sessions[session_id] = updated_session
    end
  end
end

