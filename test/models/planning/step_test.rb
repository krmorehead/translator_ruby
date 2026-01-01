# frozen_string_literal: true

require "test_helper"

module Planning
  class StepTest < ActiveSupport::TestCase
    speed_profile :fast
    test "initialization with all required fields" do
      step = Step.new(
        milestone_number: 1,
        step_number: 1,
        title: "Create User Model",
        intent: "Define the core user entity",
        details: ["Add email field", "Add password field"],
        tests: ["Test user creation", "Test validations"]
      )

      assert_equal "1.1", step.number
      assert_equal 1, step.milestone_number
      assert_equal 1, step.step_number
      assert_equal "Create User Model", step.title
      assert_equal "Define the core user entity", step.intent
      assert_equal ["Add email field", "Add password field"], step.details
      assert_equal ["Test user creation", "Test validations"], step.tests
      assert_not_nil step.id
    end

    speed_profile :fast
    test "validates milestone_number must be an Integer" do
      error = assert_raises(ArgumentError) do
        Step.new(
          milestone_number: "1",
          step_number: 1,
          title: "Test",
          intent: "Test intent",
          details: [],
          tests: []
        )
      end
      assert_match(/milestone_number must be an Integer/, error.message)
    end

    speed_profile :fast
    test "validates step_number must be an Integer" do
      error = assert_raises(ArgumentError) do
        Step.new(
          milestone_number: 1,
          step_number: "1",
          title: "Test",
          intent: "Test intent",
          details: [],
          tests: []
        )
      end
      assert_match(/step_number must be an Integer/, error.message)
    end

    speed_profile :fast
    test "validates milestone_number must be positive" do
      error = assert_raises(ArgumentError) do
        Step.new(
          milestone_number: 0,
          step_number: 1,
          title: "Test",
          intent: "Test intent",
          details: [],
          tests: []
        )
      end
      assert_match(/milestone_number must be positive/, error.message)
    end

    speed_profile :fast
    test "validates step_number must be positive" do
      error = assert_raises(ArgumentError) do
        Step.new(
          milestone_number: 1,
          step_number: -1,
          title: "Test",
          intent: "Test intent",
          details: [],
          tests: []
        )
      end
      assert_match(/step_number must be positive/, error.message)
    end

    speed_profile :fast
    test "validates title must be a String" do
      error = assert_raises(ArgumentError) do
        Step.new(
          milestone_number: 1,
          step_number: 1,
          title: 123,
          intent: "Test intent",
          details: [],
          tests: []
        )
      end
      assert_match(/title must be a String/, error.message)
    end

    speed_profile :fast
    test "validates title cannot be empty" do
      error = assert_raises(ArgumentError) do
        Step.new(
          milestone_number: 1,
          step_number: 1,
          title: "  ",
          intent: "Test intent",
          details: [],
          tests: []
        )
      end
      assert_match(/title cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates intent must be a String" do
      error = assert_raises(ArgumentError) do
        Step.new(
          milestone_number: 1,
          step_number: 1,
          title: "Test",
          intent: 123,
          details: [],
          tests: []
        )
      end
      assert_match(/intent must be a String/, error.message)
    end

    speed_profile :fast
    test "validates intent cannot be empty" do
      error = assert_raises(ArgumentError) do
        Step.new(
          milestone_number: 1,
          step_number: 1,
          title: "Test",
          intent: "  ",
          details: [],
          tests: []
        )
      end
      assert_match(/intent cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates details must be an Array" do
      error = assert_raises(ArgumentError) do
        Step.new(
          milestone_number: 1,
          step_number: 1,
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
        Step.new(
          milestone_number: 1,
          step_number: 1,
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
        Step.new(
          milestone_number: 1,
          step_number: 1,
          title: "Test",
          intent: "Test intent",
          details: ["valid", 123, "another"],
          tests: []
        )
      end
      assert_match(/all details must be Strings/, error.message)
    end

    speed_profile :fast
    test "validates all tests must be Strings" do
      error = assert_raises(ArgumentError) do
        Step.new(
          milestone_number: 1,
          step_number: 1,
          title: "Test",
          intent: "Test intent",
          details: [],
          tests: ["valid", 123, "another"]
        )
      end
      assert_match(/all tests must be Strings/, error.message)
    end

    speed_profile :fast
    test "accepts valid milestone and step numbers" do
      valid_combinations = [
        [1, 1], [2, 3], [10, 5], [99, 99]
      ]
      
      valid_combinations.each do |milestone, step|
        s = Step.new(
          milestone_number: milestone,
          step_number: step,
          title: "Test",
          intent: "Test intent",
          details: ["detail"],
          tests: ["test"]
        )
        assert_equal "#{milestone}.#{step}", s.number
        assert_equal milestone, s.milestone_number
        assert_equal step, s.step_number
      end
    end

    speed_profile :fast
    test "number property formats correctly" do
      step = Step.new(
        milestone_number: 3,
        step_number: 5,
        title: "Test",
        intent: "Test intent",
        details: ["detail"],
        tests: ["test"]
      )

      assert_equal "3.5", step.number
      assert_equal 3, step.milestone_number
      assert_equal 5, step.step_number
    end

    speed_profile :fast
    test "complete? returns true when all fields present" do
      step = Step.new(
        milestone_number: 1,
        step_number: 1,
        title: "Test",
        intent: "Test intent",
        details: ["detail"],
        tests: ["test"]
      )

      assert step.complete?
    end

    speed_profile :fast
    test "complete? returns false when details empty" do
      step = Step.new(
        milestone_number: 1,
        step_number: 1,
        title: "Test",
        intent: "Test intent",
        details: [],
        tests: ["test"]
      )

      refute step.complete?
    end

    speed_profile :fast
    test "complete? returns false when tests empty" do
      step = Step.new(
        milestone_number: 1,
        step_number: 1,
        title: "Test",
        intent: "Test intent",
        details: ["detail"],
        tests: []
      )

      refute step.complete?
    end

    speed_profile :fast
    test "to_h produces correct hash structure" do
      step = Step.new(
        milestone_number: 1,
        step_number: 1,
        title: "Create User Model",
        intent: "Define the core user entity",
        details: ["Add email field"],
        tests: ["Test user creation"]
      )

      hash = step.to_h

      assert_not_nil hash[:id]
      assert_equal 1, hash[:milestone_number]
      assert_equal 1, hash[:step_number]
      assert_equal "Create User Model", hash[:title]
      assert_equal "Define the core user entity", hash[:intent]
      assert_equal ["Add email field"], hash[:details]
      assert_equal ["Test user creation"], hash[:tests]
      
      # number is NOT in hash - it's a computed property
      refute hash.key?(:number)
    end

    speed_profile :fast
    test "from_h reconstructs object correctly with new format" do
      original = Step.new(
        milestone_number: 1,
        step_number: 1,
        title: "Create User Model",
        intent: "Define the core user entity",
        details: ["Add email field"],
        tests: ["Test user creation"]
      )

      hash = original.to_h
      reconstructed = Step.from_h(hash)

      assert_equal original.id, reconstructed.id
      assert_equal original.number, reconstructed.number
      assert_equal original.milestone_number, reconstructed.milestone_number
      assert_equal original.step_number, reconstructed.step_number
      assert_equal original.title, reconstructed.title
      assert_equal original.intent, reconstructed.intent
      assert_equal original.details, reconstructed.details
      assert_equal original.tests, reconstructed.tests
    end

    speed_profile :fast
    test "from_h reconstructs object correctly with string keys" do
      hash = {
        "id" => "test-id-123",
        "milestone_number" => 1,
        "step_number" => 1,
        "title" => "Create User Model",
        "intent" => "Define user entity",
        "details" => ["Add email field"],
        "tests" => ["Test user creation"]
      }

      reconstructed = Step.from_h(hash)

      assert_equal "test-id-123", reconstructed.id
      assert_equal "1.1", reconstructed.number
      assert_equal 1, reconstructed.milestone_number
      assert_equal 1, reconstructed.step_number
      assert_equal "Create User Model", reconstructed.title
      assert_equal "Define user entity", reconstructed.intent
      assert_equal ["Add email field"], reconstructed.details
      assert_equal ["Test user creation"], reconstructed.tests
    end

    speed_profile :fast
    test "from_h validates input must be Hash" do
      error = assert_raises(ArgumentError) do
        Step.from_h("not a hash")
      end
      assert_match(/hash must be a Hash/, error.message)
    end

    speed_profile :fast
    test "serialization round-trip preserves data" do
      original = Step.new(
        milestone_number: 2,
        step_number: 3,
        title: "Implement authentication",
        intent: "Add secure user login",
        details: ["Use bcrypt", "Add session management"],
        tests: ["Test login", "Test logout", "Test security"]
      )

      hash = original.to_h
      reconstructed = Step.from_h(hash)

      assert_equal original.id, reconstructed.id
      assert_equal original.number, reconstructed.number
      assert_equal original.milestone_number, reconstructed.milestone_number
      assert_equal original.step_number, reconstructed.step_number
      assert_equal original.title, reconstructed.title
      assert_equal original.intent, reconstructed.intent
      assert_equal original.details, reconstructed.details
      assert_equal original.tests, reconstructed.tests
      assert_equal original.complete?, reconstructed.complete?
    end

    speed_profile :fast
    test "id is auto-generated if not provided" do
      step1 = Step.new(
        milestone_number: 1,
        step_number: 1,
        title: "Test",
        intent: "Test intent",
        details: ["detail"],
        tests: ["test"]
      )

      step2 = Step.new(
        milestone_number: 1,
        step_number: 2,
        title: "Test",
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
      step = Step.new(
        id: custom_id,
        milestone_number: 1,
        step_number: 1,
        title: "Test",
        intent: "Test intent",
        details: ["detail"],
        tests: ["test"]
      )

      assert_equal custom_id, step.id
    end
  end
end
