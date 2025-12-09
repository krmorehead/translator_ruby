require "test_helper"

class MemoryToolTest < ActiveSupport::TestCase
  def setup
    @sandbox_path = Rails.root.join("test", "tool_test", "memory_tool_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@sandbox_path)
    @tool = MemoryTool.new(sandbox_path: @sandbox_path)
  end

  def teardown
    FileUtils.rm_rf(@sandbox_path) if File.exist?(@sandbox_path)
  end

  test "schema includes operations" do
    schema = MemoryTool.schema
    ops = schema[:function][:parameters][:properties][:operation][:enum]
    assert_includes ops, MemoryTool::OP_GET
    assert_includes ops, MemoryTool::OP_UPDATE
  end

  test "list sections" do
    result = @tool.execute(operation: MemoryTool::OP_LIST)
    assert result[:success]
    assert_includes result[:result], :quests
  end

  test "update and get section append" do
    update = @tool.execute(operation: MemoryTool::OP_UPDATE, section: "quests", content: "Find the relic", append: true)
    assert update[:success]

    get = @tool.execute(operation: MemoryTool::OP_GET, section: "quests")
    assert_equal 1, get[:result].size
    assert_includes get[:result].first[:text] || get[:result].first["text"], "Find the relic"
  end

  test "update replace section" do
    @tool.execute(operation: MemoryTool::OP_UPDATE, section: "people", content: "Gimli", append: true)
    replace = @tool.execute(operation: MemoryTool::OP_UPDATE, section: "people", content: "Legolas", append: false)

    assert replace[:success]
    get = @tool.execute(operation: MemoryTool::OP_GET, section: "people")
    assert_equal 1, get[:result].size
    assert_includes get[:result].first[:text] || get[:result].first["text"], "Legolas"
  end

  test "rejects sandbox escape" do
    result = @tool.execute(operation: MemoryTool::OP_UPDATE, path: "/tmp/memory.json", section: "quests", content: "Test")
    refute result[:success]
    assert_includes result[:error], "outside the sandbox"
  end

  test "requires section name" do
    result = @tool.execute(operation: MemoryTool::OP_GET)
    refute result[:success]
    assert_includes result[:error], "section"
  end
end
