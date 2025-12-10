# frozen_string_literal: true

require "test_helper"

class QuestLogMemoryTest < ActiveSupport::TestCase
  def setup
    @sandbox_path = Rails.root.join("test", "tool_test", "quest_log_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@sandbox_path)
    @path = File.join(@sandbox_path, "memory.json")
    @store = MemoryStore.new(path: @path, sandbox_path: @sandbox_path)
  end

  def teardown
    FileUtils.rm_rf(@sandbox_path) if File.exist?(@sandbox_path)
  end

  test "adds quests to quest_log" do
    Memories::QuestLogMemory.add(@store, text: "Find the dragon")
    entries = Memories::QuestLogMemory.entries(@store)
    assert_equal 1, entries.size
    assert_equal "Find the dragon", entries.first[:text] || entries.first["text"]
  end

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

  test "raises when quest not found" do
    assert_raises(ArgumentError) do
      Memories::QuestLogMemory.set_main(@store, text: "Missing quest")
    end
  end

  test "requires text or index" do
    assert_raises(ArgumentError) do
      Memories::QuestLogMemory.set_main(@store)
    end
  end
end
