require "test_helper"

class MemorySummarizeToolTest < ActiveSupport::TestCase
  def setup
    @sandbox_path = Rails.root.join("test", "tool_test", "memory_sum_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@sandbox_path)
    @path = File.join(@sandbox_path, "memory.json")

    @store = MemoryStore.new(path: @path, sandbox_path: @sandbox_path)
    @store.update_section(name: :quests, content: "Rescue the prince", append: true)
    @store.update_section(name: :quests, content: "Find the lost sword", append: true)
    @store.update_section(name: :current_goal, content: "Enter the castle", append: false)
    @store.update_section(name: :people, content: "Aria the ranger", append: true)
    @store.update_section(name: :recent_conversation, content: "We camped near the river.", append: true)
  end

  def teardown
    FileUtils.rm_rf(@sandbox_path) if File.exist?(@sandbox_path)
  end

  test "schema requires sections" do
    schema = MemorySummarizeTool.schema
    props = schema[:function][:parameters][:properties]
    assert props.key?(:sections)
  end

  test "summarizes selected sections and extracts keys" do
    tool = MemorySummarizeTool.new(sandbox_path: @sandbox_path)
    result = tool.execute(sections: [ "quests", "recent_conversation", "current_goal", "people" ], path: @path, max_tokens: 20)

    assert result[:success]
    payload = result[:result]
    assert_includes payload[:summary], "Rescue the prince"
    assert_includes payload[:summary], "camped near the river"
    assert_includes payload[:key_points][:quests], "Rescue the prince"
    assert_includes payload[:key_points][:quests], "Find the lost sword"
    assert_includes payload[:key_points][:goals], "Enter the castle"
    assert_includes payload[:key_points][:people], "Aria the ranger"
  end

  test "handles empty sections gracefully" do
    tool = MemorySummarizeTool.new(sandbox_path: @sandbox_path)
    result = tool.execute(sections: [ "misc" ], path: @path)

    assert result[:success]
    assert_equal "", result[:result][:summary]
    assert_equal [], result[:result][:key_points][:quests]
  end

  test "rejects sandbox escape" do
    tool = MemorySummarizeTool.new(sandbox_path: @sandbox_path)
    result = tool.execute(sections: [ "quests" ], path: "/tmp/memory.json")

    refute result[:success]
    assert_includes result[:error], "outside the sandbox"
  end
end
