# frozen_string_literal: true

require "test_helper"

class CheckpointPolicyTest < ActiveSupport::TestCase
  def setup
    @policy = CheckpointPolicy.new
  end

  speed_profile :fast
  test "initializes with default configuration" do
    assert_equal 300, @policy.config[:checkpoint_interval]
    assert_equal 100, @policy.config[:max_changes_before_checkpoint]
    assert @policy.config[:checkpoint_on_milestone]
    refute @policy.config[:checkpoint_on_error]
    assert_equal 60, @policy.config[:min_interval_between_checkpoints]
  end

  speed_profile :fast
  test "initializes with custom configuration" do
    policy = CheckpointPolicy.new(
      checkpoint_interval: 600,
      max_changes_before_checkpoint: 50
    )
    
    assert_equal 600, policy.config[:checkpoint_interval]
    assert_equal 50, policy.config[:max_changes_before_checkpoint]
  end

  speed_profile :fast
  test "raises error for invalid checkpoint_interval" do
    error = assert_raises(ArgumentError) do
      CheckpointPolicy.new(checkpoint_interval: 0)
    end
    assert_includes error.message, "checkpoint_interval must be positive"
  end

  speed_profile :fast
  test "raises error for invalid max_changes_before_checkpoint" do
    error = assert_raises(ArgumentError) do
      CheckpointPolicy.new(max_changes_before_checkpoint: -1)
    end
    assert_includes error.message, "max_changes_before_checkpoint must be positive"
  end

  speed_profile :fast
  test "raises error for invalid min_interval_between_checkpoints" do
    error = assert_raises(ArgumentError) do
      CheckpointPolicy.new(min_interval_between_checkpoints: -1)
    end
    assert_includes error.message, "min_interval_between_checkpoints must be non-negative"
  end

  speed_profile :fast
  test "should_checkpoint? returns true for milestone trigger" do
    context = {
      trigger: :milestone,
      last_checkpoint_time: Time.now.utc - 120
    }
    
    result = @policy.should_checkpoint?(context)
    
    assert result[:should_checkpoint]
    assert_equal "Milestone boundary reached", result[:reason]
  end

  speed_profile :fast
  test "should_checkpoint? returns false for milestone when disabled" do
    policy = CheckpointPolicy.new(checkpoint_on_milestone: false)
    context = {
      trigger: :milestone,
      last_checkpoint_time: Time.now.utc - 120
    }
    
    result = policy.should_checkpoint?(context)
    
    refute result[:should_checkpoint]
    assert_equal "Milestone checkpoints disabled", result[:reason]
  end

  speed_profile :fast
  test "should_checkpoint? respects minimum interval for milestones" do
    context = {
      trigger: :milestone,
      last_checkpoint_time: Time.now.utc - 30 # Less than 60s minimum
    }
    
    result = @policy.should_checkpoint?(context)
    
    refute result[:should_checkpoint]
    assert_includes result[:reason], "Minimum interval not elapsed"
  end

  speed_profile :fast
  test "should_checkpoint? returns true for error trigger" do
    policy = CheckpointPolicy.new(checkpoint_on_error: true)
    context = {
      trigger: :error,
      last_checkpoint_time: Time.now.utc - 120
    }
    
    result = policy.should_checkpoint?(context)
    
    assert result[:should_checkpoint]
    assert_equal "Checkpoint before error recovery", result[:reason]
  end

  speed_profile :fast
  test "should_checkpoint? returns false for error when disabled" do
    context = {
      trigger: :error,
      last_checkpoint_time: Time.now.utc - 120
    }
    
    result = @policy.should_checkpoint?(context)
    
    refute result[:should_checkpoint]
    assert_equal "Error checkpoints disabled", result[:reason]
  end

  speed_profile :fast
  test "should_checkpoint? returns true for manual trigger" do
    context = { trigger: :manual }
    
    result = @policy.should_checkpoint?(context)
    
    assert result[:should_checkpoint]
    assert_equal "Manual checkpoint requested", result[:reason]
  end

  speed_profile :fast
  test "should_checkpoint? returns true when interval elapsed" do
    context = {
      trigger: :timer,
      last_checkpoint_time: Time.now.utc - 400 # More than 300s
    }
    
    result = @policy.should_checkpoint?(context)
    
    assert result[:should_checkpoint]
    assert_includes result[:reason], "interval elapsed"
  end

  speed_profile :fast
  test "should_checkpoint? returns true when too many changes" do
    context = {
      trigger: :timer,
      last_checkpoint_time: Time.now.utc - 120,
      files_changed: 150 # More than 100
    }
    
    result = @policy.should_checkpoint?(context)
    
    assert result[:should_checkpoint]
    assert_includes result[:reason], "Too many changes"
  end

  speed_profile :fast
  test "should_checkpoint? returns false when conditions not met" do
    context = {
      trigger: :timer,
      last_checkpoint_time: Time.now.utc - 120, # Less than 300s
      files_changed: 50 # Less than 100
    }
    
    result = @policy.should_checkpoint?(context)
    
    refute result[:should_checkpoint]
    assert_equal "No checkpoint conditions met", result[:reason]
  end

  speed_profile :fast
  test "should_checkpoint? respects minimum interval for timer" do
    context = {
      trigger: :timer,
      last_checkpoint_time: Time.now.utc - 30, # Less than 60s minimum
      files_changed: 150
    }
    
    result = @policy.should_checkpoint?(context)
    
    refute result[:should_checkpoint]
    assert_includes result[:reason], "Minimum interval not elapsed"
  end

  speed_profile :fast
  test "should_checkpoint? handles nil last_checkpoint_time" do
    context = {
      trigger: :timer,
      last_checkpoint_time: nil,
      files_changed: 50
    }
    
    result = @policy.should_checkpoint?(context)
    
    assert result[:should_checkpoint]
  end

  speed_profile :fast
  test "should_checkpoint? defaults to timer trigger" do
    context = { last_checkpoint_time: Time.now.utc - 400 }
    
    result = @policy.should_checkpoint?(context)
    
    assert result[:should_checkpoint]
  end

  speed_profile :fast
  test "should_checkpoint? returns false for unknown trigger" do
    context = { trigger: :unknown }
    
    result = @policy.should_checkpoint?(context)
    
    refute result[:should_checkpoint]
    assert_includes result[:reason], "Unknown trigger"
  end

  speed_profile :fast
  test "should_checkpoint? raises error for non-hash context" do
    error = assert_raises(TypeError) do
      @policy.should_checkpoint?("not a hash")
    end
    assert_includes error.message, "context must be a Hash"
  end

  speed_profile :fast
  test "interval_elapsed? returns true when interval passed" do
    last_time = Time.now.utc - 400
    
    assert @policy.interval_elapsed?(last_time)
  end

  speed_profile :fast
  test "interval_elapsed? returns false when interval not passed" do
    last_time = Time.now.utc - 200
    
    refute @policy.interval_elapsed?(last_time)
  end

  speed_profile :fast
  test "interval_elapsed? returns true for nil last_checkpoint_time" do
    assert @policy.interval_elapsed?(nil)
  end

  speed_profile :fast
  test "too_many_changes? returns true when limit exceeded" do
    assert @policy.too_many_changes?(150)
  end

  speed_profile :fast
  test "too_many_changes? returns false when under limit" do
    refute @policy.too_many_changes?(50)
  end

  speed_profile :fast
  test "too_many_changes? returns false at exactly limit" do
    refute @policy.too_many_changes?(100)
  end

  speed_profile :fast
  test "min_interval_passed? returns true when minimum interval passed" do
    last_time = Time.now.utc - 120
    
    assert @policy.min_interval_passed?(last_time)
  end

  speed_profile :fast
  test "min_interval_passed? returns false when minimum interval not passed" do
    last_time = Time.now.utc - 30
    
    refute @policy.min_interval_passed?(last_time)
  end

  speed_profile :fast
  test "min_interval_passed? returns true for nil last_checkpoint_time" do
    assert @policy.min_interval_passed?(nil)
  end

  speed_profile :fast
  test "update_config updates configuration" do
    @policy.update_config(checkpoint_interval: 900)
    
    assert_equal 900, @policy.config[:checkpoint_interval]
  end

  speed_profile :fast
  test "update_config validates new configuration" do
    error = assert_raises(ArgumentError) do
      @policy.update_config(checkpoint_interval: -1)
    end
    assert_includes error.message, "checkpoint_interval must be positive"
  end

  speed_profile :fast
  test "policy with zero minimum interval allows immediate checkpoints" do
    policy = CheckpointPolicy.new(min_interval_between_checkpoints: 0)
    
    context = {
      trigger: :milestone,
      last_checkpoint_time: Time.now.utc - 1 # Just 1 second ago
    }
    
    result = policy.should_checkpoint?(context)
    
    assert result[:should_checkpoint]
  end

  speed_profile :fast
  test "policy handles edge case at exactly checkpoint interval" do
    context = {
      trigger: :timer,
      last_checkpoint_time: Time.now.utc - 300 # Exactly 300s
    }
    
    result = @policy.should_checkpoint?(context)
    
    assert result[:should_checkpoint]
  end

  speed_profile :fast
  test "policy handles edge case at exactly minimum interval" do
    context = {
      trigger: :milestone,
      last_checkpoint_time: Time.now.utc - 60 # Exactly 60s
    }
    
    result = @policy.should_checkpoint?(context)
    
    assert result[:should_checkpoint]
  end
end

