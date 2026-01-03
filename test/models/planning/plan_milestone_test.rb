# frozen_string_literal: true

require "test_helper"

module Planning
  class PlanMilestoneTest < ActiveSupport::TestCase
    speed_profile :fast
    test "initialization with required parameters" do
      milestone = PlanMilestone.new(
        title: "Core Infrastructure",
        description: "Build the foundational worker and workflow infrastructure",
        steps: []
      )

      assert_not_nil milestone.id
      assert_equal "Core Infrastructure", milestone.title
      assert_equal "Build the foundational worker and workflow infrastructure", milestone.description
      assert_equal [], milestone.steps
      assert_nil milestone.order_index
      assert_nil milestone.estimated_duration
      assert_nil milestone.success_criteria
    end

    speed_profile :fast
    test "initialization with optional parameters" do
      step = PlanStep.new(
        title: "Create Worker",
        intent: "Build worker class",
        details: ["detail"],
        tests: ["test"]
      )

      milestone = PlanMilestone.new(
        title: "Core Infrastructure",
        description: "Build the foundation",
        steps: [step],
        order_index: 1,
        estimated_duration: "2 hours",
        success_criteria: ["All tests pass", "Worker functional"]
      )

      assert_equal 1, milestone.order_index
      assert_equal "2 hours", milestone.estimated_duration
      assert_equal ["All tests pass", "Worker functional"], milestone.success_criteria
      assert_equal 1, milestone.steps.size
    end

    speed_profile :fast
    test "validates title must be a non-empty String" do
      error = assert_raises(ArgumentError) do
        PlanMilestone.new(
          title: "  ",
          description: "Test description",
          steps: []
        )
      end
      assert_match(/title must be a non-empty String/, error.message)
    end

    speed_profile :fast
    test "validates title must be a String type" do
      error = assert_raises(ArgumentError) do
        PlanMilestone.new(
          title: 123,
          description: "Test description",
          steps: []
        )
      end
      assert_match(/title must be a non-empty String/, error.message)
    end

    speed_profile :fast
    test "validates description must be a String" do
      error = assert_raises(ArgumentError) do
        PlanMilestone.new(
          title: "Test",
          description: 123,
          steps: []
        )
      end
      assert_match(/description must be a String/, error.message)
    end

    speed_profile :fast
    test "validates steps must be an Array" do
      error = assert_raises(ArgumentError) do
        PlanMilestone.new(
          title: "Test",
          description: "Test description",
          steps: "not an array"
        )
      end
      assert_match(/steps must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates all steps must be PlanStep instances" do
      error = assert_raises(ArgumentError) do
        PlanMilestone.new(
          title: "Test",
          description: "Test description",
          steps: ["not a step"]
        )
      end
      assert_match(/all steps must be PlanStep instances/, error.message)
    end

    speed_profile :fast
    test "validates success_criteria must be Array when provided" do
      error = assert_raises(ArgumentError) do
        PlanMilestone.new(
          title: "Test",
          description: "Test description",
          steps: [],
          success_criteria: "not an array"
        )
      end
      assert_match(/success_criteria must be an Array/, error.message)
    end

    speed_profile :fast
    test "add_step adds a step to the milestone" do
      milestone = PlanMilestone.new(
        title: "Test",
        description: "Test description",
        steps: []
      )

      assert_equal 0, milestone.step_count

      step = PlanStep.new(
        title: "Create Worker",
        intent: "Build worker class",
        details: ["detail"],
        tests: ["test"]
      )

      milestone.add_step(step)

      assert_equal 1, milestone.step_count
      assert_equal step, milestone.steps.first
    end

    speed_profile :fast
    test "add_step validates step is a PlanStep" do
      milestone = PlanMilestone.new(
        title: "Test",
        description: "Test description",
        steps: []
      )

      error = assert_raises(ArgumentError) do
        milestone.add_step("not a step")
      end
      assert_match(/step must be a PlanStep/, error.message)
    end

    speed_profile :fast
    test "step_count returns correct count" do
      step1 = PlanStep.new(title: "Step 1", intent: "Intent 1", details: ["d"], tests: ["t"])
      step2 = PlanStep.new(title: "Step 2", intent: "Intent 2", details: ["d"], tests: ["t"])

      milestone = PlanMilestone.new(
        title: "Test",
        description: "Test description",
        steps: [step1, step2]
      )

      assert_equal 2, milestone.step_count
    end

    speed_profile :fast
    test "progress returns 0 when no steps" do
      milestone = PlanMilestone.new(
        title: "Test",
        description: "Test description",
        steps: []
      )

      assert_equal 0, milestone.progress
    end

    speed_profile :fast
    test "progress returns correct percentage" do
      step1 = PlanStep.new(title: "Step 1", intent: "Intent 1", details: ["d"], tests: ["t"])
      step2 = PlanStep.new(title: "Step 2", intent: "Intent 2", details: ["d"], tests: ["t"])
      step3 = PlanStep.new(title: "Step 3", intent: "Intent 3", details: ["d"], tests: ["t"])
      step4 = PlanStep.new(title: "Step 4", intent: "Intent 4", details: ["d"], tests: ["t"])

      milestone = PlanMilestone.new(
        title: "Test",
        description: "Test description",
        steps: [step1, step2, step3, step4]
      )

      assert_equal 0, milestone.progress

      step1.mark_complete
      assert_equal 25, milestone.progress

      step2.mark_complete
      assert_equal 50, milestone.progress

      step3.mark_complete
      assert_equal 75, milestone.progress

      step4.mark_complete
      assert_equal 100, milestone.progress
    end

    speed_profile :fast
    test "completed? returns false when no steps complete" do
      step1 = PlanStep.new(title: "Step 1", intent: "Intent 1", details: ["d"], tests: ["t"])
      step2 = PlanStep.new(title: "Step 2", intent: "Intent 2", details: ["d"], tests: ["t"])

      milestone = PlanMilestone.new(
        title: "Test",
        description: "Test description",
        steps: [step1, step2]
      )

      refute milestone.completed?
    end

    speed_profile :fast
    test "completed? returns false when some steps complete" do
      step1 = PlanStep.new(title: "Step 1", intent: "Intent 1", details: ["d"], tests: ["t"])
      step2 = PlanStep.new(title: "Step 2", intent: "Intent 2", details: ["d"], tests: ["t"])

      milestone = PlanMilestone.new(
        title: "Test",
        description: "Test description",
        steps: [step1, step2]
      )

      step1.mark_complete
      refute milestone.completed?
    end

    speed_profile :fast
    test "completed? returns true when all steps complete" do
      step1 = PlanStep.new(title: "Step 1", intent: "Intent 1", details: ["d"], tests: ["t"])
      step2 = PlanStep.new(title: "Step 2", intent: "Intent 2", details: ["d"], tests: ["t"])

      milestone = PlanMilestone.new(
        title: "Test",
        description: "Test description",
        steps: [step1, step2]
      )

      step1.mark_complete
      step2.mark_complete
      assert milestone.completed?
    end

    speed_profile :fast
    test "completed? returns true when no steps" do
      milestone = PlanMilestone.new(
        title: "Test",
        description: "Test description",
        steps: []
      )

      assert milestone.completed?
    end

    speed_profile :fast
    test "to_h produces correct hash structure" do
      step = PlanStep.new(title: "Step 1", intent: "Intent 1", details: ["detail"], tests: ["test"])

      milestone = PlanMilestone.new(
        title: "Core Infrastructure",
        description: "Build the foundation",
        steps: [step],
        order_index: 1,
        estimated_duration: "2 hours",
        success_criteria: ["All tests pass"]
      )

      hash = milestone.to_h

      assert_not_nil hash[:id]
      assert_equal "Core Infrastructure", hash[:title]
      assert_equal "Build the foundation", hash[:description]
      assert_equal 1, hash[:order_index]
      assert_equal "2 hours", hash[:estimated_duration]
      assert_equal ["All tests pass"], hash[:success_criteria]
      assert_equal 1, hash[:steps].size
      assert_instance_of Hash, hash[:steps].first
      assert_equal "Step 1", hash[:steps].first[:title]
    end

    speed_profile :fast
    test "to_h recursively serializes steps" do
      step1 = PlanStep.new(title: "Step 1", intent: "Intent 1", details: ["d1"], tests: ["t1"])
      step2 = PlanStep.new(title: "Step 2", intent: "Intent 2", details: ["d2"], tests: ["t2"])

      milestone = PlanMilestone.new(
        title: "Test",
        description: "Test description",
        steps: [step1, step2]
      )

      hash = milestone.to_h

      assert_equal 2, hash[:steps].size
      assert_equal step1.id, hash[:steps][0][:id]
      assert_equal step2.id, hash[:steps][1][:id]
      assert_equal ["d1"], hash[:steps][0][:details]
      assert_equal ["d2"], hash[:steps][1][:details]
    end

    speed_profile :fast
    test "from_h reconstructs object correctly" do
      step = PlanStep.new(title: "Step 1", intent: "Intent 1", details: ["detail"], tests: ["test"])

      original = PlanMilestone.new(
        title: "Core Infrastructure",
        description: "Build the foundation",
        steps: [step],
        order_index: 1,
        estimated_duration: "2 hours"
      )

      hash = original.to_h
      reconstructed = PlanMilestone.from_h(hash)

      assert_equal original.id, reconstructed.id
      assert_equal original.title, reconstructed.title
      assert_equal original.description, reconstructed.description
      assert_equal original.order_index, reconstructed.order_index
      assert_equal original.estimated_duration, reconstructed.estimated_duration
      assert_equal original.steps.size, reconstructed.steps.size
      assert_equal original.steps.first.id, reconstructed.steps.first.id
      assert_equal original.steps.first.title, reconstructed.steps.first.title
    end

    speed_profile :fast
    test "from_h reconstructs with string keys" do
      step_hash = {
        "id" => "step-123",
        "title" => "Step 1",
        "intent" => "Intent 1",
        "details" => ["detail"],
        "tests" => ["test"],
        "status" => "pending"
      }

      hash = {
        "id" => "milestone-123",
        "title" => "Core Infrastructure",
        "description" => "Build the foundation",
        "steps" => [step_hash],
        "order_index" => 1
      }

      reconstructed = PlanMilestone.from_h(hash)

      assert_equal "milestone-123", reconstructed.id
      assert_equal "Core Infrastructure", reconstructed.title
      assert_equal "Build the foundation", reconstructed.description
      assert_equal 1, reconstructed.order_index
      assert_equal 1, reconstructed.steps.size
      assert_equal "step-123", reconstructed.steps.first.id
    end

    speed_profile :fast
    test "from_h validates input must be Hash" do
      error = assert_raises(ArgumentError) do
        PlanMilestone.from_h("not a hash")
      end
      assert_match(/hash must be a Hash/, error.message)
    end

    speed_profile :fast
    test "serialization round-trip preserves all data" do
      step1 = PlanStep.new(title: "Step 1", intent: "Intent 1", details: ["d1"], tests: ["t1"])
      step2 = PlanStep.new(title: "Step 2", intent: "Intent 2", details: ["d2"], tests: ["t2"])
      step1.mark_complete

      original = PlanMilestone.new(
        title: "Core Infrastructure",
        description: "Build the foundation",
        steps: [step1, step2],
        order_index: 1,
        estimated_duration: "2 hours",
        success_criteria: ["All tests pass", "Code reviewed"]
      )

      hash = original.to_h
      reconstructed = PlanMilestone.from_h(hash)

      assert_equal original.id, reconstructed.id
      assert_equal original.title, reconstructed.title
      assert_equal original.description, reconstructed.description
      assert_equal original.order_index, reconstructed.order_index
      assert_equal original.estimated_duration, reconstructed.estimated_duration
      assert_equal original.success_criteria, reconstructed.success_criteria
      assert_equal original.step_count, reconstructed.step_count
      assert_equal original.progress, reconstructed.progress
      assert_equal original.completed?, reconstructed.completed?
    end

    speed_profile :fast
    test "id is auto-generated if not provided" do
      milestone1 = PlanMilestone.new(title: "Test 1", description: "Desc 1", steps: [])
      milestone2 = PlanMilestone.new(title: "Test 2", description: "Desc 2", steps: [])

      assert_not_nil milestone1.id
      assert_not_nil milestone2.id
      refute_equal milestone1.id, milestone2.id
    end

    speed_profile :fast
    test "id can be provided during initialization" do
      custom_id = "custom-milestone-id"
      milestone = PlanMilestone.new(
        id: custom_id,
        title: "Test",
        description: "Test description",
        steps: []
      )

      assert_equal custom_id, milestone.id
    end
  end
end


