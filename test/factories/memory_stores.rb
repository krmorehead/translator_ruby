# frozen_string_literal: true

FactoryBot.define do
  # Factory for MemoryStore
  factory :memory_store, class: "MemoryStore" do
    skip_create

    transient do
      owner { SecureRandom.uuid }
    end

    initialize_with do
      new(owner_id: owner)
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
      owner { SecureRandom.uuid }
      workflow_id_value { SecureRandom.uuid }
      workflow_name_value { "test_workflow" }
      parent { nil }
    end
    
    initialize_with do
      workflow_path = File.join(ENV.fetch("AGENT_DATA_PATH"), owner, "workflows", "#{workflow_name_value}_#{workflow_id_value}.json")
      # Don't create directory here - let WorkflowMemoryStore.save! handle it
      
      # Always create a real parent instance if not provided
      parent_instance = parent || begin
        MemoryStore.new(owner_id: owner)
      end
      
      new(
        workflow_id: workflow_id_value,
        workflow_name: workflow_name_value,
        owner_id: owner,
        parent_id: parent_instance.id,
        path: workflow_path
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

