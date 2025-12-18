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

  # Context integration tests
  test "context_for returns a context for a section" do
    store = new_store
    store.update_section(name: :current_scene, content: { text: "Dark forest" }, append: false)

    context = store.context_for(:current_scene)

    assert_kind_of Contexts::BaseContext, context
    assert_equal 1, context.size
  end

  test "context_for uses memory class context_class" do
    store = new_store
    store.update_section(name: :current_scene, content: { text: "Castle" }, append: false)

    context = store.context_for(:current_scene)

    # CurrentSceneMemory specifies CurrentSceneContext
    assert_kind_of Contexts::CurrentSceneContext, context
  end

  test "context_for caches contexts" do
    store = new_store
    store.update_section(name: :people, content: "Gandalf", append: true)

    context1 = store.context_for(:people)
    context2 = store.context_for(:people)

    assert_equal context1.object_id, context2.object_id
  end

  test "set_section invalidates cached context" do
    store = new_store
    store.update_section(name: :people, content: "Gandalf", append: true)

    context1 = store.context_for(:people)
    store.set_section(:people, [{ text: "Aragorn" }])
    context2 = store.context_for(:people)

    refute_equal context1.object_id, context2.object_id
  end

  test "update_section invalidates cached context" do
    store = new_store
    context1 = store.context_for(:quests)

    store.update_section(name: :quests, content: "Find dragon", append: true)
    context2 = store.context_for(:quests)

    refute_equal context1.object_id, context2.object_id
  end

  test "full_context returns composite context with sub-contexts" do
    store = new_store
    store.update_section(name: :current_scene, content: { text: "Tavern" }, append: false)
    store.update_section(name: :people, content: "Bartender", append: true)

    full = store.full_context

    assert_kind_of Contexts::BaseContext, full
    assert full.has_sub_context?(:current_scene)
    assert full.has_sub_context?(:people)
  end

  test "invalidate_contexts clears all cached contexts" do
    store = new_store
    context1 = store.context_for(:people)

    store.invalidate_contexts!
    context2 = store.context_for(:people)

    refute_equal context1.object_id, context2.object_id
  end
end
