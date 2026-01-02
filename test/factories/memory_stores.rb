# frozen_string_literal: true

FactoryBot.define do
  # Factory for MemoryStore
  factory :memory_store, class: "MemoryStore" do
    skip_create

    transient do
      base_dir { Dir.mktmpdir("memory_store_test") }
      owner { SecureRandom.uuid }
    end

    initialize_with do
      memory_path = File.join(base_dir, owner, "memory.json")
      FileUtils.mkdir_p(File.dirname(memory_path))
      new(path: memory_path, owner_id: owner)
    end

    trait :with_decisions do
      after(:build) do |store|
        store.update_section(
          name: :decisions,
          content: { text: "Test decision", timestamp: Time.now.utc.iso8601 },
          append: true
        )
      end
    end

    trait :with_quest do
      after(:build) do |store|
        store.update_section(
          name: :quests,
          content: { text: "Find the dragon", timestamp: Time.now.utc.iso8601 },
          append: true
        )
      end
    end
  end

  # Factory for WorkflowMemoryStore
  factory :workflow_memory_store, class: "WorkflowMemoryStore" do
    skip_create

    transient do
      base_dir { Dir.mktmpdir("workflow_memory_test") }
      owner { SecureRandom.uuid }
      workflow_id_value { SecureRandom.uuid }
      workflow_name_value { "test_workflow" }
      parent { nil }
    end

    workflow_id { workflow_id_value }
    workflow_name { workflow_name_value }
    owner_id { owner }
    path { File.join(base_dir, owner, "workflows", "#{workflow_name_value}_#{workflow_id_value}.json") }
    
    initialize_with do
      FileUtils.mkdir_p(File.dirname(path))
      
      # Always create a real parent instance if not provided
      parent_instance = parent || begin
        parent_path = File.join(base_dir, owner, "parent_memory.json")
        FileUtils.mkdir_p(File.dirname(parent_path))
        MemoryStore.new(path: parent_path, owner_id: owner)
      end
      
      new(
        workflow_id: workflow_id,
        workflow_name: workflow_name,
        owner_id: owner_id,
        parent_id: parent_instance.id,
        path: path
      )
    end

    trait :with_decisions do
      after(:build) do |store|
        store.record_decision(
          decision: "Test decision",
          rationale: "Test rationale",
          context: {}
        )
      end
    end

    trait :with_state_transitions do
      after(:build) do |store|
        store.record_state_transition(from: :pending, to: :running, event: :start)
        store.record_state_transition(from: :running, to: :completed, event: :finish)
      end
    end
  end
end

