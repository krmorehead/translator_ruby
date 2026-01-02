require "test_helper"

class CurrentContextToolTest < ActiveSupport::TestCase
  def setup
    @owner_id = SecureRandom.uuid
    @store = MemoryStore.new(owner_id: @owner_id)
    @store.set_section(MemoryKinds::CURRENT_SCENE, "A dimly lit tavern")
    @store.set_section(MemoryKinds::PEOPLE, [ { text: "Barkeep" } ])
    @store.set_section(MemoryKinds::CURRENT_GOAL, "Find the missing scout")
    @store.set_section(MemoryKinds::RECENT_CONVERSATION, [ "Hello there" ])
    @store.save!
  end

  speed_profile :medium
  test "returns current context sections" do
    tool = CurrentContextTool.new()
    result = tool.execute(owner_id: @owner_id)

    assert result[:success]
    ctx = result[:result]
    assert_equal "A dimly lit tavern", ctx[:scene]
    assert_equal [ { text: "Barkeep" } ], ctx[:people]
    assert_equal "Find the missing scout", ctx[:current_quest]
    assert_equal [ "Hello there" ], ctx[:recent_conversation]
  end
end
