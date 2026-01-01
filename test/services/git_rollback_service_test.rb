# frozen_string_literal: true

require "test_helper"

class GitRollbackServiceTest < ActiveSupport::TestCase
  def setup
    @test_dir = Dir.mktmpdir("git_rollback_test")
    setup_git_repo
    @service = GitRollbackService.new(path: @test_dir)
  end

  def teardown
    FileUtils.remove_entry(@test_dir) if @test_dir && File.exist?(@test_dir)
  end

  speed_profile :fast
  test "initializes with valid git repository" do
    assert_instance_of GitRollbackService, @service
    assert_equal @test_dir, @service.path
  end

  speed_profile :fast
  test "raises error for non-git directory" do
    non_git_dir = Dir.mktmpdir("non_git")
    error = assert_raises(ArgumentError) do
      GitRollbackService.new(path: non_git_dir)
    end
    assert_includes error.message, "not a git repository"
  ensure
    FileUtils.remove_entry(non_git_dir) if non_git_dir && File.exist?(non_git_dir)
  end

  speed_profile :medium
  test "can_rollback? returns true for valid checkpoint" do
    checkpoint = create_test_checkpoint("Test checkpoint")
    
    result = @service.can_rollback?(checkpoint)
    
    assert result[:can_rollback]
    assert_nil result[:reason]
  end

  speed_profile :medium
  test "can_rollback? returns false for non-existent checkpoint" do
    result = @service.can_rollback?("invalid_commit_id_123")
    
    refute result[:can_rollback]
    assert_includes result[:reason], "does not exist"
  end

  speed_profile :medium
  test "can_rollback? returns false with uncommitted changes" do
    checkpoint = create_test_checkpoint("Test checkpoint")
    
    # Create uncommitted change
    File.write(File.join(@test_dir, "uncommitted.txt"), "uncommitted content")
    
    result = @service.can_rollback?(checkpoint)
    
    refute result[:can_rollback]
    assert_includes result[:reason], "Uncommitted changes"
  end

  speed_profile :medium
  test "rollback_to performs hard reset successfully" do
    # Create checkpoint
    File.write(File.join(@test_dir, "file1.txt"), "original content")
    checkpoint = create_test_checkpoint("Original state")
    
    # Make new changes
    File.write(File.join(@test_dir, "file1.txt"), "modified content")
    commit_changes("Modified state")
    
    # Rollback
    success = @service.rollback_to(checkpoint, strategy: :hard, create_backup: false)
    
    assert success
    assert_equal "original content", File.read(File.join(@test_dir, "file1.txt"))
  end

  speed_profile :medium
  test "rollback_to performs soft reset successfully" do
    # Create checkpoint
    File.write(File.join(@test_dir, "file1.txt"), "original content")
    checkpoint = create_test_checkpoint("Original state")
    
    # Make new changes
    File.write(File.join(@test_dir, "file1.txt"), "modified content")
    commit_changes("Modified state")
    
    # Rollback with soft strategy (keeps changes staged)
    success = @service.rollback_to(checkpoint, strategy: :soft, create_backup: false)
    
    assert success
    # File content should remain (staged)
    assert_equal "modified content", File.read(File.join(@test_dir, "file1.txt"))
  end

  speed_profile :medium
  test "rollback_to performs mixed reset successfully" do
    # Create checkpoint
    File.write(File.join(@test_dir, "file1.txt"), "original content")
    checkpoint = create_test_checkpoint("Original state")
    
    # Make new changes
    File.write(File.join(@test_dir, "file1.txt"), "modified content")
    commit_changes("Modified state")
    
    # Rollback with mixed strategy (keeps changes unstaged)
    success = @service.rollback_to(checkpoint, strategy: :mixed, create_backup: false)
    
    assert success
    # File content should remain (unstaged)
    assert_equal "modified content", File.read(File.join(@test_dir, "file1.txt"))
  end

  speed_profile :medium
  test "rollback_to creates backup checkpoint by default" do
    checkpoint = create_test_checkpoint("Test checkpoint")
    File.write(File.join(@test_dir, "file1.txt"), "new content")
    commit_changes("New state")
    
    # Rollback will create a backup, then reset to checkpoint
    # The backup commit will not be in HEAD history after rollback
    success = @service.rollback_to(checkpoint, strategy: :hard, create_backup: true)
    
    assert success
    
    # Verify we're back at the original checkpoint
    Dir.chdir(@test_dir) do
      current_commit = `git rev-parse HEAD`.strip
      assert_equal checkpoint.id, current_commit
    end
    
    # The backup commit should be in reflog
    Dir.chdir(@test_dir) do
      reflog = `git reflog`.strip
      assert_includes reflog, "Backup before rollback"
    end
  end

  speed_profile :medium
  test "rollback_to accepts Checkpoint object" do
    checkpoint = create_test_checkpoint("Test checkpoint")
    File.write(File.join(@test_dir, "file1.txt"), "new content")
    commit_changes("New state")
    
    success = @service.rollback_to(checkpoint, strategy: :hard, create_backup: false)
    
    assert success
  end

  speed_profile :medium
  test "rollback_to accepts commit ID string" do
    checkpoint = create_test_checkpoint("Test checkpoint")
    File.write(File.join(@test_dir, "file1.txt"), "new content")
    commit_changes("New state")
    
    success = @service.rollback_to(checkpoint.id, strategy: :hard, create_backup: false)
    
    assert success
  end

  speed_profile :medium
  test "rollback_to raises error for invalid strategy" do
    checkpoint = create_test_checkpoint("Test checkpoint")
    
    error = assert_raises(ArgumentError) do
      @service.rollback_to(checkpoint, strategy: :invalid_strategy, create_backup: false)
    end
    assert_includes error.message, "Invalid strategy"
  end

  speed_profile :medium
  test "rollback_to raises error for non-existent checkpoint" do
    error = assert_raises(ArgumentError) do
      @service.rollback_to("invalid_commit_123", strategy: :hard, create_backup: false)
    end
    assert_includes error.message, "does not exist"
  end

  speed_profile :medium
  test "rollback_to raises error with uncommitted changes" do
    checkpoint = create_test_checkpoint("Test checkpoint")
    
    # Create uncommitted change
    File.write(File.join(@test_dir, "uncommitted.txt"), "uncommitted")
    
    error = assert_raises(RuntimeError) do
      @service.rollback_to(checkpoint, strategy: :hard, create_backup: false)
    end
    assert_includes error.message, "uncommitted changes"
  end

  speed_profile :medium
  test "list_rollback_candidates returns reachable checkpoints" do
    checkpoint1 = create_test_checkpoint("Checkpoint 1")
    checkpoint2 = create_test_checkpoint("Checkpoint 2")
    checkpoint3 = create_test_checkpoint("Checkpoint 3")
    
    candidates = @service.list_rollback_candidates
    
    assert_includes candidates.map(&:id), checkpoint1.id
    assert_includes candidates.map(&:id), checkpoint2.id
    assert_includes candidates.map(&:id), checkpoint3.id
  end

  speed_profile :medium
  test "list_rollback_candidates from specific checkpoint" do
    checkpoint1 = create_test_checkpoint("Checkpoint 1")
    checkpoint2 = create_test_checkpoint("Checkpoint 2")
    
    candidates = @service.list_rollback_candidates(checkpoint2)
    
    # Should include checkpoint1 (ancestor) and checkpoint2 itself
    candidate_ids = candidates.map(&:id)
    assert_includes candidate_ids, checkpoint1.id
  end

  speed_profile :medium
  test "create_backup_checkpoint creates checkpoint with backup metadata" do
    backup = @service.create_backup_checkpoint
    
    assert_instance_of Checkpoint, backup
    assert_includes backup.message, "Backup before rollback"
    assert backup.metadata[:backup]
  end

  speed_profile :fast
  test "rollback_to handles invalid checkpoint type" do
    error = assert_raises(TypeError) do
      @service.rollback_to(12345, strategy: :hard, create_backup: false)
    end
    assert_includes error.message, "must be a Checkpoint or String"
  end

  private

  def setup_git_repo
    Dir.chdir(@test_dir) do
      system("git init -q")
      system("git config user.email 'test@example.com'")
      system("git config user.name 'Test User'")
      
      # Create initial commit
      File.write("README.md", "# Test Repository")
      system("git add .")
      system("git commit -q -m 'Initial commit'")
    end
  end

  def create_test_checkpoint(message)
    # Create a small file change so there's something to commit
    # Use nanoseconds to ensure unique filename even if called multiple times rapidly
    timestamp_file = File.join(@test_dir, ".checkpoint_#{Time.now.to_f.to_s.tr('.', '_')}")
    File.write(timestamp_file, Time.now.utc.iso8601)
    
    # Stage the file
    Dir.chdir(@test_dir) do
      system("git add .")
    end
    
    checkpoint_service = CheckpointService.new(path: @test_dir)
    checkpoint_service.create_checkpoint(message)
  end

  def commit_changes(message)
    Dir.chdir(@test_dir) do
      system("git add .")
      system("git commit -q -m '#{message}'")
    end
  end
end
