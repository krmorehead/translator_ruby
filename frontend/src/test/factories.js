// Test Data Factories for Frontend Tests
// Pattern matches backend FactoryBot factories

export const buildExecutionPlanResult = (overrides = {}) => {
  const defaults = {
    success: true,
    result: {
      execution_plan: {
        id: "test-plan-id",
        goal: "Test execution goal",
        milestones: [
          {
            id: "milestone-1",
            title: "Setup Phase",
            description: "Initial setup and configuration",
            estimated_duration: "2 days",
            success_criteria: [
              "Environment configured",
              "Dependencies installed"
            ],
            steps: [
              {
                id: "step-1-1",
                milestone_number: 1,
                step_number: 1,
                title: "Install dependencies",
                intent: "Set up project environment",
                details: [
                  "Run npm install",
                  "Configure environment variables"
                ],
                tests: [
                  "Verify all packages installed",
                  "Check environment configuration"
                ]
              }
            ]
          }
        ],
        constraints: ["Must complete within 1 week"],
        assumptions: ["Team has access to required tools"],
        risks: ["Dependency conflicts may arise"],
        created_at: new Date().toISOString()
      },
      output_paths: {
        plan_path: "tmp/test/plans/test_plan.md",
        json_path: "tmp/test/plans/test_plan.json",
        metadata_path: "tmp/test/plans/test_metadata.json"
      },
      analysis_summary: {
        relevant_files: [
          "app/models/user.rb",
          "app/services/auth_service.rb"
        ],
        patterns_found: ["MVC architecture", "Service objects"],
        constraints_identified: ["Rails 7.0 required"]
      }
    },
    metadata: {
      milestone_count: 1,
      step_count: 1,
      total_duration_estimate: "2 days"
    }
  };

  return mergeDeep(defaults, overrides);
};

export const buildProjectPlanResult = (overrides = {}) => {
  const defaults = {
    success: true,
    milestones: [
      {
        order_index: 0,
        title: "Phase 1: Setup",
        description: "Initial project setup",
        success_criteria: "Environment ready"
      }
    ],
    project_plan_path: "tmp/test/docs/project_plan.md",
    file_references_path: "tmp/test/docs/file_references.md",
    research_summary: "Codebase uses Rails patterns",
    existing_files: ["app/models/user.rb"],
    planned_files: ["app/services/new_service.rb"]
  };

  return mergeDeep(defaults, overrides);
};

export const buildSisyphusExecution = (overrides = {}) => {
  const defaults = {
    success: true,
    state: {
      execution_id: "exec-123",
      status: "running",
      current_step: 1,
      total_steps: 5,
      started_at: new Date().toISOString(),
      milestones_completed: 0,
      current_milestone: "Setup Phase"
    }
  };

  return mergeDeep(defaults, overrides);
};

// Deep merge helper
function mergeDeep(target, source) {
  const output = { ...target };
  if (isObject(target) && isObject(source)) {
    Object.keys(source).forEach(key => {
      if (isObject(source[key])) {
        if (!(key in target)) {
          output[key] = source[key];
        } else {
          output[key] = mergeDeep(target[key], source[key]);
        }
      } else {
        output[key] = source[key];
      }
    });
  }
  return output;
}

function isObject(item) {
  return item && typeof item === 'object' && !Array.isArray(item);
}








