# frozen_string_literal: true

FactoryBot.define do
  # Factory for Execution::ApprovalRequest
  #
  # Approvals have three statuses only:
  # - :pending - waiting for user action
  # - :approved - user approved
  # - :rejected - user rejected
  #
  # There is NO timeout status. Approvals wait forever for user action.
  #
  # NOTE: new() generates its own ID and timestamps automatically
  # Only from_h() accepts an id parameter (for deserialization)
  factory :approval_request, class: "Execution::ApprovalRequest" do
    skip_create

    transient do
      exec_id { SecureRandom.uuid }
      approval_type { :step }
      step_id { "step-#{SecureRandom.hex(4)}" }
      step_title { "Test Step #{SecureRandom.hex(2)}" }
      actions { [] }
      changes { {} }
    end

    initialize_with do
      # new() generates its own UUID - NEVER pass id
      new(
        execution_id: exec_id,
        type: approval_type,
        subject_id: step_id,
        subject_title: step_title,
        planned_actions: actions,
        estimated_changes: changes
      )
    end

    # Type traits
    trait :step do
      transient do
        approval_type { :step }
        step_title { "Execute Test Step" }
      end
    end

    trait :milestone do
      transient do
        approval_type { :milestone }
        step_id { "milestone-#{SecureRandom.hex(4)}" }
        step_title { "Complete Test Milestone" }
      end
    end

    # Status traits - new() always creates pending, these traits modify after creation
    trait :pending do
      # Default - no modifications needed
    end

    trait :approved do
      after(:build) do |request|
        # approve() returns a new instance with approved status
        request.approve(resolved_by: "test_user")
      end
    end

    trait :rejected do
      after(:build) do |request|
        # reject() returns a new instance with rejected status
        request.reject(resolved_by: "test_user")
      end
    end

    # Content traits
    trait :with_planned_actions do
      transient do
        actions do
          [
            "Create new file: hello.rb",
            "Write Hello World code",
            "Make file executable"
          ]
        end
      end
    end

    trait :with_estimated_changes do
      transient do
        changes do
          {
            files_to_create: 2,
            files_to_modify: 1,
            files_to_delete: 0,
            commands_to_run: 1
          }
        end
      end
    end

    trait :with_full_details do
      with_planned_actions
      with_estimated_changes
    end

    # Convenience combined traits
    trait :step_approval_with_details do
      step
      with_full_details
    end

    trait :milestone_approval_with_details do
      milestone
      with_full_details
    end
  end
end
