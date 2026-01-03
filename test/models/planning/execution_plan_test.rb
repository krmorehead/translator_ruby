# frozen_string_literal: true

require "test_helper"

module Planning
  class ExecutionPlanTest < ActiveSupport::TestCase
    speed_profile :fast
    test "initialization with required parameters" do
      milestone = PlanMilestone.new(
        title: "Milestone 1",
        description: "First milestone",
        steps: []
      )

      plan = ExecutionPlan.new(
        goal: "Create a PlanAgentWorker",
        milestones: [milestone]
      )

      assert_not_nil plan.created_at
      assert_equal "Create a PlanAgentWorker", plan.goal
      assert_equal 1, plan.milestones.size
      assert_equal({}, plan.metadata)
      assert_nil plan.constraints
      assert_nil plan.assumptions
      assert_nil plan.risks
    end

    speed_profile :fast
    test "initialization with optional parameters" do
      milestone = PlanMilestone.new(
        title: "Milestone 1",
        description: "First milestone",
        steps: []
      )

      metadata = { author: "test", version: "1.0" }
      
      plan = ExecutionPlan.new(
        goal: "Create a PlanAgentWorker",
        milestones: [milestone],
        metadata: metadata,
        constraints: ["Must follow OOP patterns"],
        assumptions: ["Rails environment available"],
        risks: ["May take longer than estimated"]
      )

      assert_equal metadata, plan.metadata
      assert_equal ["Must follow OOP patterns"], plan.constraints
      assert_equal ["Rails environment available"], plan.assumptions
      assert_equal ["May take longer than estimated"], plan.risks
    end

    speed_profile :fast
    test "validates goal must be a non-empty String" do
      error = assert_raises(ArgumentError) do
        ExecutionPlan.new(
          goal: "  ",
          milestones: []
        )
      end
      assert_match(/goal must be a non-empty String/, error.message)
    end

    speed_profile :fast
    test "validates goal must be a String type" do
      error = assert_raises(ArgumentError) do
        ExecutionPlan.new(
          goal: 123,
          milestones: []
        )
      end
      assert_match(/goal must be a non-empty String/, error.message)
    end

    speed_profile :fast
    test "validates milestones must be an Array" do
      error = assert_raises(ArgumentError) do
        ExecutionPlan.new(
          goal: "Test goal",
          milestones: "not an array"
        )
      end
      assert_match(/milestones must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates all milestones must be PlanMilestone instances" do
      error = assert_raises(ArgumentError) do
        ExecutionPlan.new(
          goal: "Test goal",
          milestones: ["not a milestone"]
        )
      end
      assert_match(/all milestones must be PlanMilestone instances/, error.message)
    end

    speed_profile :fast
    test "validates metadata must be a Hash" do
      error = assert_raises(ArgumentError) do
        ExecutionPlan.new(
          goal: "Test goal",
          milestones: [],
          metadata: "not a hash"
        )
      end
      assert_match(/metadata must be a Hash/, error.message)
    end

    speed_profile :fast
    test "validates constraints must be Array when provided" do
      error = assert_raises(ArgumentError) do
        ExecutionPlan.new(
          goal: "Test goal",
          milestones: [],
          constraints: "not an array"
        )
      end
      assert_match(/constraints must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates assumptions must be Array when provided" do
      error = assert_raises(ArgumentError) do
        ExecutionPlan.new(
          goal: "Test goal",
          milestones: [],
          assumptions: "not an array"
        )
      end
      assert_match(/assumptions must be an Array/, error.message)
    end

    speed_profile :fast
    test "validates risks must be Array when provided" do
      error = assert_raises(ArgumentError) do
        ExecutionPlan.new(
          goal: "Test goal",
          milestones: [],
          risks: "not an array"
        )
      end
      assert_match(/risks must be an Array/, error.message)
    end

    speed_profile :fast
    test "add_milestone adds a milestone to the plan" do
      plan = ExecutionPlan.new(
        goal: "Test goal",
        milestones: []
      )

      assert_equal 0, plan.milestone_count

      milestone = PlanMilestone.new(
        title: "Milestone 1",
        description: "First milestone",
        steps: []
      )

      plan.add_milestone(milestone)

      assert_equal 1, plan.milestone_count
      assert_equal milestone, plan.milestones.first
    end

    speed_profile :fast
    test "add_milestone validates milestone is a PlanMilestone" do
      plan = ExecutionPlan.new(
        goal: "Test goal",
        milestones: []
      )

      error = assert_raises(ArgumentError) do
        plan.add_milestone("not a milestone")
      end
      assert_match(/milestone must be a PlanMilestone/, error.message)
    end

    speed_profile :fast
    test "milestone_count returns correct count" do
      milestone1 = PlanMilestone.new(title: "M1", description: "Desc 1", steps: [])
      milestone2 = PlanMilestone.new(title: "M2", description: "Desc 2", steps: [])

      plan = ExecutionPlan.new(
        goal: "Test goal",
        milestones: [milestone1, milestone2]
      )

      assert_equal 2, plan.milestone_count
    end

    speed_profile :fast
    test "step_count returns total steps across all milestones" do
      step1 = PlanStep.new(title: "S1", intent: "I1", details: ["d"], tests: ["t"])
      step2 = PlanStep.new(title: "S2", intent: "I2", details: ["d"], tests: ["t"])
      step3 = PlanStep.new(title: "S3", intent: "I3", details: ["d"], tests: ["t"])

      milestone1 = PlanMilestone.new(title: "M1", description: "Desc 1", steps: [step1, step2])
      milestone2 = PlanMilestone.new(title: "M2", description: "Desc 2", steps: [step3])

      plan = ExecutionPlan.new(
        goal: "Test goal",
        milestones: [milestone1, milestone2]
      )

      assert_equal 3, plan.step_count
    end

    speed_profile :fast
    test "step_count returns 0 when no milestones" do
      plan = ExecutionPlan.new(
        goal: "Test goal",
        milestones: []
      )

      assert_equal 0, plan.step_count
    end

    speed_profile :fast
    test "to_h produces correct hash structure" do
      step = PlanStep.new(title: "S1", intent: "I1", details: ["d"], tests: ["t"])
      milestone = PlanMilestone.new(title: "M1", description: "Desc 1", steps: [step])

      plan = ExecutionPlan.new(
        goal: "Create a PlanAgentWorker",
        milestones: [milestone],
        metadata: { author: "test" },
        constraints: ["Follow OOP"],
        assumptions: ["Rails available"],
        risks: ["May take time"]
      )

      hash = plan.to_h

      assert_not_nil hash[:created_at]
      assert_equal "Create a PlanAgentWorker", hash[:goal]
      assert_equal 1, hash[:milestones].size
      assert_instance_of Hash, hash[:milestones].first
      assert_equal "M1", hash[:milestones].first[:title]
      assert_equal({ author: "test" }, hash[:metadata])
      assert_equal ["Follow OOP"], hash[:constraints]
      assert_equal ["Rails available"], hash[:assumptions]
      assert_equal ["May take time"], hash[:risks]
    end

    speed_profile :fast
    test "to_h recursively serializes milestones and steps" do
      step1 = PlanStep.new(title: "S1", intent: "I1", details: ["d1"], tests: ["t1"])
      step2 = PlanStep.new(title: "S2", intent: "I2", details: ["d2"], tests: ["t2"])
      milestone1 = PlanMilestone.new(title: "M1", description: "D1", steps: [step1])
      milestone2 = PlanMilestone.new(title: "M2", description: "D2", steps: [step2])

      plan = ExecutionPlan.new(
        goal: "Test goal",
        milestones: [milestone1, milestone2]
      )

      hash = plan.to_h

      assert_equal 2, hash[:milestones].size
      assert_equal milestone1.id, hash[:milestones][0][:id]
      assert_equal milestone2.id, hash[:milestones][1][:id]
      assert_equal 1, hash[:milestones][0][:steps].size
      assert_equal step1.id, hash[:milestones][0][:steps][0][:id]
    end

    speed_profile :fast
    test "from_h reconstructs object correctly" do
      step = PlanStep.new(title: "S1", intent: "I1", details: ["d"], tests: ["t"])
      milestone = PlanMilestone.new(title: "M1", description: "Desc 1", steps: [step])

      original = ExecutionPlan.new(
        goal: "Create a PlanAgentWorker",
        milestones: [milestone],
        metadata: { author: "test" },
        constraints: ["Follow OOP"]
      )

      hash = original.to_h
      reconstructed = ExecutionPlan.from_h(hash)

      assert_equal original.goal, reconstructed.goal
      assert_equal original.created_at, reconstructed.created_at
      assert_equal original.metadata, reconstructed.metadata
      assert_equal original.constraints, reconstructed.constraints
      assert_equal original.milestones.size, reconstructed.milestones.size
      assert_equal original.milestones.first.id, reconstructed.milestones.first.id
      assert_equal original.milestones.first.title, reconstructed.milestones.first.title
    end

    speed_profile :fast
    test "from_h reconstructs with string keys" do
      step_hash = {
        "id" => "step-123",
        "title" => "S1",
        "intent" => "I1",
        "details" => ["d"],
        "tests" => ["t"],
        "status" => "pending"
      }

      milestone_hash = {
        "id" => "milestone-123",
        "title" => "M1",
        "description" => "Desc 1",
        "steps" => [step_hash]
      }

      hash = {
        "goal" => "Create a PlanAgentWorker",
        "milestones" => [milestone_hash],
        "created_at" => "2024-01-01T00:00:00Z",
        "metadata" => { "author" => "test" }
      }

      reconstructed = ExecutionPlan.from_h(hash)

      assert_equal "Create a PlanAgentWorker", reconstructed.goal
      assert_equal "2024-01-01T00:00:00Z", reconstructed.created_at
      assert_equal({ "author" => "test" }, reconstructed.metadata)
      assert_equal 1, reconstructed.milestones.size
      assert_equal "milestone-123", reconstructed.milestones.first.id
    end

    speed_profile :fast
    test "from_h validates input must be Hash" do
      error = assert_raises(ArgumentError) do
        ExecutionPlan.from_h("not a hash")
      end
      assert_match(/hash must be a Hash/, error.message)
    end

    speed_profile :fast
    test "serialization round-trip preserves all data" do
      step1 = PlanStep.new(title: "S1", intent: "I1", details: ["d1"], tests: ["t1"])
      step2 = PlanStep.new(title: "S2", intent: "I2", details: ["d2"], tests: ["t2"])
      milestone1 = PlanMilestone.new(title: "M1", description: "D1", steps: [step1])
      milestone2 = PlanMilestone.new(title: "M2", description: "D2", steps: [step2])

      original = ExecutionPlan.new(
        goal: "Create a comprehensive system",
        milestones: [milestone1, milestone2],
        metadata: { author: "test", version: "1.0" },
        constraints: ["Follow OOP", "Use TDD"],
        assumptions: ["Rails available", "Postgres configured"],
        risks: ["May take time", "Complexity"]
      )

      hash = original.to_h
      reconstructed = ExecutionPlan.from_h(hash)

      assert_equal original.goal, reconstructed.goal
      assert_equal original.created_at, reconstructed.created_at
      assert_equal original.metadata, reconstructed.metadata
      assert_equal original.constraints, reconstructed.constraints
      assert_equal original.assumptions, reconstructed.assumptions
      assert_equal original.risks, reconstructed.risks
      assert_equal original.milestone_count, reconstructed.milestone_count
      assert_equal original.step_count, reconstructed.step_count
    end
  end
end








