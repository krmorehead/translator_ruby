# frozen_string_literal: true

require "test_helper"

class ModelInteractionMemoryTest < ActiveSupport::TestCase
  setup do
    @sandbox = Rails.root.join("tmp", "model_interaction_test_#{Process.pid}_#{Thread.current.object_id}")
    FileUtils.mkdir_p(@sandbox)
    @memory_path = @sandbox.join("memory.json")
    @owner_id = SecureRandom.uuid
    @store = MemoryStore.new(owner_id: @owner_id)
  end

  teardown do
    FileUtils.rm_rf(@sandbox)
  end
  speed_profile :fast
  test "section_name returns model_interactions" do
    assert_equal MemoryKinds::MODEL_INTERACTIONS, Memories::TrainingData::ModelInteractionMemory.section_name
  end

  speed_profile :fast
  test "default returns empty array" do
    assert_equal [], Memories::TrainingData::ModelInteractionMemory.default
  end

  speed_profile :fast
  test "weight is 0.0" do
    assert_equal 0.0, Memories::TrainingData::ModelInteractionMemory.weight
  end

  speed_profile :fast
  test "append adds interaction to store" do
    interaction = {
      request: {
        model: "test-model",
        messages: [{ role: "user", content: "test" }]
      },
      response: {
        content: "response",
        finish_reason: "stop"
      },
      thoughts: "test thoughts"
    }

    Memories::TrainingData::ModelInteractionMemory.append(store: @store, interaction: interaction)

    interactions = @store.get_section(MemoryKinds::MODEL_INTERACTIONS)
    assert_equal 1, interactions.size
    assert_equal "test-model", interactions.first[:request][:model]
    assert_equal "test thoughts", interactions.first[:thoughts]
  end

  speed_profile :fast
  test "append adds timestamp to entry" do
    interaction = {
      request: { model: "test" },
      response: { content: "test" },
      thoughts: nil
    }

    Memories::TrainingData::ModelInteractionMemory.append(store: @store, interaction: interaction)

    interactions = @store.get_section(MemoryKinds::MODEL_INTERACTIONS)
    assert interactions.first.key?(:timestamp)
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, interactions.first[:timestamp])
  end

  speed_profile :fast
  test "append handles nil thoughts" do
    interaction = {
      request: { model: "test" },
      response: { content: "test" },
      thoughts: nil
    }

    Memories::TrainingData::ModelInteractionMemory.append(store: @store, interaction: interaction)

    interactions = @store.get_section(MemoryKinds::MODEL_INTERACTIONS)
    assert_nil interactions.first[:thoughts]
  end

  speed_profile :fast
  test "to_h returns all interactions" do
    interactions = [
      { request: { model: "model1" }, response: { content: "r1" }, thoughts: "t1" },
      { request: { model: "model2" }, response: { content: "r2" }, thoughts: nil }
    ]

    interactions.each do |interaction|
      Memories::TrainingData::ModelInteractionMemory.append(store: @store, interaction: interaction)
    end

    result = Memories::TrainingData::ModelInteractionMemory.to_h(store: @store)
    assert_equal 2, result.size
  end

  speed_profile :fast
  test "to_h returns default when section empty" do
    result = Memories::TrainingData::ModelInteractionMemory.to_h(store: @store)
    assert_equal [], result
  end

  speed_profile :fast
  test "summarize returns interaction count" do
    interaction = {
      request: { model: "test" },
      response: { content: "test" },
      thoughts: "thoughts"
    }

    3.times do
      Memories::TrainingData::ModelInteractionMemory.append(store: @store, interaction: interaction)
    end

    summary = Memories::TrainingData::ModelInteractionMemory.summarize(store: @store)
    assert_equal MemoryKinds::MODEL_INTERACTIONS, summary[:section]
    assert_includes summary[:summary], "3 model interaction"
  end

  speed_profile :fast
  test "multiple interactions maintain order" do
    3.times do |i|
      interaction = {
        request: { model: "model-#{i}" },
        response: { content: "response #{i}" },
        thoughts: "thoughts #{i}"
      }
      Memories::TrainingData::ModelInteractionMemory.append(store: @store, interaction: interaction)
    end

    interactions = Memories::TrainingData::ModelInteractionMemory.to_h(store: @store)
    assert_equal 3, interactions.size
    assert_equal "model-0", interactions[0][:request][:model]
    assert_equal "model-1", interactions[1][:request][:model]
    assert_equal "model-2", interactions[2][:request][:model]
  end
end

