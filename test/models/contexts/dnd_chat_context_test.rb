# frozen_string_literal: true

require "test_helper"

class DndChatContextTest < ActiveSupport::TestCase
  def context
    @context ||= Contexts::DndChatContext.new
  end

  test "initializes with standard sub-contexts" do
    assert context.has_sub_context?(:scene)
    assert context.has_sub_context?(:people)
    assert context.has_sub_context?(:quests)
    assert context.has_sub_context?(:conversation)
    assert context.has_sub_context?(:actions)
  end

  test "scene returns CurrentSceneContext" do
    assert_kind_of Contexts::CurrentSceneContext, context.scene
  end

  test "add_person adds to people sub-context" do
    context.add_person(name: "Gandalf", description: "A wise wizard")

    assert_equal 1, context.people.size
    assert context.people.entries.first.content.include?("Gandalf")
  end

  test "add_quest adds to quests sub-context with status" do
    context.add_quest(
      title: "Find the Ring",
      description: "Locate the One Ring",
      status: "active"
    )

    assert_equal 1, context.quests.size
    entry = context.quests.entries.first
    assert entry.content.include?("[ACTIVE]")
    assert_equal "active", entry.metadata[:status]
  end

  test "add_message adds to conversation sub-context" do
    context.add_message(speaker: "Player", message: "I attack the dragon!")

    assert_equal 1, context.conversation.size
    assert context.conversation.entries.first.content.include?("Player:")
  end

  test "add_action adds to actions sub-context" do
    context.add_action(action_name: "attack", result: "Hit for 10 damage")

    assert_equal 1, context.actions.size
  end

  test "format_for_action_detection includes scene and conversation" do
    context.scene.set_location(name: "Dark Cave", description: "A damp, dark cave")
    context.add_message(speaker: "DM", message: "You see a goblin")

    formatted = context.format_for_action_detection

    assert formatted.include?("Dark Cave") || formatted.include?("damp")
    assert formatted.include?("goblin")
  end

  test "format_for_narrative includes completed actions" do
    context.scene.set_location(name: "Tavern", description: "A cozy tavern")
    context.add_action(action_name: "attack goblin", result: "Success!")

    formatted = context.format_for_narrative

    assert formatted.include?("attack goblin") || formatted.include?("Success")
  end

  test "format_for_prompt with :action_detection format" do
    context.scene.set_location(name: "Forest", description: "Dense trees")

    formatted = context.format_for_prompt("attack", format: :action_detection)

    assert formatted.include?("Forest") || formatted.include?("trees")
  end

  test "format_for_prompt with :narrative format" do
    context.scene.set_location(name: "Castle", description: "Grand hall")

    formatted = context.format_for_prompt("narrate", format: :narrative)

    assert formatted.is_a?(String)
  end

  test "serializes and deserializes correctly" do
    context.add_person(name: "Frodo", description: "A hobbit")
    context.add_quest(title: "Destroy Ring", description: "Mount Doom", status: "active")
    context.scene.set_location(name: "Shire", description: "Peaceful land")

    hash = context.to_h
    restored = Contexts::DndChatContext.from_h(hash)

    assert_equal context.people.size, restored.people.size
    assert_equal context.quests.size, restored.quests.size
  end

  test "condense works on DndChatContext" do
    10.times { |i| context.add_person(name: "NPC#{i}", description: "Character #{i}") }

    condensed = context.condense(max_entries: 3)

    assert_kind_of Contexts::DndChatContext, condensed
    assert condensed.people.size <= 3
  end
end

