require "test_helper"

class MemorySummarizeToolTest < ActiveSupport::TestCase
  def setup
    @sandbox_path = Rails.root.join("test", "tool_test", "memory_sum_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@sandbox_path)
    @path = File.join(@sandbox_path, "memory.json")

    @store = MemoryStore.new(path: @path)
    @store.update_section(name: :quests, content: "Rescue the prince", append: true)
    @store.update_section(name: :quests, content: "Find the lost sword", append: true)
    @store.update_section(name: :current_goal, content: "Enter the castle", append: false)
    @store.update_section(name: :people, content: "Aria the ranger", append: true)
    @store.update_section(name: :recent_conversation, content: "We camped near the river.", append: true)
    @store.update_section(name: :quest_log, content: "Rescue the prince", append: true)
  end

  def teardown
    FileUtils.rm_rf(@sandbox_path) if File.exist?(@sandbox_path)
  end

  test "schema requires target" do
    schema = MemorySummarizeTool.schema
    props = schema[:function][:parameters][:properties]
    assert props.key?(:target)
  end

  test "summarizes a person" do
    tool = MemorySummarizeTool.new()
    result = tool.execute(target: "person", name: "Aria", path: @path)

    assert result[:success]
    payload = result[:result]
    assert_equal "person", payload[:target]
    assert_includes payload[:summary], "Aria the ranger"
  end

  test "summarizes a location" do
    @store.update_section(name: :current_scene, content: "A quiet forest", append: false)
    tool = MemorySummarizeTool.new()
    result = tool.execute(target: "location", name: "forest", path: @path)

    assert result[:success]
    payload = result[:result]
    assert_equal "location", payload[:target]
    assert payload[:summary].is_a?(String)
  end

  test "summarizes quest log" do
    tool = MemorySummarizeTool.new()
    result = tool.execute(target: "quest_log", path: @path)

    assert result[:success]
    payload = result[:result]
    assert_equal "quest_log", payload[:target]
    assert_includes payload[:summary], "Rescue the prince"
  end
end
