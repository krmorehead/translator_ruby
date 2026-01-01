# frozen_string_literal: true

require "test_helper"
require_relative "../../lib/checkpoint_tracker"

class CheckpointTrackerTest < ActiveSupport::TestCase
  def setup
    @test_dir = Dir.mktmpdir("checkpoint_tracker_test")
    setup_git_repo(@test_dir)
    CheckpointTracker.instance.clear_all_caches
  end

  def teardown
    FileUtils.remove_entry(@test_dir) if @test_dir && File.exist?(@test_dir)
  end

  speed_profile :fast
  test "singleton pattern returns same instance" do
    instance1 = CheckpointTracker.instance
    instance2 = CheckpointTracker.instance
    assert_same instance1, instance2
  end

  speed_profile :medium
  test "current_id creates checkpoint on first call" do
    create_file_change(@test_dir)
    
    checkpoint_id = CheckpointTracker.instance.current_id(path: @test_dir)
    
    assert_not_nil checkpoint_id
    assert_instance_of String, checkpoint_id
    assert checkpoint_id.length > 0
  end

  speed_profile :medium
  test "current_id returns same ID when no changes" do
    create_file_change(@test_dir)
    
    id1 = CheckpointTracker.instance.current_id(path: @test_dir)
    id2 = CheckpointTracker.instance.current_id(path: @test_dir)
    
    assert_equal id1, id2
  end

  speed_profile :medium
  test "current_id creates new checkpoint when codebase changes" do
    create_file_change(@test_dir)
    id1 = CheckpointTracker.instance.current_id(path: @test_dir)
    
    # Make another change
    create_file_change(@test_dir)
    id2 = CheckpointTracker.instance.current_id(path: @test_dir)
    
    assert_not_equal id1, id2
  end

  speed_profile :medium
  test "current_id accepts custom message" do
    create_file_change(@test_dir)
    
    checkpoint_id = CheckpointTracker.instance.current_id(
      path: @test_dir,
      message: "Custom milestone"
    )
    
    assert_not_nil checkpoint_id
  end

  speed_profile :medium
  test "current_id accepts worker_id and milestone_id" do
    create_file_change(@test_dir)
    
    checkpoint_id = CheckpointTracker.instance.current_id(
      path: @test_dir,
      milestone_id: "v1.0",
      worker_id: "worker-123"
    )
    
    assert_not_nil checkpoint_id
  end

  speed_profile :medium
  test "current_checkpoint returns checkpoint object" do
    create_file_change(@test_dir)
    
    checkpoint_id = CheckpointTracker.instance.current_id(path: @test_dir)
    checkpoint = CheckpointTracker.instance.current_checkpoint(path: @test_dir)
    
    assert_instance_of Checkpoint, checkpoint
    assert_equal checkpoint_id, checkpoint.id
  end

  speed_profile :medium
  test "current_checkpoint returns nil before first checkpoint" do
    checkpoint = CheckpointTracker.instance.current_checkpoint(path: @test_dir)
    assert_nil checkpoint
  end

  speed_profile :medium
  test "force_checkpoint creates checkpoint even without changes" do
    create_file_change(@test_dir)
    id1 = CheckpointTracker.instance.current_id(path: @test_dir)
    
    # Make another change for force checkpoint
    create_file_change(@test_dir)
    id2 = CheckpointTracker.instance.force_checkpoint(
      path: @test_dir,
      message: "Forced checkpoint"
    )
    
    assert_not_equal id1, id2
  end

  speed_profile :fast
  test "clear_cache removes cached checkpoint for path" do
    create_file_change(@test_dir)
    CheckpointTracker.instance.current_id(path: @test_dir)
    
    CheckpointTracker.instance.clear_cache(path: @test_dir)
    checkpoint = CheckpointTracker.instance.current_checkpoint(path: @test_dir)
    
    assert_nil checkpoint
  end

  speed_profile :fast
  test "clear_all_caches removes all cached checkpoints" do
    create_file_change(@test_dir)
    CheckpointTracker.instance.current_id(path: @test_dir)
    
    CheckpointTracker.instance.clear_all_caches
    checkpoint = CheckpointTracker.instance.current_checkpoint(path: @test_dir)
    
    assert_nil checkpoint
  end

  speed_profile :medium
  test "handles multiple paths independently" do
    test_dir_2 = Dir.mktmpdir("checkpoint_tracker_test_2")
    setup_git_repo(test_dir_2)
    
    begin
      create_file_change(@test_dir)
      create_file_change(test_dir_2)
      
      id1 = CheckpointTracker.instance.current_id(path: @test_dir)
      id2 = CheckpointTracker.instance.current_id(path: test_dir_2)
      
      assert_not_equal id1, id2
    ensure
      FileUtils.remove_entry(test_dir_2) if test_dir_2 && File.exist?(test_dir_2)
    end
  end

  private

  def setup_git_repo(path)
    Dir.chdir(path) do
      system("git init -q")
      system("git config user.email 'test@example.com'")
      system("git config user.name 'Test User'")
      File.write("README.md", "Initial commit")
      system("git add .")
      system("git commit -q -m 'Initial commit'")
    end
  end

  def create_file_change(path)
    file_path = File.join(path, ".change_#{Time.now.to_f.to_s.tr('.', '_')}")
    File.write(file_path, Time.now.utc.iso8601)
    Dir.chdir(path) do
      system("git add .")
    end
  end
end

