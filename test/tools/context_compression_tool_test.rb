require "test_helper"

class ContextCompressionToolTest < ActiveSupport::TestCase
  def setup
    @sandbox = Rails.root.join("tmp", "context_compression_tool_test").to_s
    FileUtils.mkdir_p(@sandbox)
    @memory_path = File.join(@sandbox, "memory.json")
    @store = MemoryStore.new(path: @memory_path, sandbox_path: @sandbox)
    @store.update_section(name: :current_scene, content: "A misty glade", append: false)
    @store.update_section(name: :people, content: "Elder Rowan", append: true)
    @store.update_section(name: :quest_log, content: "Recover the moonstone", append: true)
  end

  def teardown
    FileUtils.rm_rf(@sandbox)
  end

  test "returns weighted summaries for all sections" do
    tool = ContextCompressionTool.new(sandbox_path: @sandbox)
    result = tool.execute(path: @memory_path)

    assert result[:success]
    payload = result[:result]
    assert payload[:overall_summary].is_a?(String)
    assert payload[:sections].is_a?(Array)
    assert payload[:sections].any? { |s| s[:section] == "current_scene" }
    assert payload[:sections].any? { |s| s[:section] == "people" }
  end
end
