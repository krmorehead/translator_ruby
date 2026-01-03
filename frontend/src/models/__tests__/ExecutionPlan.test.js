import { describe, test, expect } from "vitest";
import { speed_profile } from "../../test/speedProfile";
import { ExecutionPlan } from "../ExecutionPlan";

describe("ExecutionPlan", () => {
  const validParams = {
    goal: "Test goal",
    constraints: ["constraint1", "constraint2"],
    assumptions: ["assumption1"],
    risks: ["risk1"],
    milestones: [
      {
        id: "m1",
        title: "Milestone 1",
        steps: [],
      },
    ],
    outputPaths: {
      plan_path: "/path/to/plan.md",
    },
    analysisSummary: {
      relevant_files: ["file1.rb", "file2.rb"],
    },
    metadata: {
      milestone_count: 1,
      step_count: 0,
    },
  };

  speed_profile("fast")("creates instance with valid parameters", () => {
    const plan = new ExecutionPlan(validParams);
    expect(plan).toBeInstanceOf(ExecutionPlan);
  });

  speed_profile("fast")("throws error for missing goal", () => {
    expect(() => {
      new ExecutionPlan({ ...validParams, goal: "" });
    }).toThrow("goal must be a non-empty string");
  });

  speed_profile("fast")("throws error for invalid constraints", () => {
    expect(() => {
      new ExecutionPlan({ ...validParams, constraints: "not an array" });
    }).toThrow("constraints must be an array");
  });

  speed_profile("fast")("throws error for invalid milestones", () => {
    expect(() => {
      new ExecutionPlan({ ...validParams, milestones: "not an array" });
    }).toThrow("milestones must be an array");
  });

  speed_profile("fast")("getMilestone returns milestone by index", () => {
    const plan = new ExecutionPlan(validParams);
    
    const milestone = plan.getMilestone(0);
    expect(milestone.id).toBe("m1");
    expect(milestone.title).toBe("Milestone 1");
  });

  speed_profile("fast")("getMilestone returns null for invalid index", () => {
    const plan = new ExecutionPlan(validParams);
    expect(plan.getMilestone(99)).toBe(null);
  });

  speed_profile("fast")("getMilestoneCount returns correct count", () => {
    const plan = new ExecutionPlan(validParams);
    expect(plan.getMilestoneCount()).toBe(1);
  });

  speed_profile("fast")("getStepCount returns total steps across milestones", () => {
    const planWithSteps = new ExecutionPlan({
      ...validParams,
      milestones: [
        {
          id: "m1",
          title: "Milestone 1",
          steps: [{ id: "s1" }, { id: "s2" }],
        },
        {
          id: "m2",
          title: "Milestone 2",
          steps: [{ id: "s3" }],
        },
      ],
    });

    expect(planWithSteps.getStepCount()).toBe(3);
  });

  speed_profile("fast")("toJSON serializes to JSON", () => {
    const plan = new ExecutionPlan(validParams);
    const json = plan.toJSON();

    expect(json.goal).toBe("Test goal");
    expect(json.constraints).toEqual(["constraint1", "constraint2"]);
    expect(json.milestones).toHaveLength(1);
  });

  speed_profile("fast")("fromJSON deserializes from JSON", () => {
    const json = {
      execution_plan: {
        goal: "Test goal",
        constraints: [],
        assumptions: [],
        risks: [],
        milestones: [],
      },
      output_paths: {
        plan_path: "/test/plan.md",
      },
      analysis_summary: {
        relevant_files: [],
      },
      metadata: {
        milestone_count: 0,
        step_count: 0,
      },
    };

    const plan = ExecutionPlan.fromJSON(json);
    expect(plan).toBeInstanceOf(ExecutionPlan);
    expect(plan.goal).toBe("Test goal");
  });

  speed_profile("fast")("fromJSON throws error for invalid JSON", () => {
    expect(() => {
      ExecutionPlan.fromJSON(null);
    }).toThrow("JSON must be an object");
  });

  speed_profile("fast")("fromDaedalusResponse creates plan from API response", () => {
    const response = {
      result: {
        execution_plan: {
          goal: "Test goal",
          constraints: [],
          assumptions: [],
          risks: [],
          milestones: [],
        },
        output_paths: {
          plan_path: "/test/plan.md",
        },
        analysis_summary: {
          relevant_files: [],
        },
      },
      metadata: {
        milestone_count: 0,
        step_count: 0,
      },
    };

    const plan = ExecutionPlan.fromDaedalusResponse(response);
    expect(plan).toBeInstanceOf(ExecutionPlan);
    expect(plan.goal).toBe("Test goal");
  });

  speed_profile("fast")("fromDaedalusResponse throws error for invalid response", () => {
    expect(() => {
      ExecutionPlan.fromDaedalusResponse({ invalid: true });
    }).toThrow("Invalid Daedalus response");
  });

  speed_profile("fast")("is immutable", () => {
    const plan = new ExecutionPlan(validParams);

    expect(() => {
      plan.goal = "new goal";
    }).toThrow();

    expect(() => {
      plan.milestones.push({ id: "new" });
    }).toThrow();
  });

  speed_profile("fast")("getter properties are read-only", () => {
    const plan = new ExecutionPlan(validParams);

    expect(plan.goal).toBe("Test goal");
    expect(plan.constraints).toEqual(["constraint1", "constraint2"]);
    expect(plan.assumptions).toEqual(["assumption1"]);
    expect(plan.risks).toEqual(["risk1"]);
    expect(plan.milestones).toHaveLength(1);
    expect(plan.outputPaths.plan_path).toBe("/path/to/plan.md");
    expect(plan.analysisSummary.relevant_files).toEqual(["file1.rb", "file2.rb"]);
    expect(plan.metadata.milestone_count).toBe(1);
  });
});

