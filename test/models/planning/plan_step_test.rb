# frozen_string_literal: true

require "test_helper"

module Planning
  class PlanStepTest < ActiveSupport::TestCase
    speed_profile :fast
    test "initialization with required parameters" do
      step = PlanStep.new(
        title: "Create User Model",
        intent: "Define the core user entity with authentication",
        details: ["Add email and password fields", "Include validation"],
        tests: ["Test user creation", "Test validations"]
      )

      assert_not_nil step.id
      assert_equal "Create User Model", step.title
      assert_equal "Define the core user entity with authentication", step.intent
      assert_equal ["Add email and password fields", "Include validation"], step.details
      assert_equal ["Test user creation", "Test validations"], step.tests
      assert_equal :pending, step.status
      assert_nil step.order_index
    end

    speed_profile :fast
    test "initialization with optional parameters" do
      step = PlanStep.new(
        title: "Create User Model",
        intent: "Define the core user entity",
        details: ["Add fields"],
        tests: ["Test creation"],
        estimated_duration: "30 minutes",
        dependencies: ["step-1", "step-2"],
        file_changes: ["app/models/user.rb", "test/models/user_test.rb"],
        order_index: 1
      )

      assert_equal "30 minutes", step.estimated_duration
      assert_equal ["step-1", "step-2"], step.dependencies
      assert_equal ["app/models/user.rb", "test/models/user_test.rb"], step.file_changes
      assert_equal 1, step.order_index
    end

    speed_profile :fast
    test "validates title must be a String" do
      error = assert_raises(ArgumentError) do
        PlanStep.new(
          title: 123,
          intent: "Test intent",
          details: [],
          tests: []
        )
      end
      assert_match(/title must be a non-empty String/, error.message)
    end

    speed_profile :fast
    test "validates title cannot be empty" do
      error = assert_raises(ArgumentError) do
        PlanStep.new(
          title: "  ",
          intent: "Test intent",
          details: [],
          tests: []
        )
      end
      assert_match(/title must be a non-empty String/, error.message)
    end

    speed_profile :fast
    test "validates intent must be a String" do
      error = assert_raises(ArgumentError) do
        PlanStep.new(
          title: "Test",
          intent: 123,
          details: [],
          tests: []
        )
      end
      assert_match(/intent must be a non-empty String/, error.message)
    end

    speed_profile :fast
    test "validates intent cannot be empty" do
      error = assert_raises(ArgumentError) do
        PlanStep.new(
          title: "Test",
          intent: "  ",
          details: [],
          tests: []
        )
      end
      assert_match(/intent must be a non-empty String/, error.message)
    end

    speed_profile :fast
    test "validates details must be an Array" do
      error = assert_raises(ArgumentError) do
        PlanStep.new(
          title: "Test",
          intent: "Test intent",
          details: "not an array",
          tests: []
        )
      end
      assert_match(/details must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates tests must be an Array" do
      error = assert_raises(ArgumentError) do
        PlanStep.new(
          title: "Test",
          intent: "Test intent",
          details: [],
          tests: "not an array"
        )
      end
      assert_match(/tests must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates all details must be Strings" do
      error = assert_raises(ArgumentError) do
        PlanStep.new(
          title: "Test",
          intent: "Test intent",
          details: ["valid", 123],
          tests: []
        )
      end
      assert_match(/all details must be Strings/, error.message)
    end

    speed_profile :fast
    test "validates all tests must be Strings" do
      error = assert_raises(ArgumentError) do
        PlanStep.new(
          title: "Test",
          intent: "Test intent",
          details: [],
          tests: ["valid", 123]
        )
      end
      assert_match(/all tests must be Strings/, error.message)
    end

    speed_profile :fast
    test "validates status must be a valid symbol" do
      error = assert_raises(ArgumentError) do
        PlanStep.new(
          title: "Test",
          intent: "Test intent",
          details: [],
          tests: [],
          status: :invalid_status
        )
      end
      assert_match(/Invalid status: invalid_status/, error.message)
    end

    speed_profile :fast
    test "validates dependencies must be Array when provided" do
      error = assert_raises(ArgumentError) do
        PlanStep.new(
          title: "Test",
          intent: "Test intent",
          details: [],
          tests: [],
          dependencies: "not-an-array"
        )
      end
      assert_match(/dependencies must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates file_changes must be Array when provided" do
      error = assert_raises(ArgumentError) do
        PlanStep.new(
          title: "Test",
          intent: "Test intent",
          details: [],
          tests: [],
          file_changes: "not-an-array"
        )
      end
      assert_match(/file_changes must be an Array/, error.message)
    end

    speed_profile :fast
    test "pending? returns true for pending status" do
      step = PlanStep.new(
        title: "Test",
        intent: "Test intent",
        details: ["detail"],
        tests: ["test"]
      )

      assert step.pending?
      refute step.in_progress?
      refute step.complete?
      refute step.skipped?
    end

    speed_profile :fast
    test "in_progress? returns true for in_progress status" do
      step = PlanStep.new(
        title: "Test",
        intent: "Test intent",
        details: ["detail"],
        tests: ["test"],
        status: :in_progress
      )

      refute step.pending?
      assert step.in_progress?
      refute step.complete?
      refute step.skipped?
    end

    speed_profile :fast
    test "complete? returns true for complete status" do
      step = PlanStep.new(
        title: "Test",
        intent: "Test intent",
        details: ["detail"],
        tests: ["test"],
        status: :complete
      )

      refute step.pending?
      refute step.in_progress?
      assert step.complete?
      refute step.skipped?
    end

    speed_profile :fast
    test "skipped? returns true for skipped status" do
      step = PlanStep.new(
        title: "Test",
        intent: "Test intent",
        details: ["detail"],
        tests: ["test"],
        status: :skipped
      )

      refute step.pending?
      refute step.in_progress?
      refute step.complete?
      assert step.skipped?
    end

    speed_profile :fast
    test "mark_complete updates status to complete" do
      step = PlanStep.new(
        title: "Test",
        intent: "Test intent",
        details: ["detail"],
        tests: ["test"]
      )

      refute step.complete?
      step.mark_complete
      assert step.complete?
      assert_equal :complete, step.status
    end

    speed_profile :fast
    test "mark_skipped updates status to skipped" do
      step = PlanStep.new(
        title: "Test",
        intent: "Test intent",
        details: ["detail"],
        tests: ["test"]
      )

      refute step.skipped?
      step.mark_skipped
      assert step.skipped?
      assert_equal :skipped, step.status
    end

    speed_profile :fast
    test "mark_in_progress updates status to in_progress" do
      step = PlanStep.new(
        title: "Test",
        intent: "Test intent",
        details: ["detail"],
        tests: ["test"]
      )

      refute step.in_progress?
      step.mark_in_progress
      assert step.in_progress?
      assert_equal :in_progress, step.status
    end

    speed_profile :fast
    test "to_h produces correct hash structure" do
      step = PlanStep.new(
        title: "Create User Model",
        intent: "Define the core user entity",
        details: ["Add email field"],
        tests: ["Test user creation"],
        estimated_duration: "30 minutes",
        dependencies: ["step-1"],
        file_changes: ["app/models/user.rb"],
        order_index: 1
      )

      hash = step.to_h

      assert_not_nil hash[:id]
      assert_equal "Create User Model", hash[:title]
      assert_equal "Define the core user entity", hash[:intent]
      assert_equal ["Add email field"], hash[:details]
      assert_equal ["Test user creation"], hash[:tests]
      assert_equal :pending, hash[:status]
      assert_equal "30 minutes", hash[:estimated_duration]
      assert_equal ["step-1"], hash[:dependencies]
      assert_equal ["app/models/user.rb"], hash[:file_changes]
      assert_equal 1, hash[:order_index]
    end

    speed_profile :fast
    test "to_h includes nil optional fields" do
      step = PlanStep.new(
        title: "Test",
        intent: "Test intent",
        details: [],
        tests: []
      )

      hash = step.to_h

      assert_nil hash[:estimated_duration]
      assert_nil hash[:dependencies]
      assert_nil hash[:file_changes]
      assert_nil hash[:order_index]
    end

    speed_profile :fast
    test "from_h reconstructs object correctly" do
      original = PlanStep.new(
        title: "Create User Model",
        intent: "Define the core user entity",
        details: ["Add email field"],
        tests: ["Test user creation"],
        estimated_duration: "30 minutes",
        order_index: 1
      )

      hash = original.to_h
      reconstructed = PlanStep.from_h(hash)

      assert_equal original.id, reconstructed.id
      assert_equal original.title, reconstructed.title
      assert_equal original.intent, reconstructed.intent
      assert_equal original.details, reconstructed.details
      assert_equal original.tests, reconstructed.tests
      assert_equal original.status, reconstructed.status
      assert_equal original.estimated_duration, reconstructed.estimated_duration
      assert_equal original.order_index, reconstructed.order_index
    end

    speed_profile :fast
    test "from_h reconstructs with string keys" do
      hash = {
        "id" => "test-id-123",
        "title" => "Create User Model",
        "intent" => "Define user entity",
        "details" => ["Add email field"],
        "tests" => ["Test user creation"],
        "status" => "complete",
        "order_index" => 2
      }

      reconstructed = PlanStep.from_h(hash)

      assert_equal "test-id-123", reconstructed.id
      assert_equal "Create User Model", reconstructed.title
      assert_equal "Define user entity", reconstructed.intent
      assert_equal ["Add email field"], reconstructed.details
      assert_equal ["Test user creation"], reconstructed.tests
      assert_equal :complete, reconstructed.status
      assert_equal 2, reconstructed.order_index
    end

    speed_profile :fast
    test "from_h validates input must be Hash" do
      error = assert_raises(ArgumentError) do
        PlanStep.from_h("not a hash")
      end
      assert_match(/hash must be a Hash/, error.message)
    end

    speed_profile :fast
    test "serialization round-trip preserves all data" do
      original = PlanStep.new(
        title: "Implement authentication",
        intent: "Add secure user login",
        details: ["Use bcrypt", "Add session management"],
        tests: ["Test login", "Test logout", "Test security"],
        estimated_duration: "2 hours",
        dependencies: ["step-1", "step-2"],
        file_changes: ["app/controllers/sessions_controller.rb"],
        order_index: 3
      )

      original.mark_in_progress

      hash = original.to_h
      reconstructed = PlanStep.from_h(hash)

      assert_equal original.id, reconstructed.id
      assert_equal original.title, reconstructed.title
      assert_equal original.intent, reconstructed.intent
      assert_equal original.details, reconstructed.details
      assert_equal original.tests, reconstructed.tests
      assert_equal original.status, reconstructed.status
      assert_equal original.estimated_duration, reconstructed.estimated_duration
      assert_equal original.dependencies, reconstructed.dependencies
      assert_equal original.file_changes, reconstructed.file_changes
      assert_equal original.order_index, reconstructed.order_index
    end

    speed_profile :fast
    test "id is auto-generated if not provided" do
      step1 = PlanStep.new(
        title: "Test 1",
        intent: "Test intent",
        details: ["detail"],
        tests: ["test"]
      )

      step2 = PlanStep.new(
        title: "Test 2",
        intent: "Test intent",
        details: ["detail"],
        tests: ["test"]
      )

      assert_not_nil step1.id
      assert_not_nil step2.id
      refute_equal step1.id, step2.id
    end

    speed_profile :fast
    test "id can be provided during initialization" do
      custom_id = "custom-step-id"
      step = PlanStep.new(
        id: custom_id,
        title: "Test",
        intent: "Test intent",
        details: ["detail"],
        tests: ["test"]
      )

      assert_equal custom_id, step.id
    end
  end
end








