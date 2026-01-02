# frozen_string_literal: true

require "test_helper"

class QuestLogMemoryTest < ActiveSupport::TestCase
  def setup

    @store = MemoryStore.new(owner_id: SecureRandom.uuid)
  end

  def teardown
    FileUtils.rm_rf(@sandbox_path) if File.exist?(@sandbox_path)
  end
  speed_profile :fast
  test "adds quests to quest_log" do
    Memories::QuestLogMemory.add(@store, text: "Find the dragon")
    entries = Memories::QuestLogMemory.entries(@store)
    assert_equal 1, entries.size
    assert_equal "Find the dragon", entries.first[:text] || entries.first["text"]
  end

  speed_profile :fast
  test "sets main and current flags" do
    Memories::QuestLogMemory.add(@store, text: "Rescue the prince")
    Memories::QuestLogMemory.add(@store, text: "Explore the ruins")

    Memories::QuestLogMemory.set_main(@store, text: "Rescue the prince")
    Memories::QuestLogMemory.set_current(@store, text: "Explore the ruins")

    entries = Memories::QuestLogMemory.entries(@store)
    prince = entries.find { |e| (e[:text] || e["text"]) == "Rescue the prince" }
    ruins = entries.find { |e| (e[:text] || e["text"]) == "Explore the ruins" }

    assert_equal true, prince[:main] || prince["main"]
    assert_nil prince[:current] || prince["current"]
    assert_equal true, ruins[:current] || ruins["current"]
    assert_nil ruins[:main] || ruins["main"]
  end

  speed_profile :fast
  test "raises when quest not found" do
    assert_raises(ArgumentError) do
      Memories::QuestLogMemory.set_main(@store, text: "Missing quest")
    end
  end

  speed_profile :fast
  test "requires text or index" do
    assert_raises(ArgumentError) do
      Memories::QuestLogMemory.set_main(@store)
    end
  end
end

