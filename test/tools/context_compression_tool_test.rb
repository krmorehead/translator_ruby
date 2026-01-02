require "test_helper"

class ContextCompressionToolTest < ActiveSupport::TestCase
  def setup
    @owner_id = SecureRandom.uuid
    @store = MemoryStore.new(owner_id: @owner_id)
    @store.update_section(name: :current_scene, content: "A misty glade", append: false)
    @store.update_section(name: :people, content: "Elder Rowan", append: true)
    @store.update_section(name: :quest_log, content: "Recover the moonstone", append: true)
    @store.save!
  end

  speed_profile :medium
  test "returns weighted summaries for all sections" do
    tool = ContextCompressionTool.new()
    result = tool.execute(owner_id: @owner_id)

    assert result[:success]
    payload = result[:result]
    assert payload[:overall_summary].is_a?(String)
    assert payload[:sections].is_a?(Array)
    assert payload[:sections].any? { |s| s[:section] == "current_scene" }
    assert payload[:sections].any? { |s| s[:section] == "people" }
  end
end
