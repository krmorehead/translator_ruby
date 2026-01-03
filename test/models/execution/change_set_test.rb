# frozen_string_literal: true

require "test_helper"

module Execution
  class ChangeSetTest < ActiveSupport::TestCase
    def setup
      @files = {
        "app/models/user.rb" => {
          change_type: :created,
          diff: "+class User\n+end",
          before_hash: nil,
          after_hash: "abc123"
        },
        "app/models/post.rb" => {
          change_type: :modified,
          diff: "+def publish\n+end",
          before_hash: "def456",
          after_hash: "ghi789"
        },
        "app/models/old.rb" => {
          change_type: :deleted,
          diff: "-class Old\n-end",
          before_hash: "jkl012",
          after_hash: nil
        }
      }
    end

    # ===== Initialization Tests =====
    speed_profile :fast
    test "initializes with required parameters" do
      change_set = ChangeSet.new(files: @files)

      assert_equal @files, change_set.files
      assert_nil change_set.checkpoint_id
      assert_not_nil change_set.created_at
    end

    speed_profile :fast
    test "initializes with optional parameters" do
      change_set = ChangeSet.new(
        files: @files,
        checkpoint_id: "commit_abc123",
        created_at: "2025-01-01T00:00:00Z",
        milestone_id: "1",
        step_id: "1.1",
        summary: "Created user model"
      )

      assert_equal "commit_abc123", change_set.checkpoint_id
      assert_equal "2025-01-01T00:00:00Z", change_set.created_at
      assert_equal "1", change_set.milestone_id
      assert_equal "1.1", change_set.step_id
      assert_equal "Created user model", change_set.summary
    end

    speed_profile :fast
    test "sets created_at to current time if not provided" do
      change_set = ChangeSet.new(files: @files)

      assert_not_nil change_set.created_at
      assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, change_set.created_at)
    end

    # ===== Validation Tests =====

    speed_profile :fast
    test "validates files is a Hash" do
      error = assert_raises(ArgumentError) do
        ChangeSet.new(files: [])
      end

      assert_match(/files must be a Hash/, error.message)
    end

    speed_profile :fast
    test "validates checkpoint_id is a String or nil" do
      error = assert_raises(ArgumentError) do
        ChangeSet.new(files: @files, checkpoint_id: 123)
      end

      assert_match(/checkpoint_id must be a String or nil/, error.message)
    end

    speed_profile :fast
    test "validates checkpoint_id is not empty" do
      error = assert_raises(ArgumentError) do
        ChangeSet.new(files: @files, checkpoint_id: "  ")
      end

      assert_match(/checkpoint_id cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates file paths are Strings" do
      invalid_files = {
        123 => { change_type: :created, diff: "+content" }
      }

      error = assert_raises(TypeError) do
        ChangeSet.new(files: invalid_files)
      end

      assert_match(/all file paths must be Strings/, error.message)
    end

    speed_profile :fast
    test "validates file details are Hashes" do
      invalid_files = {
        "file.rb" => "not a hash"
      }

      error = assert_raises(TypeError) do
        ChangeSet.new(files: invalid_files)
      end

      assert_match(/all file details must be Hashes/, error.message)
    end

    speed_profile :fast
    test "validates file details include change_type" do
      invalid_files = {
        "file.rb" => { diff: "+content" }
      }

      error = assert_raises(ArgumentError) do
        ChangeSet.new(files: invalid_files)
      end

      assert_match(/must include :change_type/, error.message)
    end

    speed_profile :fast
    test "validates change_type is valid" do
      invalid_files = {
        "file.rb" => { change_type: :invalid, diff: "+content" }
      }

      error = assert_raises(ArgumentError) do
        ChangeSet.new(files: invalid_files)
      end

      assert_match(/invalid change_type/, error.message)
      assert_match(/created, modified, deleted/, error.message)
    end

    speed_profile :fast
    test "validates file details include diff" do
      invalid_files = {
        "file.rb" => { change_type: :created }
      }

      error = assert_raises(ArgumentError) do
        ChangeSet.new(files: invalid_files)
      end

      assert_match(/must include :diff/, error.message)
    end

    speed_profile :fast
    test "validates diff is a String" do
      invalid_files = {
        "file.rb" => { change_type: :created, diff: 123 }
      }

      error = assert_raises(TypeError) do
        ChangeSet.new(files: invalid_files)
      end

      assert_match(/diff .* must be a String/, error.message)
    end

    speed_profile :fast
    test "validates before_hash is String or nil" do
      invalid_files = {
        "file.rb" => {
          change_type: :created,
          diff: "+content",
          before_hash: 123
        }
      }

      error = assert_raises(TypeError) do
        ChangeSet.new(files: invalid_files)
      end

      assert_match(/before_hash .* must be a String or nil/, error.message)
    end

    speed_profile :fast
    test "validates after_hash is String or nil" do
      invalid_files = {
        "file.rb" => {
          change_type: :created,
          diff: "+content",
          after_hash: 123
        }
      }

      error = assert_raises(TypeError) do
        ChangeSet.new(files: invalid_files)
      end

      assert_match(/after_hash .* must be a String or nil/, error.message)
    end

    # ===== Count Methods Tests =====

    speed_profile :fast
    test "file_count returns total number of files" do
      change_set = ChangeSet.new(files: @files)

      assert_equal 3, change_set.file_count
    end

    speed_profile :fast
    test "modifications_count returns count of modified files" do
      change_set = ChangeSet.new(files: @files)

      assert_equal 1, change_set.modifications_count
    end

    speed_profile :fast
    test "additions_count returns count of created files" do
      change_set = ChangeSet.new(files: @files)

      assert_equal 1, change_set.additions_count
    end

    speed_profile :fast
    test "deletions_count returns count of deleted files" do
      change_set = ChangeSet.new(files: @files)

      assert_equal 1, change_set.deletions_count
    end

    # ===== Query Methods Tests =====

    speed_profile :fast
    test "changed_files returns array of file paths" do
      change_set = ChangeSet.new(files: @files)

      files = change_set.changed_files

      assert_equal 3, files.size
      assert_includes files, "app/models/user.rb"
      assert_includes files, "app/models/post.rb"
      assert_includes files, "app/models/old.rb"
    end

    speed_profile :fast
    test "changes_by_type filters by created" do
      change_set = ChangeSet.new(files: @files)

      created = change_set.changes_by_type(:created)

      assert_equal 1, created.size
      assert_includes created.keys, "app/models/user.rb"
    end

    speed_profile :fast
    test "changes_by_type filters by modified" do
      change_set = ChangeSet.new(files: @files)

      modified = change_set.changes_by_type(:modified)

      assert_equal 1, modified.size
      assert_includes modified.keys, "app/models/post.rb"
    end

    speed_profile :fast
    test "changes_by_type filters by deleted" do
      change_set = ChangeSet.new(files: @files)

      deleted = change_set.changes_by_type(:deleted)

      assert_equal 1, deleted.size
      assert_includes deleted.keys, "app/models/old.rb"
    end

    speed_profile :fast
    test "changes_by_type validates type" do
      change_set = ChangeSet.new(files: @files)

      error = assert_raises(ArgumentError) do
        change_set.changes_by_type(:invalid)
      end

      assert_match(/Invalid change type/, error.message)
    end

    speed_profile :fast
    test "full_diff generates unified diff" do
      change_set = ChangeSet.new(files: @files)

      diff = change_set.full_diff

      assert_includes diff, "--- app/models/user.rb"
      assert_includes diff, "+class User"
      assert_includes diff, "--- app/models/post.rb"
      assert_includes diff, "+def publish"
      assert_includes diff, "--- app/models/old.rb"
      assert_includes diff, "-class Old"
    end

    speed_profile :fast
    test "file_details returns details for specific file" do
      change_set = ChangeSet.new(files: @files)

      details = change_set.file_details("app/models/user.rb")

      assert_equal :created, details[:change_type]
      assert_equal "+class User\n+end", details[:diff]
      assert_nil details[:before_hash]
      assert_equal "abc123", details[:after_hash]
    end

    speed_profile :fast
    test "file_details returns nil for non-existent file" do
      change_set = ChangeSet.new(files: @files)

      assert_nil change_set.file_details("nonexistent.rb")
    end

    speed_profile :fast
    test "file_changed? returns true for changed file" do
      change_set = ChangeSet.new(files: @files)

      assert change_set.file_changed?("app/models/user.rb")
    end

    speed_profile :fast
    test "file_changed? returns false for non-existent file" do
      change_set = ChangeSet.new(files: @files)

      refute change_set.file_changed?("nonexistent.rb")
    end

    speed_profile :fast
    test "any_changes? returns true when files present" do
      change_set = ChangeSet.new(files: @files)

      assert change_set.any_changes?
    end

    speed_profile :fast
    test "any_changes? returns false when no files" do
      change_set = ChangeSet.new(files: {})

      refute change_set.any_changes?
    end

    # ===== Serialization Tests =====

    speed_profile :fast
    test "to_h serializes all attributes" do
      change_set = ChangeSet.new(
        files: @files,
        checkpoint_id: "commit_abc",
        created_at: "2025-01-01T00:00:00Z",
        milestone_id: "1",
        step_id: "1.1",
        summary: "Test changes"
      )

      hash = change_set.to_h

      assert_equal @files, hash[:files]
      assert_equal "commit_abc", hash[:checkpoint_id]
      assert_equal "2025-01-01T00:00:00Z", hash[:created_at]
      assert_equal "1", hash[:milestone_id]
      assert_equal "1.1", hash[:step_id]
      assert_equal "Test changes", hash[:summary]
    end

    speed_profile :fast
    test "from_h reconstructs ChangeSet" do
      hash = {
        files: @files,
        checkpoint_id: "commit_abc",
        created_at: "2025-01-01T00:00:00Z",
        milestone_id: "1",
        step_id: "1.1",
        summary: "Test changes"
      }

      change_set = ChangeSet.from_h(hash)

      assert_equal @files, change_set.files
      assert_equal "commit_abc", change_set.checkpoint_id
      assert_equal "2025-01-01T00:00:00Z", change_set.created_at
      assert_equal "1", change_set.milestone_id
      assert_equal "1.1", change_set.step_id
      assert_equal "Test changes", change_set.summary
    end

    speed_profile :fast
    test "from_h handles string keys" do
      hash = {
        "files" => @files,
        "checkpoint_id" => "commit_abc"
      }

      change_set = ChangeSet.from_h(hash)

      assert_equal @files, change_set.files
      assert_equal "commit_abc", change_set.checkpoint_id
    end

    speed_profile :fast
    test "from_h validates hash parameter" do
      error = assert_raises(ArgumentError) do
        ChangeSet.from_h("not a hash")
      end

      assert_match(/hash must be a Hash/, error.message)
    end

    speed_profile :fast
    test "serialization round-trip preserves data" do
      original = ChangeSet.new(
        files: @files,
        checkpoint_id: "commit_abc",
        milestone_id: "1",
        step_id: "1.1",
        summary: "Test changes"
      )

      hash = original.to_h
      reconstructed = ChangeSet.from_h(hash)

      assert_equal original.files, reconstructed.files
      assert_equal original.checkpoint_id, reconstructed.checkpoint_id
      assert_equal original.milestone_id, reconstructed.milestone_id
      assert_equal original.step_id, reconstructed.step_id
      assert_equal original.summary, reconstructed.summary
    end
  end
end








