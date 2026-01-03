# frozen_string_literal: true

require "test_helper"

class CheckpointTest < ActiveSupport::TestCase
  # Initialization tests
  speed_profile :fast
  test "initializes with required parameters" do
    checkpoint = Checkpoint.new(
      id: "abc123def456",
      message: "Test checkpoint",
      created_at: Time.now.utc
    )

    assert_equal "abc123def456", checkpoint.id
    assert_equal "Test checkpoint", checkpoint.message
    assert_instance_of Time, checkpoint.created_at
    assert_equal({}, checkpoint.metadata)
    assert_equal [], checkpoint.files_changed
    assert_nil checkpoint.author
  end

  speed_profile :fast
  test "initializes with all parameters" do
    now = Time.now.utc
    metadata = { milestone_id: "m1", step_ids: ["s1", "s2"] }
    files = ["app/models/user.rb", "app/controllers/users_controller.rb"]

    checkpoint = Checkpoint.new(
      id: "abc123def456",
      message: "Milestone complete",
      created_at: now,
      metadata: metadata,
      files_changed: files,
      author: "Test User"
    )

    assert_equal "abc123def456", checkpoint.id
    assert_equal "Milestone complete", checkpoint.message
    assert_equal now, checkpoint.created_at
    assert_equal metadata, checkpoint.metadata
    assert_equal files, checkpoint.files_changed
    assert_equal "Test User", checkpoint.author
  end

  # Validation tests
  speed_profile :fast
  test "validates id is a String" do
    error = assert_raises(ArgumentError) do
      Checkpoint.new(
        id: 123,
        message: "Test",
        created_at: Time.now.utc
      )
    end
    assert_match(/id must be a String/, error.message)
  end

  speed_profile :fast
  test "validates id is not empty" do
    error = assert_raises(ArgumentError) do
      Checkpoint.new(
        id: "",
        message: "Test",
        created_at: Time.now.utc
      )
    end
    assert_match(/id cannot be empty/, error.message)
  end

  speed_profile :fast
  test "validates message is a String" do
    error = assert_raises(ArgumentError) do
      Checkpoint.new(
        id: "abc123",
        message: 123,
        created_at: Time.now.utc
      )
    end
    assert_match(/message must be a String/, error.message)
  end

  speed_profile :fast
  test "validates created_at is a Time" do
    error = assert_raises(ArgumentError) do
      Checkpoint.new(
        id: "abc123",
        message: "Test",
        created_at: "2024-01-01"
      )
    end
    assert_match(/created_at must be a Time/, error.message)
  end

  speed_profile :fast
  test "validates metadata is a Hash" do
    error = assert_raises(TypeError) do
      Checkpoint.new(
        id: "abc123",
        message: "Test",
        created_at: Time.now.utc,
        metadata: "not a hash"
      )
    end
    assert_match(/metadata must be a Hash/, error.message)
  end

  speed_profile :fast
  test "validates files_changed is an Array" do
    error = assert_raises(TypeError) do
      Checkpoint.new(
        id: "abc123",
        message: "Test",
        created_at: Time.now.utc,
        files_changed: "not an array"
      )
    end
    assert_match(/files_changed must be an Array/, error.message)
  end

  # Helper methods tests
  speed_profile :fast
  test "short_id returns first 7 characters" do
    checkpoint = Checkpoint.new(
      id: "abc123def456ghi789",
      message: "Test",
      created_at: Time.now.utc
    )

    assert_equal "abc123d", checkpoint.short_id
  end

  speed_profile :fast
  test "age returns seconds since creation" do
    past_time = Time.now.utc - 3600 # 1 hour ago
    checkpoint = Checkpoint.new(
      id: "abc123",
      message: "Test",
      created_at: past_time
    )

    age = checkpoint.age
    assert age >= 3600
    assert age < 3610 # Allow 10 second tolerance
  end

  speed_profile :fast
  test "file_count returns number of files" do
    checkpoint = Checkpoint.new(
      id: "abc123",
      message: "Test",
      created_at: Time.now.utc,
      files_changed: ["file1.rb", "file2.rb", "file3.rb"]
    )

    assert_equal 3, checkpoint.file_count
  end

  speed_profile :fast
  test "file_count returns zero for empty files_changed" do
    checkpoint = Checkpoint.new(
      id: "abc123",
      message: "Test",
      created_at: Time.now.utc
    )

    assert_equal 0, checkpoint.file_count
  end

  # Metadata accessors tests
  speed_profile :fast
  test "milestone_id returns metadata milestone_id" do
    checkpoint = Checkpoint.new(
      id: "abc123",
      message: "Test",
      created_at: Time.now.utc,
      metadata: { milestone_id: "m1" }
    )

    assert_equal "m1", checkpoint.milestone_id
  end

  speed_profile :fast
  test "milestone_id returns nil when not in metadata" do
    checkpoint = Checkpoint.new(
      id: "abc123",
      message: "Test",
      created_at: Time.now.utc
    )

    assert_nil checkpoint.milestone_id
  end

  speed_profile :fast
  test "step_ids returns metadata step_ids" do
    checkpoint = Checkpoint.new(
      id: "abc123",
      message: "Test",
      created_at: Time.now.utc,
      metadata: { step_ids: ["s1", "s2", "s3"] }
    )

    assert_equal ["s1", "s2", "s3"], checkpoint.step_ids
  end

  speed_profile :fast
  test "step_ids returns empty array when not in metadata" do
    checkpoint = Checkpoint.new(
      id: "abc123",
      message: "Test",
      created_at: Time.now.utc
    )

    assert_equal [], checkpoint.step_ids
  end

  speed_profile :fast
  test "worker_id returns metadata worker_id" do
    checkpoint = Checkpoint.new(
      id: "abc123",
      message: "Test",
      created_at: Time.now.utc,
      metadata: { worker_id: "w123" }
    )

    assert_equal "w123", checkpoint.worker_id
  end

  speed_profile :fast
  test "execution_id returns metadata execution_id" do
    checkpoint = Checkpoint.new(
      id: "abc123",
      message: "Test",
      created_at: Time.now.utc,
      metadata: { execution_id: "exec123" }
    )

    assert_equal "exec123", checkpoint.execution_id
  end

  speed_profile :fast
  test "backup? returns true when backup metadata is true" do
    checkpoint = Checkpoint.new(
      id: "abc123",
      message: "Test",
      created_at: Time.now.utc,
      metadata: { backup: true }
    )

    assert checkpoint.backup?
  end

  speed_profile :fast
  test "backup? returns false when backup metadata is not set" do
    checkpoint = Checkpoint.new(
      id: "abc123",
      message: "Test",
      created_at: Time.now.utc
    )

    refute checkpoint.backup?
  end

  # Serialization tests
  speed_profile :fast
  test "to_h returns hash representation" do
    now = Time.now.utc
    metadata = { milestone_id: "m1", step_ids: ["s1"] }
    files = ["file.rb"]

    checkpoint = Checkpoint.new(
      id: "abc123",
      message: "Test checkpoint",
      created_at: now,
      metadata: metadata,
      files_changed: files,
      author: "Test User"
    )

    hash = checkpoint.to_h

    assert_equal "abc123", hash[:id]
    assert_equal "Test checkpoint", hash[:message]
    assert_equal now.iso8601, hash[:created_at]
    assert_equal metadata, hash[:metadata]
    assert_equal files, hash[:files_changed]
    assert_equal "Test User", hash[:author]
  end

  speed_profile :fast
  test "from_h reconstructs checkpoint from hash" do
    now = Time.now.utc
    hash = {
      id: "abc123",
      message: "Test checkpoint",
      created_at: now.iso8601,
      metadata: { milestone_id: "m1" },
      files_changed: ["file.rb"],
      author: "Test User"
    }

    checkpoint = Checkpoint.from_h(hash)

    assert_equal "abc123", checkpoint.id
    assert_equal "Test checkpoint", checkpoint.message
    assert_equal now.to_i, checkpoint.created_at.to_i # Compare as integers to avoid precision issues
    assert_equal "m1", checkpoint.milestone_id
    assert_equal ["file.rb"], checkpoint.files_changed
    assert_equal "Test User", checkpoint.author
  end

  speed_profile :fast
  test "from_h handles string keys" do
    hash = {
      "id" => "abc123",
      "message" => "Test",
      "created_at" => Time.now.utc.iso8601
    }

    checkpoint = Checkpoint.from_h(hash)

    assert_equal "abc123", checkpoint.id
    assert_equal "Test", checkpoint.message
  end

  speed_profile :fast
  test "from_h validates hash is required" do
    error = assert_raises(ArgumentError) do
      Checkpoint.from_h(nil)
    end
    assert_match(/hash is required/, error.message)
  end

  speed_profile :fast
  test "from_h validates hash is a Hash" do
    error = assert_raises(ArgumentError) do
      Checkpoint.from_h("not a hash")
    end
    assert_match(/hash must be a Hash/, error.message)
  end

  speed_profile :fast
  test "serialization round-trip preserves data" do
    now = Time.now.utc
    original = Checkpoint.new(
      id: "abc123def456",
      message: "Test checkpoint",
      created_at: now,
      metadata: { milestone_id: "m1", step_ids: ["s1", "s2"] },
      files_changed: ["file1.rb", "file2.rb"],
      author: "Test User"
    )

    hash = original.to_h
    reconstructed = Checkpoint.from_h(hash)

    assert_equal original.id, reconstructed.id
    assert_equal original.message, reconstructed.message
    assert_equal original.created_at.to_i, reconstructed.created_at.to_i
    assert_equal original.metadata, reconstructed.metadata
    assert_equal original.files_changed, reconstructed.files_changed
    assert_equal original.author, reconstructed.author
  end
end


