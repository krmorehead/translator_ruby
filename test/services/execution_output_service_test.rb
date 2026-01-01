# frozen_string_literal: true

require "test_helper"

class ExecutionOutputServiceTest < ActiveSupport::TestCase
  setup do
    @temp_dir = Dir.mktmpdir("execution_output_test")
    @service = ExecutionOutputService.new(base_path: @temp_dir)
    
    # Create sample execution record
    @execution_record = Execution::ExecutionRecord.new(
      plan_id: "plan_123",
      step_results: [],
      started_at: Time.parse("2026-01-01 10:00:00 UTC").utc.iso8601,
      status: :running
    )
    
    # Add some step results
    step_result1 = Execution::StepResult.new(
      step_id: "step_1",
      success: true,
      actions_taken: [],
      files_changed: ["app/models/user.rb"],
      diffs: {
        "app/models/user.rb" => "--- a/app/models/user.rb\n+++ b/app/models/user.rb\n+  def name\n+  end\n"
      },
      duration: 5.2
    )
    
    @execution_record.add_step_result(step_result1)
    @execution_record.add_checkpoint("abc123")
    @execution_record.update_status(:complete)
  end

  teardown do
    FileUtils.rm_rf(@temp_dir) if File.exist?(@temp_dir)
  end

  # Basic initialization
  speed_profile :fast
  test "initializes with base_path" do
    assert_instance_of ExecutionOutputService, @service
    assert_equal @temp_dir, @service.base_path
  end

  speed_profile :fast
  test "initializes with default options" do
    service = ExecutionOutputService.new
    assert_not_nil service.base_path
    assert_includes service.base_path, "docs/executions"
  end

  # Writing execution output
  speed_profile :fast
  test "write_execution_output creates output directory" do
    result = @service.write_execution_output(@execution_record, plan_name: "test_plan")
    
    output_dir = result[:output_dir]
    assert File.directory?(output_dir)
    assert_match(/test_plan/, output_dir)
  end

  speed_profile :fast
  test "write_execution_output creates execution_log.md" do
    result = @service.write_execution_output(@execution_record, plan_name: "test_plan")
    
    log_file = result[:log_file]
    assert File.exist?(log_file)
    
    content = File.read(log_file)
    assert_includes content, "# Execution Log"
    assert_includes content, "plan_123"
  end

  speed_profile :fast
  test "write_execution_output creates execution.json" do
    result = @service.write_execution_output(@execution_record, plan_name: "test_plan")
    
    json_file = result[:json_file]
    assert File.exist?(json_file)
    
    json_content = JSON.parse(File.read(json_file), symbolize_names: true)
    assert_equal "plan_123", json_content[:plan_id]
    assert_equal "complete", json_content[:status]
  end

  speed_profile :fast
  test "write_execution_output creates changes.md" do
    result = @service.write_execution_output(@execution_record, plan_name: "test_plan")
    
    changes_file = result[:changes_file]
    assert File.exist?(changes_file)
    
    content = File.read(changes_file)
    assert_includes content, "# File Changes"
    assert_includes content, "app/models/user.rb"
  end

  speed_profile :fast
  test "write_execution_output creates diffs directory with individual diffs" do
    result = @service.write_execution_output(@execution_record, plan_name: "test_plan")
    
    diffs_dir = result[:diffs_dir]
    assert File.directory?(diffs_dir)
    
    # Check for individual diff file
    diff_files = Dir.glob(File.join(diffs_dir, "*.diff"))
    assert diff_files.size > 0
  end

  speed_profile :fast
  test "write_execution_output creates checkpoints.md" do
    result = @service.write_execution_output(@execution_record, plan_name: "test_plan")
    
    checkpoints_file = result[:checkpoints_file]
    assert File.exist?(checkpoints_file)
    
    content = File.read(checkpoints_file)
    assert_includes content, "# Checkpoints"
    assert_includes content, "abc123"
  end

  speed_profile :fast
  test "write_execution_output creates metadata.json" do
    result = @service.write_execution_output(@execution_record, plan_name: "test_plan")
    
    metadata_file = result[:metadata_file]
    assert File.exist?(metadata_file)
    
    metadata = JSON.parse(File.read(metadata_file), symbolize_names: true)
    assert_equal "plan_123", metadata[:plan_id]
    assert_not_nil metadata[:started_at]
  end

  speed_profile :fast
  test "write_execution_output returns hash with all file paths" do
    result = @service.write_execution_output(@execution_record, plan_name: "test_plan")
    
    assert_instance_of Hash, result
    assert result.key?(:output_dir)
    assert result.key?(:log_file)
    assert result.key?(:json_file)
    assert result.key?(:changes_file)
    assert result.key?(:diffs_dir)
    assert result.key?(:checkpoints_file)
    assert result.key?(:metadata_file)
  end

  # Options
  speed_profile :fast
  test "write_execution_output respects include_diffs option" do
    result = @service.write_execution_output(@execution_record, plan_name: "test_plan", include_diffs: false)
    
    # diffs_dir should not be included in result
    refute result.key?(:diffs_dir), "diffs_dir should not be in result when include_diffs is false"
  end

  speed_profile :fast
  test "write_execution_output respects include_checkpoints option" do
    result = @service.write_execution_output(@execution_record, plan_name: "test_plan", include_checkpoints: false)
    
    # checkpoints_file should not be included when option is false
    refute result.key?(:checkpoints_file), "checkpoints_file should not be in result when include_checkpoints is false"
  end

  # Content validation
  speed_profile :fast
  test "execution_log.md includes step results" do
    result = @service.write_execution_output(@execution_record, plan_name: "test_plan")
    
    content = File.read(result[:log_file])
    assert_includes content, "step_1"
    assert_includes content, "Success" # With capital S
  end

  speed_profile :fast
  test "execution_log.md includes duration" do
    result = @service.write_execution_output(@execution_record, plan_name: "test_plan")
    
    content = File.read(result[:log_file])
    assert_match(/duration/i, content)
  end

  speed_profile :fast
  test "changes.md includes diff snippets" do
    result = @service.write_execution_output(@execution_record, plan_name: "test_plan")
    
    content = File.read(result[:changes_file])
    assert_includes content, "app/models/user.rb"
    assert_includes content, "def name"
  end

  # Error handling
  speed_profile :fast
  test "handles directory creation errors gracefully" do
    # Make base path read-only
    FileUtils.chmod(0444, @temp_dir)
    
    error = assert_raises(RuntimeError) do
      @service.write_execution_output(@execution_record, plan_name: "test_plan")
    end
    
    assert_not_nil error.message
  ensure
    FileUtils.chmod(0755, @temp_dir)
  end

  speed_profile :fast
  test "validates execution_record parameter" do
    error = assert_raises(ArgumentError) do
      @service.write_execution_output(nil, plan_name: "test")
    end
    
    assert_match(/execution_record.*required/i, error.message)
  end

  speed_profile :fast
  test "validates execution_record type" do
    error = assert_raises(TypeError) do
      @service.write_execution_output({}, plan_name: "test")
    end
    
    assert_match(/must be.*ExecutionRecord/i, error.message)
  end

  # Plan name handling
  speed_profile :fast
  test "generates default plan name if not provided" do
    result = @service.write_execution_output(@execution_record)
    
    output_dir = result[:output_dir]
    assert_match(/execution_\d+/, output_dir)
  end

  speed_profile :fast
  test "sanitizes plan name for file system" do
    result = @service.write_execution_output(@execution_record, plan_name: "My Plan / With Special: Chars")
    
    output_dir = result[:output_dir]
    # Check the basename (directory name) not the full path
    dir_name = File.basename(output_dir)
    refute_includes dir_name, "/"
    refute_includes dir_name, ":"
  end

  # Timestamp handling
  speed_profile :fast
  test "output directory includes timestamp" do
    result = @service.write_execution_output(@execution_record, plan_name: "test_plan")
    
    output_dir = result[:output_dir]
    assert_match(/\d{8}_\d{6}/, output_dir)
  end

  # Multiple executions
  speed_profile :fast
  test "creates separate directories for multiple executions" do
    result1 = @service.write_execution_output(@execution_record, plan_name: "test_plan")
    
    # Create a second execution record with different start time
    execution_record2 = Execution::ExecutionRecord.new(
      plan_id: "plan_124",
      step_results: [],
      started_at: (Time.parse("2026-01-01 10:00:00 UTC") + 1).utc.iso8601,
      status: :running
    )
    
    result2 = @service.write_execution_output(execution_record2, plan_name: "test_plan")
    
    refute_equal result1[:output_dir], result2[:output_dir]
    assert File.directory?(result1[:output_dir])
    assert File.directory?(result2[:output_dir])
  end
end

