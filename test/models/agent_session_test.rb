# frozen_string_literal: true

require "test_helper"

class AgentSessionTest < ActiveSupport::TestCase
  speed_profile :fast
  test "creates valid session with all required fields" do
    session = AgentSession.new(
      session_id: "session-123",
      owner_id: "owner-456",
      agent_type: AgentSession::AGENT_TYPE_DAEDALUS,
      started_at: Time.now.utc,
      last_activity_at: Time.now.utc,
      status: AgentSession::STATUS_ACTIVE
    )

    assert_equal "session-123", session.session_id
    assert_equal "owner-456", session.owner_id
    assert_equal AgentSession::AGENT_TYPE_DAEDALUS, session.agent_type
    assert_equal AgentSession::STATUS_ACTIVE, session.status
  end

  speed_profile :fast
  test "is immutable after creation" do
    session = build_session

    assert session.frozen?
  end

  speed_profile :fast
  test "validates session_id is required" do
    error = assert_raises(ArgumentError) do
      AgentSession.new(
        session_id: nil,
        owner_id: "owner-456",
        agent_type: AgentSession::AGENT_TYPE_DAEDALUS,
        started_at: Time.now.utc,
        last_activity_at: Time.now.utc,
        status: AgentSession::STATUS_ACTIVE
      )
    end

    assert_match(/session_id is required/, error.message)
  end

  speed_profile :fast
  test "validates owner_id is required" do
    error = assert_raises(ArgumentError) do
      AgentSession.new(
        session_id: "session-123",
        owner_id: nil,
        agent_type: AgentSession::AGENT_TYPE_DAEDALUS,
        started_at: Time.now.utc,
        last_activity_at: Time.now.utc,
        status: AgentSession::STATUS_ACTIVE
      )
    end

    assert_match(/owner_id is required/, error.message)
  end

  speed_profile :fast
  test "validates agent_type is valid" do
    error = assert_raises(ArgumentError) do
      AgentSession.new(
        session_id: "session-123",
        owner_id: "owner-456",
        agent_type: "invalid_type",
        started_at: Time.now.utc,
        last_activity_at: Time.now.utc,
        status: AgentSession::STATUS_ACTIVE
      )
    end

    assert_match(/Invalid agent_type/, error.message)
  end

  speed_profile :fast
  test "validates status is valid" do
    error = assert_raises(ArgumentError) do
      AgentSession.new(
        session_id: "session-123",
        owner_id: "owner-456",
        agent_type: AgentSession::AGENT_TYPE_DAEDALUS,
        started_at: Time.now.utc,
        last_activity_at: Time.now.utc,
        status: "invalid_status"
      )
    end

    assert_match(/Invalid status/, error.message)
  end

  speed_profile :fast
  test "active? returns true for active status" do
    session = build_session(status: AgentSession::STATUS_ACTIVE)
    assert session.active?
  end

  speed_profile :fast
  test "complete? returns true for complete status" do
    session = build_session(status: AgentSession::STATUS_COMPLETE)
    assert session.complete?
  end

  speed_profile :fast
  test "paused? returns true for paused status" do
    session = build_session(status: AgentSession::STATUS_PAUSED)
    assert session.paused?
  end

  speed_profile :fast
  test "failed? returns true for failed status" do
    session = build_session(status: AgentSession::STATUS_FAILED)
    assert session.failed?
  end

  speed_profile :fast
  test "touch returns new instance with updated timestamp" do
    session = build_session
    original_time = session.last_activity_at
    
    sleep 0.01 # Ensure time difference
    updated_session = session.touch

    assert_instance_of AgentSession, updated_session
    refute_equal session.object_id, updated_session.object_id
    assert updated_session.last_activity_at > original_time
    assert_equal session.session_id, updated_session.session_id
  end

  speed_profile :fast
  test "with_status returns new instance with updated status" do
    session = build_session(status: AgentSession::STATUS_ACTIVE)
    
    updated_session = session.with_status(AgentSession::STATUS_COMPLETE)

    assert_instance_of AgentSession, updated_session
    refute_equal session.object_id, updated_session.object_id
    assert updated_session.complete?
    refute session.complete?
  end

  speed_profile :fast
  test "to_h serializes to hash correctly" do
    started = Time.now.utc
    session = build_session(started_at: started, last_activity_at: started)
    
    hash = session.to_h

    assert_equal "session-123", hash[:session_id]
    assert_equal "owner-456", hash[:owner_id]
    assert_equal AgentSession::AGENT_TYPE_DAEDALUS, hash[:agent_type]
    assert_equal started.iso8601, hash[:started_at]
    assert_equal AgentSession::STATUS_ACTIVE, hash[:status]
  end

  speed_profile :fast
  test "from_h creates session from hash" do
    hash = {
      session_id: "session-789",
      owner_id: "owner-abc",
      agent_type: AgentSession::AGENT_TYPE_SISYPHUS,
      started_at: Time.now.utc.iso8601,
      last_activity_at: Time.now.utc.iso8601,
      status: AgentSession::STATUS_PAUSED
    }

    session = AgentSession.from_h(hash)

    assert_equal "session-789", session.session_id
    assert_equal "owner-abc", session.owner_id
    assert_equal AgentSession::AGENT_TYPE_SISYPHUS, session.agent_type
    assert session.paused?
  end

  speed_profile :fast
  test "from_h handles string keys" do
    hash = {
      "session_id" => "session-789",
      "owner_id" => "owner-abc",
      "agent_type" => AgentSession::AGENT_TYPE_SISYPHUS,
      "started_at" => Time.now.utc.iso8601,
      "last_activity_at" => Time.now.utc.iso8601,
      "status" => AgentSession::STATUS_PAUSED
    }

    session = AgentSession.from_h(hash)

    assert_equal "session-789", session.session_id
  end

  private

  def build_session(overrides = {})
    defaults = {
      session_id: "session-123",
      owner_id: "owner-456",
      agent_type: AgentSession::AGENT_TYPE_DAEDALUS,
      started_at: Time.now.utc,
      last_activity_at: Time.now.utc,
      status: AgentSession::STATUS_ACTIVE
    }

    AgentSession.new(**defaults.merge(overrides))
  end
end








