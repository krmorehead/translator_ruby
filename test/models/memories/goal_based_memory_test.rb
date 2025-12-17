require "test_helper"

class GoalBasedMemoryTest < ActiveSupport::TestCase
  def setup
    @test_dir = Rails.root.join("tmp", "goal_memory_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@test_dir)
    @store_path = File.join(@test_dir, "test_memory.json")

    # Create a concrete subclass for testing
    @test_memory_class = Class.new(Memories::GoalBasedMemory) do
      def self.section_name
        "test_goals"
      end
    end

    # Initialize store with the test section
    @sections = { test_goals: [] }
    File.write(@store_path, JSON.generate(@sections))
  end

  def teardown
    FileUtils.rm_rf(@test_dir) if @test_dir && File.exist?(@test_dir)
  end

  def create_store
    # Create a mock store that works with our test section
    store = Object.new
    store.instance_variable_set(:@path, @store_path)
    store.instance_variable_set(:@sections, @sections)

    def store.get_section(name)
      @sections[name.to_sym]
    end

    def store.set_section(name, value)
      @sections[name.to_sym] = value
      File.write(@path, JSON.generate(@sections))
      value
    end

    store
  end

  test "goal entry structure includes status" do
    entry = @test_memory_class.create_goal_entry(content: "Test goal")

    assert_not_nil entry[:id]
    assert_equal "Test goal", entry[:text]
    assert_equal Memories::GoalBasedMemory::STATUS_PENDING, entry[:status]
    assert_equal 1, entry[:priority]
    assert_not_nil entry[:created_at]
    assert_not_nil entry[:timestamp]
  end

  test "active_goals filters correctly" do
    store = create_store

    @sections[:test_goals] = [
      { id: "1", text: "Active goal", status: "active" },
      { id: "2", text: "Pending goal", status: "pending" },
      { id: "3", text: "Complete goal", status: "complete" },
      { id: "4", text: "Another active", status: "active" }
    ]

    active = @test_memory_class.active_goals(store: store)

    assert_equal 2, active.size
    assert active.all? { |g| g[:status] == "active" }
  end

  test "pending_goals filters correctly" do
    store = create_store

    @sections[:test_goals] = [
      { id: "1", text: "Active goal", status: "active" },
      { id: "2", text: "Pending goal", status: "pending" },
      { id: "3", text: "Another pending", status: "pending" }
    ]

    pending = @test_memory_class.pending_goals(store: store)

    assert_equal 2, pending.size
    assert pending.all? { |g| g[:status] == "pending" }
  end

  test "complete_goal updates status by id" do
    store = create_store

    @sections[:test_goals] = [
      { id: "goal-1", text: "First goal", status: "active" },
      { id: "goal-2", text: "Second goal", status: "active" }
    ]

    result = @test_memory_class.complete_goal(store: store, id: "goal-1")

    assert_not_nil result
    assert_equal "complete", result[:status]
    assert_not_nil result[:completed_at]

    # Check the store was updated
    updated = @sections[:test_goals].find { |g| g[:id] == "goal-1" }
    assert_equal "complete", updated[:status]
  end

  test "complete_goal updates status by index" do
    store = create_store

    @sections[:test_goals] = [
      { id: "goal-1", text: "First goal", status: "active" },
      { id: "goal-2", text: "Second goal", status: "active" }
    ]

    result = @test_memory_class.complete_goal(store: store, id: 1)

    assert_not_nil result
    assert_equal "goal-2", result[:id]
    assert_equal "complete", result[:status]
  end

  test "complete_goal returns nil for non-existent goal" do
    store = create_store
    @sections[:test_goals] = []

    result = @test_memory_class.complete_goal(store: store, id: "nonexistent")

    assert_nil result
  end

  test "activate_goal changes pending to active" do
    store = create_store

    @sections[:test_goals] = [
      { id: "goal-1", text: "Pending goal", status: "pending" }
    ]

    result = @test_memory_class.activate_goal(store: store, id: "goal-1")

    assert_not_nil result
    assert_equal "active", result[:status]
    assert_not_nil result[:activated_at]
  end

  test "default weight is 0.9" do
    assert_equal 0.9, @test_memory_class.weight
  end

  test "summarize groups goals by status" do
    store = create_store

    @sections[:test_goals] = [
      { id: "1", text: "Active 1", status: "active" },
      { id: "2", text: "Active 2", status: "active" },
      { id: "3", text: "Pending 1", status: "pending" },
      { id: "4", text: "Complete 1", status: "complete" }
    ]

    summary = @test_memory_class.summarize(store: store)

    assert_equal "test_goals", summary[:section]
    assert_equal 2, summary[:active_count]
    assert_equal 1, summary[:pending_count]
    assert_equal 1, summary[:complete_count]
    assert_equal 4, summary[:total_count]
    assert_includes summary[:summary], "Active 1"
    assert_includes summary[:summary], "Pending 1"
  end

  test "create_goal_entry with hash content" do
    entry = @test_memory_class.create_goal_entry(
      content: { text: "Hash goal", extra: "data" },
      priority: 5,
      status: "active"
    )

    assert_equal "Hash goal", entry[:text]
    assert_equal 5, entry[:priority]
    assert_equal "active", entry[:status]
  end

  test "inherits from BaseMemory" do
    assert Memories::GoalBasedMemory < Memories::BaseMemory
  end
end

