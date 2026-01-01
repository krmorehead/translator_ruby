require "test_helper"

class MemoryToolTest < ActiveSupport::TestCase
  def setup
    @test_path = Rails.root.join("test", "tool_test", "memory_tool_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@test_path)
    @tool = MemoryTool.new
  end

  def teardown
    FileUtils.rm_rf(@test_path) if File.exist?(@test_path)
  end
  speed_profile :medium
  test "schema includes operations" do
    schema = MemoryTool.schema
    ops = schema[:function][:parameters][:properties][:operation][:enum]
    assert_includes ops, MemoryTool::OP_GET
    assert_includes ops, MemoryTool::OP_UPDATE
  end

  speed_profile :medium
  test "list sections" do
    result = @tool.execute(operation: MemoryTool::OP_LIST, path: File.join(@test_path, "memory.json"), section: "", content: nil, append: true)
    assert result[:success]
    assert_includes result[:result], :quests
  end

  speed_profile :medium
  test "update and get section append" do
    update = @tool.execute(operation: MemoryTool::OP_UPDATE, path: File.join(@test_path, "memory.json"), section: "quests", content: "Find the relic", append: true)
    assert update[:success]

    get = @tool.execute(operation: MemoryTool::OP_GET, path: File.join(@test_path, "memory.json"), section: "quests", content: nil, append: true)
    assert_equal 1, get[:result].size
    # Content is stored as-is (string in this case)
    assert_includes get[:result].first.to_s, "Find the relic"
  end

  speed_profile :medium
  test "update replace section" do
    path = File.join(@test_path, "memory.json")
    @tool.execute(operation: MemoryTool::OP_UPDATE, path: path, section: "people", content: "Gimli", append: true)
    replace = @tool.execute(operation: MemoryTool::OP_UPDATE, path: path, section: "people", content: "Legolas", append: false)

    assert replace[:success]
    get = @tool.execute(operation: MemoryTool::OP_GET, path: path, section: "people", content: nil, append: true)
    assert_equal 1, get[:result].size
    # Content is stored as-is (string in this case)
    assert_includes get[:result].first.to_s, "Legolas"
  end

  speed_profile :medium
  test "requires section name" do
    result = @tool.execute(operation: MemoryTool::OP_GET, path: File.join(@test_path, "memory.json"), section: nil, content: nil, append: true)
    refute result[:success]
    assert_includes result[:error], "section"
  end
end
