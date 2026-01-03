# frozen_string_literal: true

require "test_helper"

class CheckpointRegistryTest < ActiveSupport::TestCase
  setup do
    @owner_id = "worker_123"
    @registry = CheckpointRegistry.new(owner_id: @owner_id)
    @checkpoint1 = Checkpoint.new(
      id: "abc123",
      message: "Checkpoint 1",
      created_at: Time.now.utc - 3600,
      metadata: { milestone_id: "m1", step_ids: ["s1"] }
    )
    @checkpoint2 = Checkpoint.new(
      id: "def456",
      message: "Checkpoint 2",
      created_at: Time.now.utc - 1800,
      metadata: { milestone_id: "m2", step_ids: ["s2"] }
    )
    @checkpoint3 = Checkpoint.new(
      id: "ghi789",
      message: "Checkpoint 3",
      created_at: Time.now.utc,
      metadata: { milestone_id: "m1", step_ids: ["s3"], backup: true }
    )
  end

  # Initialization tests
  speed_profile :fast
  test "initializes with owner_id" do
    registry = CheckpointRegistry.new(owner_id: "test_owner")

    assert_equal "test_owner", registry.owner_id
    assert_equal [], registry.checkpoints
    assert_instance_of Time, registry.created_at
  end

  speed_profile :fast
  test "validates owner_id is a String" do
    error = assert_raises(ArgumentError) do
      CheckpointRegistry.new(owner_id: 123)
    end
    assert_match(/owner_id must be a String/, error.message)
  end

  speed_profile :fast
  test "validates owner_id is not empty" do
    error = assert_raises(ArgumentError) do
      CheckpointRegistry.new(owner_id: "")
    end
    assert_match(/owner_id cannot be empty/, error.message)
  end

  # Add method tests
  speed_profile :fast
  test "add adds checkpoint to registry" do
    @registry.add(@checkpoint1)

    assert_equal 1, @registry.count
    assert_equal @checkpoint1, @registry.checkpoints.first
  end

  speed_profile :fast
  test "add returns the added checkpoint" do
    result = @registry.add(@checkpoint1)

    assert_equal @checkpoint1, result
  end

  speed_profile :fast
  test "add validates checkpoint is a Checkpoint" do
    error = assert_raises(TypeError) do
      @registry.add("not a checkpoint")
    end
    assert_match(/checkpoint must be a Checkpoint/, error.message)
  end

  speed_profile :fast
  test "add allows multiple checkpoints" do
    @registry.add(@checkpoint1)
    @registry.add(@checkpoint2)
    @registry.add(@checkpoint3)

    assert_equal 3, @registry.count
  end

  # Find method tests
  speed_profile :fast
  test "find returns checkpoint by ID" do
    @registry.add(@checkpoint1)
    @registry.add(@checkpoint2)

    found = @registry.find("abc123")

    assert_equal @checkpoint1, found
  end

  speed_profile :fast
  test "find returns nil for non-existent ID" do
    @registry.add(@checkpoint1)

    found = @registry.find("nonexistent")

    assert_nil found
  end

  # Latest method tests
  speed_profile :fast
  test "latest returns most recent checkpoint" do
    @registry.add(@checkpoint1)
    @registry.add(@checkpoint2)
    @registry.add(@checkpoint3)

    assert_equal @checkpoint3, @registry.latest
  end

  speed_profile :fast
  test "latest returns nil when registry is empty" do
    assert_nil @registry.latest
  end

  # For milestone method tests
  speed_profile :fast
  test "for_milestone returns checkpoints for milestone" do
    @registry.add(@checkpoint1)
    @registry.add(@checkpoint2)
    @registry.add(@checkpoint3)

    m1_checkpoints = @registry.for_milestone("m1")

    assert_equal 2, m1_checkpoints.size
    assert_includes m1_checkpoints, @checkpoint1
    assert_includes m1_checkpoints, @checkpoint3
  end

  speed_profile :fast
  test "for_milestone returns empty array when no matches" do
    @registry.add(@checkpoint1)

    checkpoints = @registry.for_milestone("nonexistent")

    assert_equal [], checkpoints
  end

  # For execution method tests
  speed_profile :fast
  test "for_execution returns checkpoints for execution" do
    execution_checkpoint = Checkpoint.new(
      id: "exec123",
      message: "Execution checkpoint",
      created_at: Time.now.utc,
      metadata: { execution_id: "exec_001" }
    )
    @registry.add(execution_checkpoint)
    @registry.add(@checkpoint1)

    exec_checkpoints = @registry.for_execution("exec_001")

    assert_equal 1, exec_checkpoints.size
    assert_equal execution_checkpoint, exec_checkpoints.first
  end

  # Backups method tests
  speed_profile :fast
  test "backups returns backup checkpoints" do
    @registry.add(@checkpoint1)
    @registry.add(@checkpoint2)
    @registry.add(@checkpoint3)

    backup_checkpoints = @registry.backups

    assert_equal 1, backup_checkpoints.size
    assert_equal @checkpoint3, backup_checkpoints.first
  end

  speed_profile :fast
  test "backups returns empty array when no backups" do
    @registry.add(@checkpoint1)
    @registry.add(@checkpoint2)

    assert_equal [], @registry.backups
  end

  # Count method tests
  speed_profile :fast
  test "count returns number of checkpoints" do
    assert_equal 0, @registry.count

    @registry.add(@checkpoint1)
    assert_equal 1, @registry.count

    @registry.add(@checkpoint2)
    assert_equal 2, @registry.count
  end

  # Empty method tests
  speed_profile :fast
  test "empty? returns true when no checkpoints" do
    assert @registry.empty?
  end

  speed_profile :fast
  test "empty? returns false when checkpoints exist" do
    @registry.add(@checkpoint1)

    refute @registry.empty?
  end

  # Checkpoint IDs method tests
  speed_profile :fast
  test "checkpoint_ids returns array of IDs" do
    @registry.add(@checkpoint1)
    @registry.add(@checkpoint2)
    @registry.add(@checkpoint3)

    ids = @registry.checkpoint_ids

    assert_equal ["abc123", "def456", "ghi789"], ids
  end

  speed_profile :fast
  test "checkpoint_ids returns empty array when empty" do
    assert_equal [], @registry.checkpoint_ids
  end

  # Clear method tests
  speed_profile :fast
  test "clear! removes all checkpoints" do
    @registry.add(@checkpoint1)
    @registry.add(@checkpoint2)

    @registry.clear!

    assert_equal 0, @registry.count
    assert @registry.empty?
  end

  # Serialization tests
  speed_profile :fast
  test "to_h returns hash representation" do
    @registry.add(@checkpoint1)
    @registry.add(@checkpoint2)

    hash = @registry.to_h

    assert_equal @owner_id, hash[:owner_id]
    assert_equal 2, hash[:checkpoints].size
    assert_instance_of String, hash[:created_at]
    assert_equal 2, hash[:count]
  end

  speed_profile :fast
  test "from_h reconstructs registry from hash" do
    @registry.add(@checkpoint1)
    @registry.add(@checkpoint2)

    hash = @registry.to_h
    reconstructed = CheckpointRegistry.from_h(hash)

    assert_equal @owner_id, reconstructed.owner_id
    assert_equal 2, reconstructed.count
    assert_equal "abc123", reconstructed.checkpoints.first.id
    assert_equal "def456", reconstructed.checkpoints.last.id
  end

  speed_profile :fast
  test "from_h handles string keys" do
    hash = {
      "owner_id" => "test_owner",
      "checkpoints" => [],
      "created_at" => Time.now.utc.iso8601,
      "count" => 0
    }

    registry = CheckpointRegistry.from_h(hash)

    assert_equal "test_owner", registry.owner_id
    assert_equal 0, registry.count
  end

  speed_profile :fast
  test "from_h validates hash is required" do
    error = assert_raises(ArgumentError) do
      CheckpointRegistry.from_h(nil)
    end
    assert_match(/hash is required/, error.message)
  end

  speed_profile :fast
  test "from_h validates hash is a Hash" do
    error = assert_raises(ArgumentError) do
      CheckpointRegistry.from_h("not a hash")
    end
    assert_match(/hash must be a Hash/, error.message)
  end

  speed_profile :fast
  test "serialization round-trip preserves data" do
    @registry.add(@checkpoint1)
    @registry.add(@checkpoint2)
    @registry.add(@checkpoint3)

    hash = @registry.to_h
    reconstructed = CheckpointRegistry.from_h(hash)

    assert_equal @registry.owner_id, reconstructed.owner_id
    assert_equal @registry.count, reconstructed.count
    assert_equal @registry.checkpoint_ids, reconstructed.checkpoint_ids

    # Verify find works on reconstructed registry
    found = reconstructed.find("abc123")
    assert_equal "Checkpoint 1", found.message
  end

  speed_profile :fast
  test "serialization preserves checkpoint queries" do
    @registry.add(@checkpoint1)
    @registry.add(@checkpoint2)
    @registry.add(@checkpoint3)

    hash = @registry.to_h
    reconstructed = CheckpointRegistry.from_h(hash)

    # Test latest
    assert_equal "Checkpoint 3", reconstructed.latest.message

    # Test for_milestone
    m1_checkpoints = reconstructed.for_milestone("m1")
    assert_equal 2, m1_checkpoints.size

    # Test backups
    backups = reconstructed.backups
    assert_equal 1, backups.size
  end
end


