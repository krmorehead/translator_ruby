# frozen_string_literal: true

FactoryBot.define do
  # Factory for ResearchMemoryStore
  factory :research_memory_store, class: "ResearchMemoryStore" do
    skip_create

    transient do
      owner_id { SecureRandom.uuid }
      workflow_id { SecureRandom.uuid }
      workflow_name { "research_workflow" }
      parent_id { SecureRandom.uuid }
    end

    initialize_with do
      ResearchMemoryStore.new(
        workflow_id: workflow_id,
        workflow_name: workflow_name,
        parent_id: parent_id,
        owner_id: owner_id
      )
    end

    trait :with_goal do
      after(:build) do |store|
        store.set_section(:research_goal, [
          { text: "Test research goal", status: "active", timestamp: Time.now.utc.iso8601 }
        ])
      end
    end

    trait :with_sub_questions do
      after(:build) do |store|
        store.set_section(:sub_questions, [
          { text: "Sub question 1", is_leaf: true, priority: 1, timestamp: Time.now.utc.iso8601 },
          { text: "Sub question 2", is_leaf: false, priority: 2, timestamp: Time.now.utc.iso8601 }
        ])
      end
    end

    trait :with_discovered_files do
      after(:build) do |store|
        store.set_section(:discovered_files, [
          { path: "app/models/user.rb", relevance_score: 0.9, timestamp: Time.now.utc.iso8601 },
          { path: "app/services/auth.rb", relevance_score: 0.8, timestamp: Time.now.utc.iso8601 }
        ])
      end
    end

    trait :with_context_chain do
      after(:build) do |store|
        store.push_context(sub_question: "Question 1", key_insights: "Insight 1")
        store.push_context(sub_question: "Question 2", key_insights: "Insight 2")
      end
    end

    trait :full do
      with_goal
      with_sub_questions
      with_discovered_files
      with_context_chain
    end
  end

  # Factory for worker context (seed information)
  factory :research_context, class: "Hash" do
    skip_create

    known_files { [] }
    prior_findings { nil }
    focus_areas { [] }
    codebase_summary { nil }
    constraints { {} }

    initialize_with do
      {
        known_files: known_files,
        prior_findings: prior_findings,
        focus_areas: focus_areas,
        codebase_summary: codebase_summary,
        constraints: constraints
      }.compact
    end

    trait :with_known_files do
      known_files { ["app/models/user.rb", "app/services/auth_service.rb"] }
    end

    trait :with_prior_findings do
      prior_findings { "The authentication system uses JWT tokens and Redis for session storage." }
    end

    trait :with_focus_areas do
      focus_areas { ["error handling", "security", "performance"] }
    end

    trait :with_codebase_summary do
      codebase_summary { "A Rails API application for e-commerce with payment processing." }
    end

    trait :full do
      with_known_files
      with_prior_findings
      with_focus_areas
      with_codebase_summary
    end
  end

  # Factory for goal decomposition tree node
  factory :goal_tree_node, class: "Hash" do
    skip_create

    id { SecureRandom.uuid }
    text { "Sample goal" }
    parent_id { nil }
    depth { 0 }
    is_leaf { false }
    children { [] }
    priority { 1 }
    rationale { "This is important because..." }

    initialize_with do
      {
        id: id,
        text: text,
        parent_id: parent_id,
        depth: depth,
        is_leaf: is_leaf,
        children: children,
        priority: priority,
        rationale: rationale
      }
    end

    trait :leaf do
      is_leaf { true }
      children { [] }
    end

    trait :with_children do
      is_leaf { false }
      children do
        [
          build(:goal_tree_node, :leaf, text: "Child 1", depth: depth + 1),
          build(:goal_tree_node, :leaf, text: "Child 2", depth: depth + 1)
        ]
      end
    end
  end
end

