# frozen_string_literal: true

FactoryBot.define do
  # Factory for Execution::ApprovalRequest
  factory :approval_request, class: "Execution::ApprovalRequest" do
    skip_create

    transient do
      request_id { SecureRandom.uuid }
      exec_id { SecureRandom.uuid }
      approval_type { :step }
      approval_status { :pending }
      step_id { "step-#{SecureRandom.hex(4)}" }
      step_title { "Test Step #{SecureRandom.hex(2)}" }
      actions { [] }
      changes { {} }
      timeout { 300 }
    end

    initialize_with do
      new(
        id: request_id,
        execution_id: exec_id,
        type: approval_type,
        status: approval_status,
        subject_id: step_id,
        subject_title: step_title,
        planned_actions: actions,
        estimated_changes: changes,
        created_at: Time.now.utc.iso8601,
        timeout_seconds: timeout
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

    # Status traits
    trait :pending do
      transient do
        approval_status { :pending }
      end
    end

    trait :approved do
      transient do
        approval_status { :approved }
      end

      after(:build) do |request, evaluator|
        # Return an approved version
        request.approve(resolved_by: "test_user")
      end
    end

    trait :rejected do
      transient do
        approval_status { :rejected }
      end

      after(:build) do |request, evaluator|
        # Return a rejected version
        request.reject(resolved_by: "test_user")
      end
    end

    trait :timeout do
      transient do
        approval_status { :timeout }
      end

      after(:build) do |request, evaluator|
        # Return a timed out version
        request.mark_timeout
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

    # Timing traits
    trait :expired do
      transient do
        timeout { 300 }
      end

      initialize_with do
        new(
          id: request_id,
          execution_id: exec_id,
          type: approval_type,
          status: approval_status,
          subject_id: step_id,
          subject_title: step_title,
          planned_actions: actions,
          estimated_changes: changes,
          created_at: (Time.now.utc - 400).iso8601, # Created 400s ago
          timeout_seconds: timeout # Timeout is 300s, so it's expired
        )
      end
    end

    trait :about_to_expire do
      transient do
        timeout { 300 }
      end

      initialize_with do
        new(
          id: request_id,
          execution_id: exec_id,
          type: approval_type,
          status: approval_status,
          subject_id: step_id,
          subject_title: step_title,
          planned_actions: actions,
          estimated_changes: changes,
          created_at: (Time.now.utc - 280).iso8601, # 20 seconds remaining
          timeout_seconds: timeout
        )
      end
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

