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

## Planned Files

| File Path | Description | Created In |
|-----------|-------------|------------|
| `app/workers/project_planner_worker.rb` | Worker that orchestrates project planning | 1.1 |
| `app/workflows/project_planning_workflow.rb` | Workflow for project plan generation | 1.2 |
| `app/prompts/planning/base_planning_prompt.rb` | Base class for planning prompts | 2.1 |
| `app/prompts/planning/plan_structure_prompt.rb` | Generates milestone/step structure | 2.2 |
| `app/prompts/planning/file_references_prompt.rb` | Generates file references document | 2.3 |
| `app/prompts/planning/plan_synthesis_prompt.rb` | Synthesizes research into plan | 2.4 |
| `app/services/project_plan_output_service.rb` | Writes project plan files | 3.1 |
| `app/controllers/project_planning_controller.rb` | Controller for project planning UI/API | 4.1 |
| `frontend/src/api/projectPlanApi.js` | API functions for project planning | 5.1 |
| `frontend/src/store/projectPlanStore.js` | Zustand store for project planning state | 5.2 |
| `frontend/src/components/ProjectPlanPage.jsx` | Project planning chat UI | 5.3 |
| `frontend/src/components/PlanViewer.jsx` | Component to display generated plans | 5.4 |
| `test/workers/project_planner_worker_test.rb` | Unit tests for ProjectPlannerWorker | 1.1 |
| `test/workflows/project_planning_workflow_test.rb` | Unit tests for ProjectPlanningWorkflow | 1.2 |
| `test/prompts/planning/plan_structure_prompt_test.rb` | Tests for plan structure prompt | 2.2 |
| `test/prompts/planning/file_references_prompt_test.rb` | Tests for file references prompt | 2.3 |
| `test/prompts/planning/plan_synthesis_prompt_test.rb` | Tests for plan synthesis prompt | 2.4 |
| `test/services/project_plan_output_service_test.rb` | Tests for output service | 3.1 |
| `test/controllers/project_planning_controller_test.rb` | Controller tests | 4.1 |
| `test/integration/project_planner_integration_test.rb` | End-to-end integration tests | 6.1 |

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

