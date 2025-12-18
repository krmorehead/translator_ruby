# frozen_string_literal: true

require "test_helper"

class CurrentSceneContextTest < ActiveSupport::TestCase
  def context
    @context ||= Contexts::CurrentSceneContext.new
  end

  test "initializes with optional location and atmosphere" do
    ctx = Contexts::CurrentSceneContext.new(location_name: "Castle", atmosphere: "tense")

    assert_equal "Castle", ctx.location_name
    assert_equal "tense", ctx.atmosphere
  end

  test "set_location creates an entry and sets location_name" do
    context.set_location(name: "Dark Forest", description: "Twisted trees block the moonlight")

    assert_equal "Dark Forest", context.location_name
    assert_equal 1, context.size
    assert context.location.content.include?("Twisted trees")
  end

  test "set_atmosphere creates an entry and sets atmosphere" do
    context.set_atmosphere(description: "The air is thick with tension", mood: "tense")

    assert_equal "tense", context.atmosphere
    assert_equal 1, context.size
  end

  test "add_npc adds an NPC entry" do
    context.add_npc(name: "Goblin Guard", description: "A mean-looking goblin", disposition: "hostile")

    npcs = context.npcs
    assert_equal 1, npcs.size
    assert_equal "hostile", npcs.first.metadata[:disposition]
  end

  test "add_hazard adds a hazard entry with severity" do
    context.add_hazard(name: "Pit Trap", description: "Hidden pit in the floor", severity: "severe")

    hazards = context.hazards
    assert_equal 1, hazards.size
    assert hazards.first.content.include?("[HAZARD - SEVERE]")
  end

  test "add_object adds an interactive object" do
    context.add_object(name: "Treasure Chest", description: "An ornate chest", interactable: true)

    assert_equal 1, context.size
  end

  test "add_exit adds an exit entry" do
    context.add_exit(direction: "north", destination: "Castle Gates")

    exits = context.exits
    assert_equal 1, exits.size
    assert_equal "north", exits.first.metadata[:direction]
  end

  test "format_immersive creates narrative description" do
    context.set_location(name: "Tavern", description: "A warm, cozy tavern")
    context.set_atmosphere(description: "Laughter fills the air", mood: "jovial")
    context.add_npc(name: "Bartender", description: "Friendly innkeep", disposition: "friendly")

    formatted = context.format_immersive

    assert formatted.include?("warm, cozy tavern")
    assert formatted.include?("Laughter")
  end

  test "format_tactical creates brief summary" do
    context.set_location(name: "Arena", description: "Combat arena")
    context.add_npc(name: "Gladiator", description: "Armed warrior", disposition: "hostile")
    context.add_hazard(name: "Spikes", description: "Floor spikes", severity: "moderate")
    context.add_exit(direction: "south", destination: "Gates")

    formatted = context.format_tactical

    assert formatted.include?("Arena")
    assert formatted.include?("Gladiator")
    assert formatted.include?("Hazards:")
    assert formatted.include?("south")
  end

  test "format_for_prompt with :immersive format" do
    context.set_location(name: "Dungeon", description: "Cold stone walls")

    formatted = context.format_for_prompt("describe", format: :immersive)
    assert formatted.include?("Cold stone walls")
  end

  test "format_for_prompt with :tactical format" do
    context.set_location(name: "Battlefield", description: "Open field")

    formatted = context.format_for_prompt("assess", format: :tactical)
    assert formatted.include?("Battlefield")
  end

  test "serializes with location_name and atmosphere" do
    context.set_location(name: "Temple", description: "Ancient temple")
    context.set_atmosphere(description: "Sacred silence", mood: "reverent")

    hash = context.to_h
    assert_equal "Temple", hash[:location_name]
    assert_equal "reverent", hash[:atmosphere]
  end

  test "deserializes with location_name and atmosphere" do
    context.set_location(name: "Library", description: "Dusty tomes")

    hash = context.to_h
    restored = Contexts::CurrentSceneContext.from_h(hash)

    assert_equal "Library", restored.location_name
    assert_equal 1, restored.size
  end
end

