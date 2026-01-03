# frozen_string_literal: true

require "test_helper"

module Contexts
  class SisyphusContextTest < ActiveSupport::TestCase
    def setup
      @temp_dir = Dir.mktmpdir("sisyphus_context_test")
      @valid_params = {
        codebase_path: @temp_dir,
        plan_goal: "Create a test application",
        plan_id: "plan-#{SecureRandom.uuid}",
        execution_id: "exec-#{SecureRandom.uuid}"
      }
    end

    def teardown
      FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
    end

    # ===== Initialization Tests =====

    speed_profile :fast
    test "initializes with valid parameters" do
      context = SisyphusContext.new(**@valid_params)

      assert_equal @temp_dir, context.codebase_path
      assert_equal "Create a test application", context.plan_goal
      assert_equal @valid_params[:plan_id], context.plan_id
      assert_equal @valid_params[:execution_id], context.execution_id
      assert_nil context.current_milestone
      assert_nil context.current_step
      assert_equal({}, context.execution_metadata)
    end

    speed_profile :fast
    test "initializes with optional parameters" do
      milestone = { number: 1, title: "Setup", description: "Initial setup" }
      step = { number: "1.1", title: "Create file", intent: "Test" }
      metadata = { retry_count: 0, started_at: Time.now }

      context = SisyphusContext.new(
        **@valid_params,
        current_milestone: milestone,
        current_step: step,
        execution_metadata: metadata
      )

      assert_equal milestone, context.current_milestone
      assert_equal step, context.current_step
      assert_equal metadata, context.execution_metadata
    end

    # ===== Type Validation Tests =====

    speed_profile :fast
    test "raises TypeError if codebase_path is not a String" do
      error = assert_raises(TypeError) do
        SisyphusContext.new(**@valid_params.merge(codebase_path: 123))
      end
      
      assert_match(/codebase_path must be a String, got Integer/, error.message)
    end

    speed_profile :fast
    test "raises TypeError if plan_goal is not a String" do
      error = assert_raises(TypeError) do
        SisyphusContext.new(**@valid_params.merge(plan_goal: nil))
      end
      
      assert_match(/plan_goal must be a String/, error.message)
    end

    speed_profile :fast
    test "raises TypeError if plan_id is not a String" do
      error = assert_raises(TypeError) do
        SisyphusContext.new(**@valid_params.merge(plan_id: :symbol))
      end
      
      assert_match(/plan_id must be a String/, error.message)
    end

    speed_profile :fast
    test "raises TypeError if execution_id is not a String" do
      error = assert_raises(TypeError) do
        SisyphusContext.new(**@valid_params.merge(execution_id: { id: "test" }))
      end
      
      assert_match(/execution_id must be a String/, error.message)
    end

    speed_profile :fast
    test "raises TypeError if execution_metadata is not a Hash" do
      error = assert_raises(TypeError) do
        SisyphusContext.new(**@valid_params.merge(execution_metadata: "metadata"))
      end
      
      assert_match(/execution_metadata must be a Hash/, error.message)
    end

    # ===== Value Validation Tests =====

    speed_profile :fast
    test "raises ArgumentError if codebase_path is empty" do
      error = assert_raises(ArgumentError) do
        SisyphusContext.new(**@valid_params.merge(codebase_path: "   "))
      end
      
      assert_match(/codebase_path cannot be empty/, error.message)
    end

    speed_profile :fast
    test "raises ArgumentError if plan_goal is empty" do
      error = assert_raises(ArgumentError) do
        SisyphusContext.new(**@valid_params.merge(plan_goal: ""))
      end
      
      assert_match(/plan_goal cannot be empty/, error.message)
    end

    speed_profile :fast
    test "raises ArgumentError if codebase_path does not exist" do
      error = assert_raises(ArgumentError) do
        SisyphusContext.new(**@valid_params.merge(codebase_path: "/nonexistent/path"))
      end
      
      assert_match(/codebase_path must be a valid directory/, error.message)
    end

    speed_profile :fast
    test "expands relative codebase paths" do
      # Create a subdirectory
      subdir = File.join(@temp_dir, "subdir")
      FileUtils.mkdir_p(subdir)

      # Use relative path
      relative_path = File.join(File.basename(@temp_dir), "subdir")
      
      # Change to parent directory
      Dir.chdir(File.dirname(@temp_dir)) do
        context = SisyphusContext.new(**@valid_params.merge(codebase_path: relative_path))
        
        # Should be expanded to absolute path
        assert context.codebase_path.start_with?("/")
        assert_equal File.expand_path(relative_path), context.codebase_path
      end
    end

    # ===== Immutability Tests =====

    speed_profile :fast
    test "with_current_position creates new context with updated milestone" do
      original = SisyphusContext.new(**@valid_params)
      
      new_milestone = { number: 2, title: "Feature", description: "Add feature" }
      updated = original.with_current_position(milestone: new_milestone)

      # Original unchanged
      assert_nil original.current_milestone
      
      # New context has updated milestone
      assert_equal new_milestone, updated.current_milestone
      assert_equal original.plan_goal, updated.plan_goal
      assert_equal original.execution_id, updated.execution_id
    end

    speed_profile :fast
    test "with_current_position creates new context with updated step" do
      original = SisyphusContext.new(**@valid_params)
      
      new_step = { number: "2.1", title: "Implement", intent: "Code feature" }
      updated = original.with_current_position(step: new_step)

      # Original unchanged
      assert_nil original.current_step
      
      # New context has updated step
      assert_equal new_step, updated.current_step
    end

    speed_profile :fast
    test "with_current_position merges metadata" do
      original = SisyphusContext.new(
        **@valid_params,
        execution_metadata: { retry_count: 0 }
      )
      
      updated = original.with_current_position(metadata: { retry_count: 1, error: "test" })

      # Original unchanged
      assert_equal 0, original.execution_metadata[:retry_count]
      assert_nil original.execution_metadata[:error]
      
      # New context has merged metadata
      assert_equal 1, updated.execution_metadata[:retry_count]
      assert_equal "test", updated.execution_metadata[:error]
    end

    speed_profile :fast
    test "execution_metadata is frozen after initialization" do
      metadata = { count: 0 }
      context = SisyphusContext.new(**@valid_params, execution_metadata: metadata)

      assert context.execution_metadata.frozen?
      
      # Cannot mutate after creation
      assert_raises(FrozenError) do
        context.execution_metadata[:count] = 1
      end
    end

    # ===== Serialization Tests =====

    speed_profile :fast
    test "to_h serializes all context data" do
      milestone = { number: 1, title: "Setup" }
      step = { number: "1.1", title: "Init" }
      metadata = { retry_count: 0 }

      context = SisyphusContext.new(
        **@valid_params,
        current_milestone: milestone,
        current_step: step,
        execution_metadata: metadata
      )

      hash = context.to_h

      # Check sisyphus-specific data
      assert hash.key?(:sisyphus_context)
      sisyphus_data = hash[:sisyphus_context]

      assert_equal @temp_dir, sisyphus_data[:codebase_path]
      assert_equal "Create a test application", sisyphus_data[:plan_goal]
      assert_equal @valid_params[:plan_id], sisyphus_data[:plan_id]
      assert_equal @valid_params[:execution_id], sisyphus_data[:execution_id]
      assert_equal milestone, sisyphus_data[:current_milestone]
      assert_equal step, sisyphus_data[:current_step]
      assert_equal metadata, sisyphus_data[:execution_metadata]

      # Check BaseContext data
      assert hash.key?(:context_class)
      assert_equal "Contexts::SisyphusContext", hash[:context_class]
    end

    speed_profile :fast
    test "from_h deserializes context correctly" do
      original = SisyphusContext.new(
        **@valid_params,
        current_milestone: { number: 1, title: "Setup" },
        current_step: { number: "1.1", title: "Init" },
        execution_metadata: { retry_count: 0 }
      )

      # Add some entries to BaseContext
      original.add(
        content: "Previous execution succeeded",
        topics: ["execution", "history"],
        source: "test",
        metadata: { timestamp: Time.now }
      )

      hash = original.to_h
      deserialized = SisyphusContext.from_h(hash)

      assert_equal original.codebase_path, deserialized.codebase_path
      assert_equal original.plan_goal, deserialized.plan_goal
      assert_equal original.plan_id, deserialized.plan_id
      assert_equal original.execution_id, deserialized.execution_id
      assert_equal original.current_milestone, deserialized.current_milestone
      assert_equal original.current_step, deserialized.current_step
      assert_equal original.execution_metadata, deserialized.execution_metadata

      # Check BaseContext entries were preserved
      assert_equal original.entries.size, deserialized.entries.size
      assert_equal original.entries.first.content, deserialized.entries.first.content
    end

    speed_profile :fast
    test "from_h raises TypeError if data is not a Hash" do
      error = assert_raises(TypeError) do
        SisyphusContext.from_h("not a hash")
      end
      
      assert_match(/data must be a Hash/, error.message)
    end

    speed_profile :fast
    test "from_h raises ArgumentError if sisyphus_context key missing" do
      error = assert_raises(ArgumentError) do
        SisyphusContext.from_h({ context_class: "Contexts::SisyphusContext" })
      end
      
      assert_match(/data must contain :sisyphus_context key/, error.message)
    end

    # ===== Prompt Formatting Tests =====

    speed_profile :fast
    test "format_for_sisyphus_prompt includes all execution context" do
      milestone = { number: 1, title: "Setup Phase", description: "Initialize project" }
      step = { number: "1.1", title: "Create Config", intent: "Set up configuration" }
      metadata = { retry_count: 1, previous_error: "Permission denied" }

      context = SisyphusContext.new(
        **@valid_params,
        current_milestone: milestone,
        current_step: step,
        execution_metadata: metadata
      )

      formatted = context.format_for_sisyphus_prompt

      # Check all sections are present
      assert_match(/# Execution Context/, formatted)
      assert_match(/\*\*Codebase Path\*\*: `#{Regexp.escape(@temp_dir)}`/, formatted)
      assert_match(/\*\*Plan Goal\*\*: Create a test application/, formatted)
      assert_match(/## Current Milestone/, formatted)
      assert_match(/- \*\*Number\*\*: 1/, formatted)
      assert_match(/- \*\*Title\*\*: Setup Phase/, formatted)
      assert_match(/- \*\*Description\*\*: Initialize project/, formatted)
      assert_match(/## Current Step/, formatted)
      assert_match(/- \*\*Number\*\*: 1\.1/, formatted)
      assert_match(/- \*\*Title\*\*: Create Config/, formatted)
      assert_match(/- \*\*Intent\*\*: Set up configuration/, formatted)
      assert_match(/## Execution Metadata/, formatted)
      assert_match(/- \*\*Retry Count\*\*: 1/, formatted)
    end

    speed_profile :fast
    test "format_for_sisyphus_prompt works without optional fields" do
      context = SisyphusContext.new(**@valid_params)

      formatted = context.format_for_sisyphus_prompt

      # Basic fields present
      assert_match(/# Execution Context/, formatted)
      assert_match(/\*\*Plan Goal\*\*/, formatted)
      
      # Optional fields not present
      refute_match(/## Current Milestone/, formatted)
      refute_match(/## Current Step/, formatted)
      refute_match(/## Execution Metadata/, formatted)
    end

    speed_profile :fast
    test "format_for_sisyphus_prompt includes BaseContext entries" do
      context = SisyphusContext.new(**@valid_params)
      
      # Add context entries
      context.add(
        content: "Previous successful execution completed in 5 minutes",
        topics: ["execution", "performance"],
        source: "history",
        metadata: {}
      )
      
      context.add(
        content: "Known issue: permissions on /tmp directory",
        topics: ["issues", "permissions"],
        source: "warnings",
        metadata: {}
      )

      formatted = context.format_for_sisyphus_prompt

      assert_match(/## Additional Context/, formatted)
      assert_match(/Previous successful execution/, formatted)
    end

    # ===== Validation Helper Tests =====

    speed_profile :fast
    test "validate! passes for valid SisyphusContext" do
      context = SisyphusContext.new(**@valid_params)

      # Should not raise
      assert_nothing_raised do
        SisyphusContext.validate!(context)
      end
    end

    speed_profile :fast
    test "validate! raises TypeError for non-SisyphusContext" do
      base_context = Contexts::BaseContext.new

      error = assert_raises(TypeError) do
        SisyphusContext.validate!(base_context)
      end

      assert_match(/Expected SisyphusContext, got Contexts::BaseContext/, error.message)
      assert_match(/Example: SisyphusContext\.new/, error.message)
    end

    speed_profile :fast
    test "validate! provides helpful error message" do
      error = assert_raises(TypeError) do
        SisyphusContext.validate!("not a context")
      end

      # Error message includes example usage
      assert_match(/codebase_path:/, error.message)
      assert_match(/plan_goal:/, error.message)
      assert_match(/plan_id:/, error.message)
      assert_match(/execution_id:/, error.message)
    end

    # ===== Integration with BaseContext Tests =====

    speed_profile :fast
    test "inherits entry management from BaseContext" do
      context = SisyphusContext.new(**@valid_params)

      # Can add entries
      entry = context.add(
        content: "Test context entry",
        topics: ["test", "example"],
        source: "test_suite",
        metadata: { priority: "high" }
      )

      assert_equal 1, context.entries.size
      assert_equal "Test context entry", entry.content
      assert_equal ["test", "example"], entry.topics
    end

    speed_profile :fast
    test "inherits sub-context support from BaseContext" do
      context = SisyphusContext.new(**@valid_params)
      sub_context = Contexts::BaseContext.new

      sub_context.add(
        content: "Sub-context data",
        topics: ["nested"],
        source: "sub",
        metadata: {}
      )

      context.add_sub_context(:detailed_analysis, sub_context)

      assert context.has_sub_context?(:detailed_analysis)
      retrieved = context.get_sub_context(:detailed_analysis)
      assert_equal 1, retrieved.entries.size
    end
  end
end

