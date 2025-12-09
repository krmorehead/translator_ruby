require "test_helper"

class MemoryStoreTest < ActiveSupport::TestCase
  def setup
    @sandbox_path = Rails.root.join("test", "tool_test", "memory_store_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@sandbox_path)
    @path = File.join(@sandbox_path, "memory.json")
  end

  def teardown
    FileUtils.rm_rf(@sandbox_path) if File.exist?(@sandbox_path)
  end

  def new_store
    MemoryStore.new(path: @path, sandbox_path: @sandbox_path)
  end

  test "initializes defaults when file missing" do
    store = new_store
    assert_includes store.list_sections, :recent_conversation
    assert_equal [], store.get_section(:quests)
  end

  test "serialize and reload preserves sections" do
    store = new_store
    store.update_section(name: :quests, content: "Find the dragon", append: true)

    reloaded = new_store
    quests = reloaded.get_section(:quests)
    assert_equal 1, quests.size
    assert_includes quests.first[:text] || quests.first["text"], "Find the dragon"
  end

  test "append and replace behaviors" do
    store = new_store
    store.update_section(name: :people, content: "Gandalf", append: true)
    store.update_section(name: :people, content: "Aragorn", append: true)

    people = store.get_section(:people)
    assert_equal 2, people.size

    store.update_section(name: :people, content: "Legolas", append: false)
    people = store.get_section(:people)
    assert_equal 1, people.size
    assert_includes people.first[:text] || people.first["text"], "Legolas"
  end

  test "sandbox validation prevents escape" do
    assert_raises(SecurityError) do
      MemoryStore.new(path: "/tmp/memory.json", sandbox_path: @sandbox_path)
    end
  end

  test "update specific section and retrieve" do
    store = new_store
    store.update_section(name: :current_scene, content: { text: "In the tavern" }, append: false)

    scene = store.get_section(:current_scene)
    assert_equal 1, scene.size
    assert_equal "In the tavern", scene.first[:text] || scene.first["text"]
  end
end
