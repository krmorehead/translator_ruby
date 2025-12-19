require "test_helper"

class CurrentContextToolTest < ActiveSupport::TestCase
  def setup
    @sandbox = Rails.root.join("tmp", "current_context_tool_test").to_s
    FileUtils.mkdir_p(@sandbox)
    @memory_path = File.join(@sandbox, "memory.json")
    @store = MemoryStore.new(path: @memory_path)
    @store.set_section(MemoryKinds::CURRENT_SCENE, "A dimly lit tavern")
    @store.set_section(MemoryKinds::PEOPLE, [ { text: "Barkeep" } ])
    @store.set_section(MemoryKinds::CURRENT_GOAL, "Find the missing scout")
    @store.set_section(MemoryKinds::RECENT_CONVERSATION, [ "Hello there" ])
  end

  def teardown
    FileUtils.rm_rf(@sandbox)
  end

  test "returns current context sections" do
    tool = CurrentContextTool.new()
    result = tool.execute(path: @memory_path)

    assert result[:success]
    ctx = result[:result]
    assert_equal "A dimly lit tavern", ctx[:scene]
    assert_equal [ { text: "Barkeep" } ], ctx[:people]
    assert_equal "Find the missing scout", ctx[:current_quest]
    assert_equal [ "Hello there" ], ctx[:recent_conversation]
  end
end
