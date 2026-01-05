# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/concerns/checkpointable"

class CheckpointableTest < ActiveSupport::TestCase
  # Test class that includes Checkpointable
  class TestWorker
    include Checkpointable
    
    attr_reader :path, :owner_id, :memory_store
    
    def initialize(path:, owner_id:, memory_store: nil)
      @path = path
      @owner_id = owner_id
      @memory_store = memory_store
    end
  end

  def setup
    @test_dir = Dir.mktmpdir("checkpointable_test")
    setup_git_repo(@test_dir)
    @worker = TestWorker.new(path: @test_dir, owner_id: "test_worker_1")
  end

  def teardown
    FileUtils.remove_entry(@test_dir) if @test_dir && File.exist?(@test_dir)
  end

  speed_profile :fast
  test "includes Checkpointable in class" do
    assert TestWorker.included_modules.include?(Checkpointable)
  end

  speed_profile :medium
  test "create_checkpoint creates checkpoint with message" do
    create_file_change(@test_dir)
    
    checkpoint = @worker.create_checkpoint("Test checkpoint")
    
    assert_instance_of Checkpoint, checkpoint
    assert_includes checkpoint.message, "Test checkpoint"
    assert_equal @worker.owner_id, checkpoint.worker_id
  end

  speed_profile :medium
  test "create_checkpoint with metadata" do
    create_file_change(@test_dir)
    
    checkpoint = @worker.create_checkpoint(
      "Milestone complete",
      milestone_id: "m1",
      step_ids: ["s1", "s2"]
    )
    
    assert_equal "m1", checkpoint.milestone_id
    assert_equal ["s1", "s2"], checkpoint.step_ids
  end

  speed_profile :medium
  test "create_checkpoint adds to registry" do
    create_file_change(@test_dir)
    
    assert_equal 0, @worker.checkpoint_count
    
    @worker.create_checkpoint("Test 1")
    assert_equal 1, @worker.checkpoint_count
    
    create_file_change(@test_dir)  # Need new changes for second checkpoint
    @worker.create_checkpoint("Test 2")
    assert_equal 2, @worker.checkpoint_count
  end

  speed_profile :medium
  test "create_checkpoint records to memory store if available" do
    # Use separate directory to avoid checkpoint count from other tests
    test_dir_2 = Dir.mktmpdir("checkpointable_test_memory")
    setup_git_repo(test_dir_2)
    
    # Use unique owner_id to avoid conflicts with parallel tests
    unique_owner = "test_worker_#{SecureRandom.hex(4)}"
    memory_path = File.join(ENV.fetch("AGENT_DATA_PATH", "."), unique_owner, "workflows", "test_workflow_memory.json")
    FileUtils.mkdir_p(File.dirname(memory_path))
    
    memory_store = WorkflowMemoryStore.new(
      owner_id: unique_owner,
      workflow_id: "test_workflow",
      workflow_name: "TestWorkflow",
      parent_id: "test_parent"
    )
    worker = TestWorker.new(path: test_dir_2, owner_id: unique_owner, memory_store: memory_store)
    
    create_file_change(test_dir_2)
    checkpoint = worker.create_checkpoint("Test checkpoint")
    
    assert_equal 1, memory_store.checkpoint_count
    assert_equal checkpoint.id, memory_store.latest_checkpoint[:checkpoint_id]
  ensure
    FileUtils.remove_entry(test_dir_2) if test_dir_2 && File.exist?(test_dir_2)
    FileUtils.rm_f(memory_path) if memory_path && File.exist?(memory_path)
  end

  speed_profile :fast
  test "checkpoint_service returns CheckpointService instance" do
    service = @worker.checkpoint_service
    
    assert_instance_of CheckpointService, service
    assert_equal @test_dir, service.path
  end

  speed_profile :fast
  test "checkpoint_registry returns CheckpointRegistry instance" do
    registry = @worker.checkpoint_registry
    
    assert_instance_of CheckpointRegistry, registry
    assert_equal @worker.owner_id, registry.owner_id
  end

  speed_profile :medium
  test "last_checkpoint returns most recent checkpoint" do
    create_file_change(@test_dir)
    checkpoint1 = @worker.create_checkpoint("First")
    
    create_file_change(@test_dir)
    checkpoint2 = @worker.create_checkpoint("Second")
    
    assert_equal checkpoint2.id, @worker.last_checkpoint.id
  end

  speed_profile :fast
  test "last_checkpoint returns nil when no checkpoints" do
    assert_nil @worker.last_checkpoint
  end

  speed_profile :medium
  test "all_checkpoints returns frozen copy" do
    create_file_change(@test_dir)
    @worker.create_checkpoint("Test 1")
    
    checkpoints = @worker.all_checkpoints
    
    assert_instance_of Array, checkpoints
    assert checkpoints.frozen?
    assert_equal 1, checkpoints.size
  end

  speed_profile :medium
  test "checkpoint_count returns correct count" do
    assert_equal 0, @worker.checkpoint_count
    
    create_file_change(@test_dir)
    @worker.create_checkpoint("Test 1")
    assert_equal 1, @worker.checkpoint_count
    
    create_file_change(@test_dir)
    @worker.create_checkpoint("Test 2")
    assert_equal 2, @worker.checkpoint_count
  end

  speed_profile :medium
  test "checkpoints_for_milestone returns filtered checkpoints" do
    create_file_change(@test_dir)
    cp1 = @worker.create_checkpoint("M1 start", milestone_id: "m1")
    
    create_file_change(@test_dir)
    cp2 = @worker.create_checkpoint("M2 start", milestone_id: "m2")
    
    create_file_change(@test_dir)
    cp3 = @worker.create_checkpoint("M1 end", milestone_id: "m1")
    
    m1_checkpoints = @worker.checkpoints_for_milestone("m1")
    
    assert_equal 2, m1_checkpoints.size
    assert_includes m1_checkpoints.map(&:id), cp1.id
    assert_includes m1_checkpoints.map(&:id), cp3.id
    refute_includes m1_checkpoints.map(&:id), cp2.id
  end

  speed_profile :medium
  test "checkpoints_for_execution returns filtered checkpoints" do
    create_file_change(@test_dir)
    cp1 = @worker.create_checkpoint("Exec 1", execution_id: "exec_1")
    
    create_file_change(@test_dir)
    cp2 = @worker.create_checkpoint("Exec 2", execution_id: "exec_2")
    
    exec1_checkpoints = @worker.checkpoints_for_execution("exec_1")
    
    assert_equal 1, exec1_checkpoints.size
    assert_equal cp1.id, exec1_checkpoints.first.id
  end

  speed_profile :medium
  test "backup_checkpoints returns only backup checkpoints" do
    create_file_change(@test_dir)
    cp1 = @worker.create_checkpoint("Regular")
    
    create_file_change(@test_dir)
    cp2 = @worker.create_checkpoint("Backup", backup: true)
    
    backups = @worker.backup_checkpoints
    
    assert_equal 1, backups.size
    assert_equal cp2.id, backups.first.id
    assert backups.first.backup?
  end

  speed_profile :fast
  test "checkpoints_enabled? returns true by default" do
    assert @worker.checkpoints_enabled?
  end

  speed_profile :fast
  test "disable_checkpoints! disables checkpoint creation" do
    @worker.disable_checkpoints!
    
    refute @worker.checkpoints_enabled?
  end

  speed_profile :fast
  test "enable_checkpoints! re-enables checkpoint creation" do
    @worker.disable_checkpoints!
    @worker.enable_checkpoints!
    
    assert @worker.checkpoints_enabled?
  end

  speed_profile :medium
  test "rollback_to_last_checkpoint rolls back to last checkpoint" do
    # Create initial file
    file_path = File.join(@test_dir, "test.txt")
    File.write(file_path, "version 1")
    stage_files(@test_dir)
    checkpoint1 = @worker.create_checkpoint("Version 1")
    
    # Modify file
    File.write(file_path, "version 2")
    stage_and_commit(@test_dir, "version 2")
    
    # Rollback
    success = @worker.rollback_to_last_checkpoint(strategy: :hard)
    
    assert success
    assert_equal "version 1", File.read(file_path)
  end

  speed_profile :medium
  test "rollback_to_checkpoint rolls back to specific checkpoint" do
    # Create initial file
    file_path = File.join(@test_dir, "test.txt")
    File.write(file_path, "version 1")
    stage_files(@test_dir)
    checkpoint1 = @worker.create_checkpoint("Version 1")
    
    # Modify file
    File.write(file_path, "version 2")
    stage_files(@test_dir)
    checkpoint2 = @worker.create_checkpoint("Version 2")
    
    # Modify again
    File.write(file_path, "version 3")
    stage_and_commit(@test_dir, "version 3")
    
    # Rollback to checkpoint1
    success = @worker.rollback_to_checkpoint(checkpoint1, strategy: :hard)
    
    assert success
    assert_equal "version 1", File.read(file_path)
  end

  speed_profile :fast
  test "rollback_to_last_checkpoint raises error when no checkpoints" do
    error = assert_raises(Checkpointable::CheckpointError) do
      @worker.rollback_to_last_checkpoint
    end
    
    assert_includes error.message, "No checkpoints available"
  end

  speed_profile :fast
  test "create_checkpoint raises error for non-git directory" do
    non_git_dir = Dir.mktmpdir("non_git")
    worker = TestWorker.new(path: non_git_dir, owner_id: "test")
    
    error = assert_raises(Checkpointable::CheckpointError) do
      worker.create_checkpoint("Test")
    end
    
    assert_includes error.message, "not a git repository"
  ensure
    FileUtils.remove_entry(non_git_dir) if non_git_dir
  end

  speed_profile :fast
  test "raises error when class does not implement path" do
    class NoPathWorker
      include Checkpointable
    end
    
    worker = NoPathWorker.new
    
    error = assert_raises(Checkpointable::CheckpointError) do
      worker.checkpoint_service
    end
    
    assert_includes error.message, "must implement #path or #checkpoint_path"
  end

  private

  def setup_git_repo(path)
    Dir.chdir(path) do
      system("git init -q")
      system("git config user.email 'test@example.com'")
      system("git config user.name 'Test User'")
      
      File.write("README.md", "# Test Repository")
      system("git add .")
      system("git commit -q -m 'Initial commit'")
    end
  end

  def create_file_change(path)
    file_path = File.join(path, ".change_#{Time.now.to_f.to_s.tr('.', '_')}")
    File.write(file_path, Time.now.utc.iso8601)
    stage_files(path)
  end

  def stage_files(path)
    Dir.chdir(path) do
      system("git add .")
    end
  end

  def stage_and_commit(path, message)
    Dir.chdir(path) do
      system("git add .")
      system("git commit -q -m '#{message}'")
    end
  end
end

