# File References: Plan Agent Worker

## Overview

This project creates a PlanAgentWorker that analyzes user requests and generates structured, multi-step execution plans - inspired by Cline's "Plan Mode" but adapted to our OOP architecture.

## Existing Files

| File Path | Description | Relevance |
|-----------|-------------|-----------|
| `app/workers/base_worker.rb` | Abstract base class for workers | Parent class for PlanAgentWorker |
| `app/workers/project_planner_worker.rb` | Project planning worker | Reference for planning workflow patterns |
| `app/workers/codebase_researcher.rb` | Codebase research worker | Reference for research integration |
| `app/services/base_workflow.rb` | Base workflow class | Parent for planning workflows |
| `app/services/workflow_orchestrator.rb` | Workflow execution coordinator | Used for workflow validation |
| `app/services/generic_llm_client.rb` | LLM client abstraction | Used for LLM calls |
| `app/models/workflow_memory_store.rb` | Workflow memory management | Memory store for planning |
| `app/models/contexts/base_context.rb` | Base context class | Reference for context patterns |
| `app/tools/base_tool.rb` | Base tool class | Used for tool schema generation |
| `app/tools/read_file_tool.rb` | File reading tool | Used in analysis phase |
| `app/tools/file_tree_tool.rb` | File tree listing | Used in codebase exploration |
| `app/tools/grep_tool.rb` | Code search tool | Used in analysis phase |
| `app/prompts/base_prompt.rb` | Base prompt class | Parent for planning prompts |
| `docs/references/oop-patterns.md` | OOP patterns guide | Design guidance |
| `test/workers/project_planner_worker_test.rb` | Project planner tests | Reference for worker test patterns |

## Planned Files

| File Path | Description | Created In |
|-----------|-------------|------------|
| `app/workers/plan_agent_worker.rb` | Main plan agent worker class | Step 1.1 |
| `app/workflows/plan_generation_workflow.rb` | Workflow for generating execution plans | Step 1.2 |
| `app/workflows/codebase_analysis_workflow.rb` | Workflow for analyzing relevant code | Step 1.3 |
| `app/models/planning/execution_plan.rb` | Plan result object | Step 2.1 |
| `app/models/planning/plan_step.rb` | Individual plan step | Step 2.2 |
| `app/models/planning/plan_milestone.rb` | Plan milestone grouping | Step 2.3 |
| `app/prompts/planning/plan_generation_prompt.rb` | Prompt for generating plans | Step 3.1 |
| `app/prompts/planning/codebase_analysis_prompt.rb` | Prompt for analyzing code | Step 3.2 |
| `app/prompts/planning/step_refinement_prompt.rb` | Prompt for refining steps | Step 3.3 |
| `app/services/plan_output_service.rb` | Service for writing plan files | Step 4.1 |
| `test/workers/plan_agent_worker_test.rb` | Worker tests | Step 1.1 |
| `test/workflows/plan_generation_workflow_test.rb` | Plan generation workflow tests | Step 1.2 |
| `test/workflows/codebase_analysis_workflow_test.rb` | Analysis workflow tests | Step 1.3 |
| `test/models/planning/execution_plan_test.rb` | Execution plan tests | Step 2.1 |
| `test/models/planning/plan_step_test.rb` | Plan step tests | Step 2.2 |
| `test/models/planning/plan_milestone_test.rb` | Milestone tests | Step 2.3 |
| `test/prompts/planning/plan_generation_prompt_test.rb` | Plan generation prompt tests | Step 3.1 |
| `test/services/plan_output_service_test.rb` | Output service tests | Step 4.1 |

## Document Tree

### Before

```
app/
├── workers/
│   ├── base_worker.rb
│   ├── project_planner_worker.rb
│   ├── codebase_researcher.rb
│   ├── dnd_agent_worker.rb
│   └── agent_worker.rb
├── workflows/
│   ├── research_workflow.rb
│   ├── goal_decomposition_workflow.rb
│   └── project_planning_workflow.rb
├── models/
│   ├── planning/
│   │   ├── result.rb
│   │   ├── milestone.rb
│   │   └── step.rb
│   └── workflow_memory_store.rb
├── prompts/
│   ├── base_prompt.rb
│   └── planning/
│       ├── milestone_generation_prompt.rb
│       ├── step_generation_prompt.rb
│       └── file_analysis_prompt.rb
├── services/
│   ├── base_workflow.rb
│   ├── workflow_orchestrator.rb
│   ├── generic_llm_client.rb
│   └── project_plan_output_service.rb
└── tools/
    ├── base_tool.rb
    ├── read_file_tool.rb
    ├── grep_tool.rb
    └── file_tree_tool.rb

test/
├── workers/
│   ├── project_planner_worker_test.rb
│   └── codebase_researcher_test.rb
├── models/
│   └── planning/
│       ├── result_test.rb
│       ├── milestone_test.rb
│       └── step_test.rb
└── services/
    └── project_plan_output_service_test.rb
```

### Added

```
app/
├── workers/
│   └── plan_agent_worker.rb
├── workflows/
│   ├── plan_generation_workflow.rb
│   └── codebase_analysis_workflow.rb
├── models/
│   └── planning/
│       ├── execution_plan.rb
│       ├── plan_step.rb
│       └── plan_milestone.rb
├── prompts/
│   └── planning/
│       ├── plan_generation_prompt.rb
│       ├── codebase_analysis_prompt.rb
│       └── step_refinement_prompt.rb
└── services/
    └── plan_output_service.rb

test/
├── workers/
│   └── plan_agent_worker_test.rb
├── workflows/
│   ├── plan_generation_workflow_test.rb
│   └── codebase_analysis_workflow_test.rb
├── models/
│   └── planning/
│       ├── execution_plan_test.rb
│       ├── plan_step_test.rb
│       └── plan_milestone_test.rb
├── prompts/
│   └── planning/
│       ├── plan_generation_prompt_test.rb
│       └── codebase_analysis_prompt_test.rb
└── services/
    └── plan_output_service_test.rb
```

