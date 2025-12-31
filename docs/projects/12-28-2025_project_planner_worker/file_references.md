# File References: Project Planner Worker

## Existing Files

| File Path | Description | Relevance |
|-----------|-------------|-----------|
| `app/workers/base_worker.rb` | Abstract base class for workers with state machine | Base class for new worker |
| `app/workers/codebase_researcher.rb` | Research worker that analyzes codebases | Used by ProjectPlannerWorker |
| `app/services/base_workflow.rb` | Abstract base class for workflows | Pattern for new workflow |
| `app/workflows/research_workflow.rb` | Main research orchestration workflow | Pattern reference |
| `app/workflows/goal_decomposition_workflow.rb` | Breaks goals into sub-questions | Pattern reference |
| `app/prompts/base_prompt.rb` | Abstract base for LLM prompts | Base class for new prompts |
| `app/prompts/research/topic_decomposition_prompt.rb` | Decomposes topics into sub-questions | Pattern reference |
| `app/prompts/research/synthesis_prompt.rb` | Synthesizes findings | Pattern reference |
| `app/services/research_output_service.rb` | Writes research output to files | Pattern for output service |
| `app/services/file_documentation_writer.rb` | Writes per-file documentation | Pattern reference |
| `app/controllers/dnd_chat_controller.rb` | D&D chat controller | Pattern for new controller |
| `app/controllers/api/v1/research_controller.rb` | Research API controller | Pattern reference |
| `config/routes.rb` | Rails routing configuration | Add new routes |
| `frontend/src/App.jsx` | React application root | Add mode routing |
| `frontend/src/api/dndChatApi.js` | D&D chat API functions | Pattern for new API |
| `frontend/src/store/chatStore.js` | Zustand store for chat state | Pattern for new store |
| `frontend/src/components/ChatPage.jsx` | D&D chat UI component | Pattern for new page |
| `test/fixtures/example_codebase/` | Example codebase for testing | Test fixture |
| `test/workers/codebase_researcher_test.rb` | CodebaseResearcher tests | Test pattern reference |
| `test/support/research_test_factory.rb` | Research test factory helpers | Extend for new tests |

## Created Files (OOP Refactoring)

| File Path | Description | Phase |
|-----------|-------------|-------|
| `app/models/planning/file_reference.rb` | Domain object for file references | Phase 1 |
| `app/models/planning/step.rb` | Domain object for plan steps | Phase 1 |
| `app/models/planning/milestone.rb` | Domain object for plan milestones | Phase 1 |
| `app/models/planning/result.rb` | Planning workflow result object | Phase 1 |
| `app/models/project_planner/result.rb` | Worker result object | Phase 1 |
| `app/services/planning/file_references_formatter.rb` | Formats file_references.md | Phase 2 |
| `app/services/planning/project_plan_formatter.rb` | Formats project_plan.md | Phase 2 |
| `test/models/planning/file_reference_test.rb` | Tests for FileReference | Phase 1 |
| `test/models/planning/step_test.rb` | Tests for Step | Phase 1 |
| `test/models/planning/milestone_test.rb` | Tests for Milestone | Phase 1 |
| `test/models/planning/result_test.rb` | Tests for Planning::Result | Phase 1 |
| `test/models/project_planner/result_test.rb` | Tests for ProjectPlanner::Result | Phase 1 |
| `test/services/planning/file_references_formatter_test.rb` | Tests for FileReferencesFormatter | Phase 2 |
| `test/services/planning/project_plan_formatter_test.rb` | Tests for ProjectPlanFormatter | Phase 2 |

## Refactored Files

| File Path | Changes | Phase |
|-----------|---------|-------|
| `app/workflows/project_planning_workflow.rb` | Now uses domain objects and formatters | Phase 3 |
| `app/workers/project_planner_worker.rb` | Uses ResearchWorkflow, returns domain objects | Phase 4 |
| `app/controllers/project_planning_controller.rb` | Handles domain objects | Phase 5 |
| `test/workflows/project_planning_workflow_test.rb` | Updated for domain objects | Phase 6 |
| `test/workers/project_planner_worker_test.rb` | Updated for domain objects | Phase 6 |
| `app/prompts/planning/base_planning_prompt.rb` | Added execute override | Phase 3 |

## Document Tree

### Before

```
project/
├── app/
│   ├── controllers/
│   │   ├── api/
│   │   │   └── v1/
│   │   │       └── research_controller.rb
│   │   └── dnd_chat_controller.rb
│   ├── prompts/
│   │   ├── base_prompt.rb
│   │   └── research/
│   │       ├── topic_decomposition_prompt.rb
│   │       ├── synthesis_prompt.rb
│   │       └── ...
│   ├── services/
│   │   ├── base_workflow.rb
│   │   ├── research_output_service.rb
│   │   └── file_documentation_writer.rb
│   ├── workers/
│   │   ├── base_worker.rb
│   │   └── codebase_researcher.rb
│   └── workflows/
│       ├── goal_decomposition_workflow.rb
│       └── research_workflow.rb
├── config/
│   └── routes.rb
├── frontend/
│   └── src/
│       ├── App.jsx
│       ├── api/
│       │   └── dndChatApi.js
│       ├── components/
│       │   └── ChatPage.jsx
│       └── store/
│           └── chatStore.js
└── test/
    ├── fixtures/
    │   └── example_codebase/
    ├── support/
    │   └── research_test_factory.rb
    ├── workers/
    │   └── codebase_researcher_test.rb
    └── workflows/
        └── research_workflow_test.rb
```

### Added

```
project/
├── app/
│   ├── controllers/
│   │   └── project_planning_controller.rb
│   ├── prompts/
│   │   └── planning/
│   │       ├── base_planning_prompt.rb
│   │       ├── plan_structure_prompt.rb
│   │       ├── file_references_prompt.rb
│   │       └── plan_synthesis_prompt.rb
│   ├── services/
│   │   └── project_plan_output_service.rb
│   ├── workers/
│   │   └── project_planner_worker.rb
│   └── workflows/
│       └── project_planning_workflow.rb
├── frontend/
│   └── src/
│       ├── api/
│       │   └── projectPlanApi.js
│       ├── components/
│       │   ├── ProjectPlanPage.jsx
│       │   └── PlanViewer.jsx
│       └── store/
│           └── projectPlanStore.js
└── test/
    ├── controllers/
    │   └── project_planning_controller_test.rb
    ├── integration/
    │   └── project_planner_integration_test.rb
    ├── prompts/
    │   └── planning/
    │       ├── plan_structure_prompt_test.rb
    │       ├── file_references_prompt_test.rb
    │       └── plan_synthesis_prompt_test.rb
    ├── services/
    │   └── project_plan_output_service_test.rb
    ├── workers/
    │   └── project_planner_worker_test.rb
    └── workflows/
        └── project_planning_workflow_test.rb
```

