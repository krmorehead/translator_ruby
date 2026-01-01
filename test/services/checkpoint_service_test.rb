# frozen_string_literal: true

require "test_helper"

class CheckpointServiceTest < ActiveSupport::TestCase
  setup do
    @temp_dir = Dir.mktmpdir("checkpoint_test")
    Dir.chdir(@temp_dir) do
      # Initialize a git repo for testing
      system("git init --quiet")
      system("git config user.email 'test@example.com'")
      system("git config user.name 'Test User'")
      
      # Create initial commit
      File.write("README.md", "# Test Repo\n")
      system("git add .")
      system("git commit -m 'Initial commit' --quiet")
    end
    
    @service = CheckpointService.new(path: @temp_dir)
  end

  teardown do
    FileUtils.rm_rf(@temp_dir) if File.exist?(@temp_dir)
  end

  # Basic initialization
  speed_profile :fast
  test "initializes with path" do
    assert_instance_of CheckpointService, @service
    assert_equal @temp_dir, @service.path
  end

  speed_profile :fast
  test "validates path is a git repository" do
    non_git_dir = Dir.mktmpdir("non_git")
    
    error = assert_raises(ArgumentError) do
      CheckpointService.new(path: non_git_dir)
    end
    
    assert_match(/not a git repository/i, error.message)
  ensure
    FileUtils.rm_rf(non_git_dir) if non_git_dir && File.exist?(non_git_dir)
  end

  # Checkpoint creation
  speed_profile :fast
  test "create_checkpoint creates a git commit and returns Checkpoint object" do
    Dir.chdir(@temp_dir) do
      File.write("test.txt", "test content\n")
      system("git add test.txt")
    end
    
    checkpoint = @service.create_checkpoint("Test checkpoint", milestone_id: "m1")
    
    assert_instance_of Checkpoint, checkpoint
    assert_not_nil checkpoint.id
    assert_match(/^[0-9a-f]{40}$/, checkpoint.id, "Should have full SHA-1 hash")
    assert_includes checkpoint.message, "Test checkpoint"
    assert_equal "m1", checkpoint.milestone_id
    assert_includes checkpoint.files_changed, "test.txt"
  end

  speed_profile :fast
  test "create_checkpoint with custom message" do
    Dir.chdir(@temp_dir) do
      File.write("file.rb", "# Ruby file\n")
      system("git add file.rb")
    end
    
    checkpoint = @service.create_checkpoint("Custom message", step_ids: ["s1"])
    
    assert_instance_of Checkpoint, checkpoint
    assert_includes checkpoint.message, "Custom message"
    assert_equal ["s1"], checkpoint.step_ids
  end

  speed_profile :fast
  test "create_checkpoint stores metadata in git notes" do
    Dir.chdir(@temp_dir) do
      File.write("meta.txt", "metadata test\n")
      system("git add meta.txt")
    end
    
    metadata = { milestone_id: "m1", step_ids: ["s1", "s2"], worker_id: "w1" }
    checkpoint = @service.create_checkpoint("With metadata", **metadata)
    
    assert_instance_of Checkpoint, checkpoint
    assert_equal "m1", checkpoint.milestone_id
    assert_equal ["s1", "s2"], checkpoint.step_ids
    assert_equal "w1", checkpoint.worker_id
  end

  speed_profile :fast
  test "create_checkpoint prefixes message with 'Sisyphus:'" do
    Dir.chdir(@temp_dir) do
      File.write("prefix_test.txt", "test\n")
      system("git add prefix_test.txt")
    end
    
    checkpoint = @service.create_checkpoint("Milestone Complete")
    
    assert_instance_of Checkpoint, checkpoint
    assert checkpoint.message.start_with?("Sisyphus:"), "Message should start with 'Sisyphus:'"
  end

  # Listing checkpoints
  speed_profile :fast
  test "list_checkpoints returns array of Checkpoint objects" do
    # Create multiple checkpoints
    2.times do |i|
      Dir.chdir(@temp_dir) do
        File.write("file#{i}.txt", "content #{i}\n")
        system("git add .")
        system("git commit -m 'Sisyphus: Checkpoint #{i}' --quiet")
      end
    end
    
    checkpoints = @service.list_checkpoints(limit: 10)
    
    assert_instance_of Array, checkpoints
    assert checkpoints.all? { |cp| cp.is_a?(Checkpoint) }
    sisyphus_checkpoints = checkpoints.select { |cp| cp.message.include?("Sisyphus:") }
    assert sisyphus_checkpoints.size >= 2
  end

  speed_profile :fast
  test "list_checkpoints respects limit parameter" do
    # Create several commits
    5.times do |i|
      Dir.chdir(@temp_dir) do
        File.write("bulk#{i}.txt", "#{i}\n")
        system("git add .")
        system("git commit -m 'Sisyphus: Bulk #{i}' --quiet")
      end
    end
    
    checkpoints = @service.list_checkpoints(limit: 3)
    
    assert checkpoints.size <= 3
  end

  # Getting checkpoint details
  speed_profile :fast
  test "get_checkpoint returns Checkpoint object" do
    Dir.chdir(@temp_dir) do
      File.write("detail_test.txt", "details\n")
      system("git add .")
    end
    
    created_checkpoint = @service.create_checkpoint("Detail Test")
    retrieved_checkpoint = @service.get_checkpoint(created_checkpoint.id)
    
    assert_instance_of Checkpoint, retrieved_checkpoint
    assert_equal created_checkpoint.id, retrieved_checkpoint.id
    assert_includes retrieved_checkpoint.message, "Detail Test"
    assert_instance_of Time, retrieved_checkpoint.created_at
    assert_instance_of Array, retrieved_checkpoint.files_changed
  end

  speed_profile :fast
  test "get_checkpoint with invalid ID returns nil" do
    invalid_id = "0" * 40
    details = @service.get_checkpoint(invalid_id)
    
    assert_nil details
  end

  # Diffing checkpoints
  speed_profile :fast
  test "diff_checkpoint shows differences between two checkpoints" do
    # Create first checkpoint
    Dir.chdir(@temp_dir) do
      File.write("diff1.txt", "version 1\n")
      system("git add .")
    end
    checkpoint1 = @service.create_checkpoint("Version 1")
    
    # Create second checkpoint
    Dir.chdir(@temp_dir) do
      File.write("diff1.txt", "version 2\n")
      system("git add .")
    end
    checkpoint2 = @service.create_checkpoint("Version 2")
    
    diff = @service.diff_checkpoint(checkpoint1.id, checkpoint2.id)
    
    assert_not_nil diff
    assert_includes diff, "diff1.txt"
    assert_includes diff, "-version 1"
    assert_includes diff, "+version 2"
  end

  speed_profile :fast
  test "diff_since_checkpoint shows current uncommitted changes" do
    Dir.chdir(@temp_dir) do
      File.write("since_test.txt", "initial\n")
      system("git add .")
    end
    checkpoint = @service.create_checkpoint("Before changes")
    
    # Make uncommitted changes
    Dir.chdir(@temp_dir) do
      File.write("since_test.txt", "modified\n")
    end
    
    diff = @service.diff_since_checkpoint(checkpoint.id)
    
    assert_not_nil diff
    assert_includes diff, "since_test.txt"
  end

  # Validation
  speed_profile :fast
  test "validate_checkpoint returns true for valid checkpoint" do
    Dir.chdir(@temp_dir) do
      File.write("valid.txt", "valid\n")
      system("git add .")
    end
    checkpoint = @service.create_checkpoint("Valid")
    
    assert @service.validate_checkpoint(checkpoint.id)
  end

  speed_profile :fast
  test "validate_checkpoint returns false for invalid checkpoint" do
    invalid_id = "0" * 40
    
    refute @service.validate_checkpoint(invalid_id)
  end

  # Metadata operations
  speed_profile :fast
  test "checkpoint_metadata returns empty hash for checkpoint without metadata" do
    # Use the initial commit which has no Sisyphus metadata
    Dir.chdir(@temp_dir) do
      initial_commit = `git rev-list --max-parents=0 HEAD`.strip
      metadata = @service.checkpoint_metadata(initial_commit)
      
      assert_instance_of Hash, metadata
      assert metadata.empty? || metadata.values.all?(&:nil?)
    end
  end

  # Error handling
  speed_profile :fast
  test "create_checkpoint with no staged changes raises error" do
    # No changes staged
    error = assert_raises(RuntimeError) do
      @service.create_checkpoint("No changes")
    end
    
    assert_match(/failed to create checkpoint/i, error.message)
  end

  speed_profile :fast
  test "handles git errors gracefully" do
    # Try to create checkpoint in corrupted state
    Dir.chdir(@temp_dir) do
      FileUtils.rm_rf(".git/refs")
    end
    
    error = assert_raises(RuntimeError) do
      @service.create_checkpoint("Will fail")
    end
    
    assert_not_nil error.message
  end

  # Options validation
  speed_profile :fast
  test "initializes with auto_commit option" do
    service = CheckpointService.new(path: @temp_dir, auto_commit: false)
    assert_equal false, service.options[:auto_commit]
  end

  speed_profile :fast
  test "initializes with custom commit_prefix" do
    service = CheckpointService.new(path: @temp_dir, commit_prefix: "CustomPrefix")
    assert_equal "CustomPrefix", service.options[:commit_prefix]
  end
end

