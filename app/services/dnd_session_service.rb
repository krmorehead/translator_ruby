# frozen_string_literal: true

# Service for managing D&D game sessions
# Maintains a map of active sessions and provides lookup/creation
module DndSessionService
  extend self

  @sessions = {}
  @mutex = Mutex.new

  # Create a new session
  # @param session_id [String, nil] Optional session ID (generates if nil)
  # @return [DndSession] New session instance
  def create_session(session_id: nil)
    session_id ||= SecureRandom.uuid

    @mutex.synchronize do
      raise ArgumentError, "Session #{session_id} already exists" if @sessions.key?(session_id)

      session = DndSession.new(session_id: session_id)
      @sessions[session_id] = session
      session
    end
  end

  # Find a session by ID, loading if needed
  # @param session_id [String] Session identifier
  # @return [DndSession, nil] Session instance or nil if not found
  def find_session(session_id)
    @mutex.synchronize do
      # Return cached session if exists
      return @sessions[session_id] if @sessions.key?(session_id)

      # Try to load - DndSession initialization will load from MemoryStore
      session = DndSession.new(session_id: session_id)
      if session.exists?
        @sessions[session_id] = session
        session
      else
        nil
      end
    rescue => e
      Rails.logger.warn("Failed to load session #{session_id}: #{e.message}")
      nil
    end
  end

  # Find a session by ID, raising if not found
  # @param session_id [String] Session identifier
  # @return [DndSession] Session instance
  # @raise [ArgumentError] If session not found
  def find_session!(session_id)
    find_session(session_id) || raise(ArgumentError, "Session not found: #{session_id}")
  end

  # Remove session from cache (doesn't delete from disk)
  # @param session_id [String] Session identifier
  def evict_session(session_id)
    @mutex.synchronize do
      @sessions.delete(session_id)
    end
  end

  # Get count of active sessions in memory
  # @return [Integer] Number of cached sessions
  def active_session_count
    @mutex.synchronize { @sessions.size }
  end

  # Clear all cached sessions (doesn't delete from disk)
  def clear_cache
    @mutex.synchronize do
      @sessions.clear
    end
  end
end

