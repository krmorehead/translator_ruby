# frozen_string_literal: true

require "test_helper"

module Planning
  class MilestoneTest < ActiveSupport::TestCase
    speed_profile :fast
    test "initialization with number, title, and description" do
      milestone = Milestone.new(
        number: 1,
        title: "User Authentication",
        description: "Implement secure user login"
      )

      assert_equal 1, milestone.number
      assert_equal "User Authentication", milestone.title
      assert_equal "Implement secure user login", milestone.description
      assert_empty milestone.steps
    end

    speed_profile :fast
    test "validates number must be an Integer" do
      error = assert_raises(ArgumentError) do
        Milestone.new(
          number: "1",
          title: "Test",
          description: "Test description"
        )
      end
      assert_match(/number must be an Integer/, error.message)
    end

    speed_profile :fast
    test "validates number must be positive" do
      error = assert_raises(ArgumentError) do
        Milestone.new(
          number: 0,
          title: "Test",
          description: "Test description"
        )
      end
      assert_match(/number must be positive/, error.message)
    end

    speed_profile :fast
    test "validates title must be a String" do
      error = assert_raises(ArgumentError) do
        Milestone.new(
          number: 1,
          title: 123,
          description: "Test description"
        )
      end
      assert_match(/title must be a String/, error.message)
    end

    speed_profile :fast
    test "validates title cannot be empty" do
      error = assert_raises(ArgumentError) do
        Milestone.new(
          number: 1,
          title: "  ",
          description: "Test description"
        )
      end
      assert_match(/title cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates description must be a String" do
      error = assert_raises(ArgumentError) do
        Milestone.new(
          number: 1,
          title: "Test",
          description: 123
        )
      end
      assert_match(/description must be a String/, error.message)
    end

    speed_profile :fast
    test "validates description cannot be empty" do
      error = assert_raises(ArgumentError) do
        Milestone.new(
          number: 1,
          title: "Test",
          description: "  "
        )
      end
      assert_match(/description cannot be empty/, error.message)
    end

    speed_profile :fast
    test "add_step accepts Planning::Step objects" do
      milestone = Milestone.new(
        number: 1,
        title: "Test",
        description: "Test description"
      )

      step = Step.new(
        milestone_number: 1, step_number: 1,
        title: "Create Model",
        intent: "Define entity",
        details: ["Add fields"],
        tests: ["Test creation"]
      )

      result = milestone.add_step(step)

      assert_equal step, result
      assert_equal 1, milestone.steps.size
      assert_equal step, milestone.steps.first
    end

    speed_profile :fast
    test "add_step rejects invalid types" do
      milestone = Milestone.new(
        number: 1,
        title: "Test",
        description: "Test description"
      )

      error = assert_raises(TypeError) do
        milestone.add_step("not a step")
      end
      assert_match(/step must be a Planning::Step/, error.message)
    end

    speed_profile :fast
    test "add_step validates step number matches milestone" do
      milestone = Milestone.new(
        number: 1,
        title: "Test",
        description: "Test description"
      )

      step = Step.new(
        milestone_number: 2, step_number: 1,  # Wrong milestone number
        title: "Create Model",
        intent: "Define entity",
        details: ["Add fields"],
        tests: ["Test creation"]
      )

      error = assert_raises(ArgumentError) do
        milestone.add_step(step)
      end
      assert_match(/step number 2.1 does not match milestone 1/, error.message)
    end

    speed_profile :fast
    test "steps_complete? returns true when all steps complete" do
      milestone = Milestone.new(
        number: 1,
        title: "Test",
        description: "Test description"
      )

      step1 = Step.new(
        milestone_number: 1, step_number: 1,
        title: "Step 1",
        intent: "First step",
        details: ["Detail 1"],
        tests: ["Test 1"]
      )

      step2 = Step.new(
        milestone_number: 1, step_number: 2,
        title: "Step 2",
        intent: "Second step",
        details: ["Detail 2"],
        tests: ["Test 2"]
      )

      milestone.add_step(step1)
      milestone.add_step(step2)

      assert milestone.steps_complete?
    end

    speed_profile :fast
    test "steps_complete? returns false when any step incomplete" do
      milestone = Milestone.new(
        number: 1,
        title: "Test",
        description: "Test description"
      )

      complete_step = Step.new(
        milestone_number: 1, step_number: 1,
        title: "Step 1",
        intent: "First step",
        details: ["Detail 1"],
        tests: ["Test 1"]
      )

      incomplete_step = Step.new(
        milestone_number: 1, step_number: 2,
        title: "Step 2",
        intent: "Second step",
        details: [],  # No details
        tests: ["Test 2"]
      )

      milestone.add_step(complete_step)
      milestone.add_step(incomplete_step)

      refute milestone.steps_complete?
    end

    speed_profile :fast
    test "steps_complete? returns false when no steps" do
      milestone = Milestone.new(
        number: 1,
        title: "Test",
        description: "Test description"
      )

      refute milestone.steps_complete?
    end

    speed_profile :fast
    test "step_count returns correct count" do
      milestone = Milestone.new(
        number: 1,
        title: "Test",
        description: "Test description"
      )

      assert_equal 0, milestone.step_count

      milestone.add_step(Step.new(
        milestone_number: 1, step_number: 1,
        title: "Step 1",
        intent: "First step",
        details: ["Detail"],
        tests: ["Test"]
      ))

      assert_equal 1, milestone.step_count

      milestone.add_step(Step.new(
        milestone_number: 1, step_number: 2,
        title: "Step 2",
        intent: "Second step",
        details: ["Detail"],
        tests: ["Test"]
      ))

      assert_equal 2, milestone.step_count
    end

    speed_profile :fast
    test "to_h produces correct hash structure" do
      milestone = Milestone.new(
        number: 1,
        title: "User Authentication",
        description: "Implement secure login"
      )

      step = Step.new(
        milestone_number: 1, step_number: 1,
        title: "Create Model",
        intent: "Define entity",
        details: ["Add fields"],
        tests: ["Test creation"]
      )

      milestone.add_step(step)

      hash = milestone.to_h

      assert_equal 1, hash[:number]
      assert_equal "User Authentication", hash[:title]
      assert_equal "Implement secure login", hash[:description]
      assert_equal 1, hash[:steps].size
      assert_equal 1, hash[:steps].first[:milestone_number]
      assert_equal 1, hash[:steps].first[:step_number]
    end

    speed_profile :fast
    test "from_h reconstructs object correctly with symbol keys" do
      original = Milestone.new(
        number: 1,
        title: "User Authentication",
        description: "Implement secure login"
      )

      original.add_step(Step.new(
        milestone_number: 1, step_number: 1,
        title: "Create Model",
        intent: "Define entity",
        details: ["Add fields"],
        tests: ["Test creation"]
      ))

      hash = original.to_h
      reconstructed = Milestone.from_h(hash)

      assert_equal original.number, reconstructed.number
      assert_equal original.title, reconstructed.title
      assert_equal original.description, reconstructed.description
      assert_equal original.step_count, reconstructed.step_count
      assert_equal original.steps.first.number, reconstructed.steps.first.number
    end

    speed_profile :fast
    test "from_h reconstructs object correctly with string keys" do
      hash = {
        "number" => 1,
        "title" => "User Authentication",
        "description" => "Implement secure login",
        "steps" => [
          {
            "milestone_number" => 1,
            "step_number" => 1,
            "title" => "Create Model",
            "intent" => "Define entity",
            "details" => ["Add fields"],
            "tests" => ["Test creation"]
          }
        ]
      }

      reconstructed = Milestone.from_h(hash)

      assert_equal 1, reconstructed.number
      assert_equal "User Authentication", reconstructed.title
      assert_equal "Implement secure login", reconstructed.description
      assert_equal 1, reconstructed.step_count
      assert_instance_of Step, reconstructed.steps.first
    end

    speed_profile :fast
    test "from_h validates input must be Hash" do
      error = assert_raises(ArgumentError) do
        Milestone.from_h("not a hash")
      end
      assert_match(/hash must be a Hash/, error.message)
    end

    speed_profile :fast
    test "serialization round-trip preserves step objects" do
      original = Milestone.new(
        number: 2,
        title: "Payment Processing",
        description: "Implement payment integration"
      )

      original.add_step(Step.new(
        milestone_number: 2, step_number: 1,
        title: "Setup Stripe",
        intent: "Configure payment gateway",
        details: ["Add API keys", "Configure webhooks"],
        tests: ["Test connection", "Test webhooks"]
      ))

      original.add_step(Step.new(
        milestone_number: 2, step_number: 2,
        title: "Process Payments",
        intent: "Handle payment flow",
        details: ["Create charge API", "Handle success/failure"],
        tests: ["Test successful payment", "Test failed payment"]
      ))

      hash = original.to_h
      reconstructed = Milestone.from_h(hash)

      assert_equal original.number, reconstructed.number
      assert_equal original.title, reconstructed.title
      assert_equal original.description, reconstructed.description
      assert_equal original.step_count, reconstructed.step_count
      
      reconstructed.steps.each do |step|
        assert_instance_of Step, step
      end
      
      assert_equal original.steps.first.title, reconstructed.steps.first.title
      assert_equal original.steps.last.title, reconstructed.steps.last.title
    end

    speed_profile :fast
    test "deserialization reconstructs step objects not hashes" do
      hash = {
        number: 1,
        title: "Test Milestone",
        description: "Test description",
        steps: [
          {
            milestone_number: 1, step_number: 1,
            title: "Test Step",
            intent: "Test intent",
            details: ["Detail"],
            tests: ["Test"]
          }
        ]
      }

      milestone = Milestone.from_h(hash)

      assert_equal 1, milestone.steps.size
      assert_instance_of Step, milestone.steps.first
      refute milestone.steps.first.is_a?(Hash)
    end
  end
end

