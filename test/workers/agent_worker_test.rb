# frozen_string_literal: true

require "test_helper"
require "ostruct"

class AgentWorkerTest < ActiveSupport::TestCase
  def setup
    @test_path = File.expand_path("../../fixtures/example_codebase", __FILE__)
  end

  # ==========================================================================
  # Test Action Registration
  # ==========================================================================
  speed_profile :slow
  test "registers actions via class method" do
    # Create a test subclass using the ActionRegistry DSL
    test_class = Class.new(AgentWorker) do
      include ActionRegistry
      register_action :test_action,
        class_name: "Actions::BaseAction",
        description: "A test action",
        parameters: { foo: { type: :string, required: true } }
    end

    assert test_class._registered_actions.key?(:test_action)
    assert_equal "A test action", test_class._registered_actions[:test_action][:description]
  end

  speed_profile :slow
  test "action_definitions returns formatted definitions" do
    test_class = Class.new(AgentWorker) do
      include ActionRegistry
      register_action :action_a, class_name: "Actions::BaseAction", description: "Action A"
      register_action :action_b, class_name: "Actions::BaseAction", description: "Action B"
    end

    definitions = test_class.action_definitions
    assert_equal 2, definitions.size
    assert definitions.any? { |d| d[:name] == "action_a" }
    assert definitions.any? { |d| d[:name] == "action_b" }
  end

  # ==========================================================================
  # Test Action Cache
  # ==========================================================================

  speed_profile :slow
  test "action cache stores results" do
    worker = create_minimal_agent

    result = worker.execute_with_cache(:test_action, { foo: "bar" }, "context123") do
      { success: true, data: "computed" }
    end

    assert_equal({ success: true, data: "computed" }, result)
    assert worker.action_cached?(:test_action, { foo: "bar" }, "context123")
  end

  speed_profile :slow
  test "action cache returns cached results on subsequent calls" do
    worker = create_minimal_agent
    call_count = 0

    # First call
    worker.execute_with_cache(:test_action, { foo: "bar" }, "context123") do
      call_count += 1
      { success: true, data: "first" }
    end

    # Second call with same inputs
    result = worker.execute_with_cache(:test_action, { foo: "bar" }, "context123") do
      call_count += 1
      { success: true, data: "second" }
    end

    assert_equal 1, call_count # Block should only execute once
    assert_equal "first", result[:data]
  end

  speed_profile :slow
  test "action cache tracks hit/miss stats" do
    worker = create_minimal_agent

    # First call - miss
    worker.execute_with_cache(:action1, {}, "ctx") { { success: true } }
    
    # Second call - hit
    worker.execute_with_cache(:action1, {}, "ctx") { { success: true } }
    
    # Third call - miss (different action)
    worker.execute_with_cache(:action2, {}, "ctx") { { success: true } }

    stats = worker.cache_stats
    assert_equal 1, stats[:hits]
    assert_equal 2, stats[:misses]
    assert_equal 2, stats[:size]
  end

  speed_profile :slow
  test "clear_action_cache! clears all cached results" do
    worker = create_minimal_agent

    worker.execute_with_cache(:action1, {}, "ctx") { { success: true } }
    assert_equal 1, worker.cache_stats[:size]

    worker.clear_action_cache!

    assert_equal 0, worker.cache_stats[:size]
    refute worker.action_cached?(:action1, {}, "ctx")
  end

  # ==========================================================================
  # Test State Machine
  # ==========================================================================

  speed_profile :slow
  test "starts in pending state" do
    worker = create_minimal_agent
    assert_equal :pending, worker.current_state
  end

  speed_profile :slow
  test "transitions through expected states" do
    worker = create_minimal_agent

    # Start
    worker.send(:trigger, :start)
    assert_equal :running, worker.current_state

    # Initialize
    worker.send(:trigger, :initialized)
    assert_equal :planning, worker.current_state
  end

  # ==========================================================================
  # Test Resource Limits
  # ==========================================================================

  speed_profile :slow
  test "resources_exhausted? respects max_iterations" do
    worker = create_minimal_agent(max_iterations: 5)

    4.times { worker.instance_variable_set(:@iteration_count, worker.iteration_count + 1) }
    refute worker.resources_exhausted?

    worker.instance_variable_set(:@iteration_count, 5)
    assert worker.resources_exhausted?
  end

  speed_profile :slow
  test "resources_exhausted? respects max_actions" do
    worker = create_minimal_agent(max_actions: 10)

    9.times { worker.instance_variable_set(:@action_count, worker.action_count + 1) }
    refute worker.resources_exhausted?

    worker.instance_variable_set(:@action_count, 10)
    assert worker.resources_exhausted?
  end

  # ==========================================================================
  # Test Available Actions
  # ==========================================================================

  speed_profile :slow
  test "available_actions returns registered action definitions" do
    # Create an AgentWorker subclass with registered actions for testing
    test_class = Class.new(AgentWorker) do
      include ActionRegistry

      register_action :test_action,
        class_name: "Actions::SearchFilesAction",
        description: "Test action",
        category: :test,
        parameters: { pattern: { type: :string, required: true } }

      def create_memory_store
        OpenStruct.new(
          get_section: ->(_) { [] },
          set_section: ->(_, _) {},
          record_state_transition: ->(**_) {}
        )
      end
    end

    worker = test_class.new(goal: "Test", path: @test_path)

    actions = worker.available_actions
    action_names = actions.map { |a| a[:name] }

    assert_includes action_names, "test_action"
  end

  
  def create_minimal_agent(**options)
    # Create a minimal agent subclass for testing
    test_class = Class.new(AgentWorker) do
      def create_memory_store
        # Use a mock memory store
        OpenStruct.new(
          get_section: ->(_) { [] },
          update_section: ->(**_) {},
          set_section: ->(_,_) {},
          record_state_transition: ->(**_) {},
          compressed_context_summary: ""
        )
      end
    end

    defaults = { goal: "Test goal", path: @test_path }
    test_class.new(**defaults.merge(options))
  end
end

