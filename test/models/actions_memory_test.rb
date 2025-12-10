# frozen_string_literal: true

require "test_helper"

class ActionsMemoryTest < ActiveSupport::TestCase
  test "section name is actions" do
    assert_equal "actions", Memories::ActionsMemory.section_name
  end

  test "default is empty array" do
    assert_equal [], Memories::ActionsMemory.default
  end

  test "registry includes actions memory" do
    sections = Memories::Registry::ALL.map(&:section_name)
    assert_includes sections, "actions"
  end

  test "memory store recognizes actions section" do
    sandbox = Rails.root.join("tmp", "actions_memory_test_#{Process.pid}_#{object_id}")
    FileUtils.mkdir_p(sandbox)
    store = MemoryStore.new(path: sandbox.join("memory.json"), sandbox_path: sandbox)

    assert_includes store.list_sections, :actions
    updated = store.update_section(name: MemoryKinds::ACTIONS, content: { action: "test" }, append: true)
    assert_kind_of Array, updated
    assert_equal "actions", MemoryKinds::ACTIONS
  ensure
    FileUtils.rm_rf(sandbox) if sandbox
  end
end
