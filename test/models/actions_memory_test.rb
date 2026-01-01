# frozen_string_literal: true

require "test_helper"

class ActionsMemoryTest < ActiveSupport::TestCase
  speed_profile :fast
  test "section name is actions" do
    assert_equal "actions", Memories::ActionsMemory.section_name
  end

  speed_profile :fast
  test "default is empty array" do
    assert_equal [], Memories::ActionsMemory.default
  end

  speed_profile :fast
  test "registry includes actions memory" do
    sections = Memories::Registry::ALL.map(&:section_name)
    assert_includes sections, "actions"
  end

  speed_profile :fast
  test "memory store recognizes actions section" do
    sandbox = Rails.root.join("tmp", "actions_memory_test_#{Process.pid}_#{object_id}")
    FileUtils.mkdir_p(sandbox)
    store = MemoryStore.new(path: sandbox.join("memory.json"))

    assert_includes store.list_sections, :actions
    updated = store.update_section(name: MemoryKinds::ACTIONS, content: { action: "test" }, append: true)
    assert_kind_of Array, updated
    assert_equal "actions", MemoryKinds::ACTIONS
  ensure
    FileUtils.rm_rf(sandbox) if sandbox
  end
end
