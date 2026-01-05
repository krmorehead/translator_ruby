# frozen_string_literal: true

require "test_helper"

# Tests for SessionCache - in-memory key-value cache (Redis-like)
# Uses real SessionCache instances, no mocking
class SessionCacheTest < ActiveSupport::TestCase
  setup do
    # Create a fresh cache for each test (not the singleton)
    @store = SessionCache.new
  end

  # Basic key-value operations

  speed_profile :fast
  test "set and get store and retrieve values" do
    @store.set("key1", "value1")

    result = @store.get("key1")

    assert_equal "value1", result
  end

  speed_profile :fast
  test "get returns nil for non-existent key" do
    result = @store.get("non-existent")

    assert_nil result
  end

  speed_profile :fast
  test "setex stores value (expiry ignored in memory store)" do
    @store.setex("key1", 3600, "value1")

    result = @store.get("key1")

    assert_equal "value1", result
  end

  speed_profile :fast
  test "del removes a key and returns 1" do
    @store.set("key1", "value1")

    result = @store.del("key1")

    assert_equal 1, result
    assert_nil @store.get("key1")
  end

  speed_profile :fast
  test "del returns 0 for non-existent key" do
    result = @store.del("non-existent")

    assert_equal 0, result
  end

  speed_profile :fast
  test "exists? returns true for existing key" do
    @store.set("key1", "value1")

    assert @store.exists?("key1")
  end

  speed_profile :fast
  test "exists? returns false for non-existent key" do
    refute @store.exists?("non-existent")
  end

  speed_profile :fast
  test "expire is a no-op but returns true" do
    @store.set("key1", "value1")

    result = @store.expire("key1", 3600)

    assert result
    assert_equal "value1", @store.get("key1")
  end

  speed_profile :fast
  test "ping returns PONG" do
    result = @store.ping

    assert_equal "PONG", result
  end

  # Set operations

  speed_profile :fast
  test "sadd adds member to set" do
    @store.sadd("myset", "member1")

    members = @store.smembers("myset")

    assert_includes members, "member1"
  end

  speed_profile :fast
  test "sadd adds multiple members to same set" do
    @store.sadd("myset", "member1")
    @store.sadd("myset", "member2")
    @store.sadd("myset", "member3")

    members = @store.smembers("myset")

    assert_equal 3, members.size
    assert_includes members, "member1"
    assert_includes members, "member2"
    assert_includes members, "member3"
  end

  speed_profile :fast
  test "sadd does not add duplicate members" do
    @store.sadd("myset", "member1")
    @store.sadd("myset", "member1")

    members = @store.smembers("myset")

    assert_equal 1, members.size
  end

  speed_profile :fast
  test "srem removes member from set" do
    @store.sadd("myset", "member1")
    @store.sadd("myset", "member2")

    result = @store.srem("myset", "member1")

    assert_equal 1, result
    members = @store.smembers("myset")
    refute_includes members, "member1"
    assert_includes members, "member2"
  end

  speed_profile :fast
  test "srem returns 0 for non-existent member" do
    @store.sadd("myset", "member1")

    result = @store.srem("myset", "non-existent")

    assert_equal 0, result
  end

  speed_profile :fast
  test "srem returns 0 for non-existent set" do
    result = @store.srem("non-existent-set", "member1")

    assert_equal 0, result
  end

  speed_profile :fast
  test "smembers returns empty array for non-existent set" do
    members = @store.smembers("non-existent-set")

    assert_equal [], members
  end

  # Sorted set operations

  speed_profile :fast
  test "zadd adds member with score" do
    @store.zadd("myzset", 100, "member1")

    members = @store.zrange("myzset", 0, -1)

    assert_includes members, "member1"
  end

  speed_profile :fast
  test "zrange returns members in ascending score order" do
    @store.zadd("myzset", 300, "third")
    @store.zadd("myzset", 100, "first")
    @store.zadd("myzset", 200, "second")

    members = @store.zrange("myzset", 0, -1)

    assert_equal %w[first second third], members
  end

  speed_profile :fast
  test "zrevrange returns members in descending score order" do
    @store.zadd("myzset", 300, "third")
    @store.zadd("myzset", 100, "first")
    @store.zadd("myzset", 200, "second")

    members = @store.zrevrange("myzset", 0, -1)

    assert_equal %w[third second first], members
  end

  speed_profile :fast
  test "zrange with limit returns subset" do
    @store.zadd("myzset", 100, "first")
    @store.zadd("myzset", 200, "second")
    @store.zadd("myzset", 300, "third")

    members = @store.zrange("myzset", 0, 1)

    assert_equal %w[first second], members
  end

  speed_profile :fast
  test "zrevrange with limit returns subset" do
    @store.zadd("myzset", 100, "first")
    @store.zadd("myzset", 200, "second")
    @store.zadd("myzset", 300, "third")

    members = @store.zrevrange("myzset", 0, 1)

    assert_equal %w[third second], members
  end

  speed_profile :fast
  test "zrem removes member from sorted set" do
    @store.zadd("myzset", 100, "first")
    @store.zadd("myzset", 200, "second")

    result = @store.zrem("myzset", "first")

    assert_equal 1, result
    members = @store.zrange("myzset", 0, -1)
    refute_includes members, "first"
    assert_includes members, "second"
  end

  speed_profile :fast
  test "zrem returns 0 for non-existent member" do
    @store.zadd("myzset", 100, "first")

    result = @store.zrem("myzset", "non-existent")

    assert_equal 0, result
  end

  speed_profile :fast
  test "zrange returns empty array for non-existent sorted set" do
    members = @store.zrange("non-existent-zset", 0, -1)

    assert_equal [], members
  end

  speed_profile :fast
  test "zrevrange returns empty array for non-existent sorted set" do
    members = @store.zrevrange("non-existent-zset", 0, -1)

    assert_equal [], members
  end

  # flushall

  speed_profile :fast
  test "flushall clears all data" do
    @store.set("key1", "value1")
    @store.sadd("myset", "member1")
    @store.zadd("myzset", 100, "member1")

    @store.flushall

    assert_nil @store.get("key1")
    assert_equal [], @store.smembers("myset")
    assert_equal [], @store.zrange("myzset", 0, -1)
  end

  # Singleton

  speed_profile :fast
  test "instance returns singleton" do
    instance1 = SessionCache.instance
    instance2 = SessionCache.instance

    assert_same instance1, instance2
  end

  # Thread safety

  speed_profile :fast
  test "concurrent writes do not corrupt data" do
    threads = 10.times.map do |i|
      Thread.new do
        100.times do |j|
          @store.set("thread-#{i}-key-#{j}", "value-#{i}-#{j}")
        end
      end
    end

    threads.each(&:join)

    # Verify all keys were written
    count = 0
    10.times do |i|
      100.times do |j|
        count += 1 if @store.get("thread-#{i}-key-#{j}") == "value-#{i}-#{j}"
      end
    end

    assert_equal 1000, count
  end

  # Integration with ApprovalRequest

  speed_profile :fast
  test "stores and retrieves serialized ApprovalRequest" do
    # Use factory - new() generates UUID automatically (OOP pattern)
    request = build(:approval_request,
      approval_type: :step,
      step_id: "step-1",
      step_title: "Test Step",
      actions: ["action1", "action2"],
      changes: { files_to_create: 1 }
    )

    # Serialize and store (like ApprovalRequestStore does)
    serialized = request.to_h.to_json
    @store.set("approval:request:#{request.id}", serialized)

    # Retrieve and deserialize
    retrieved_json = @store.get("approval:request:#{request.id}")
    retrieved_hash = JSON.parse(retrieved_json)
    retrieved_request = Execution::ApprovalRequest.from_h(retrieved_hash)

    assert_equal request.id, retrieved_request.id
    assert_equal request.execution_id, retrieved_request.execution_id
    assert_equal request.type, retrieved_request.type
    assert_equal request.status, retrieved_request.status
    assert_equal request.subject_title, retrieved_request.subject_title
  end
end

