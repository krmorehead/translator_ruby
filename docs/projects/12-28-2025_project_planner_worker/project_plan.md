# Project Plan: Project Planner Worker

## Overview

Create a new ProjectPlannerWorker that uses the existing CodebaseResearcher to gather information about a codebase, then synthesizes that research into a structured project plan following the `.prompts/create-project-plan.md` rules. The worker outputs `file_references.md` and `project_plan.md` files to `docs/projects/{date}_{project_name}/`. The feature is callable from the frontend in a dedicated "Project Planning" mode separate from D&D mode.

## Goals

- Create a ProjectPlannerWorker that orchestrates CodebaseResearcher and project plan generation
- Generate project plans that follow the existing `.prompts/create-project-plan.md` format
- Output structured `file_references.md` and `project_plan.md` files
- Add a new frontend mode for project planning with a dedicated UI
- Create a new controller for project planning endpoints
- Use existing test fixtures for validation

---

## Milestone 1 - Worker Infrastructure

Establish the ProjectPlannerWorker and its supporting workflow.

### 1.1 - Create ProjectPlannerWorker Class

**Intent**: Create a new worker that orchestrates codebase research followed by project plan generation. This worker uses CodebaseResearcher internally to gather codebase understanding, then passes that information to a ProjectPlanningWorkflow to generate the structured plan.

**Details**:
- Create `app/workers/project_planner_worker.rb`
- Inherits from BaseWorker
- Accepts required parameters:
  - `goal` - the project objective/feature to plan (e.g., "Add user authentication")
  - `path` - root path of the target codebase
  - `project_name` - name for the project directory (slugified for filesystem)
- Accepts optional parameters:
  - `context` - seed context for research (known files, constraints, etc.)
  - `max_research_depth` - depth for CodebaseResearcher (default: 2)
- Registers CodebaseResearcher and ProjectPlanningWorkflow
- Defines worker states:
  - `:pending` - Worker created
  - `:running` - Initializing
  - `:researching` - Running CodebaseResearcher
  - `:planning` - Running ProjectPlanningWorkflow
  - `:writing` - Writing output files
  - `:complete` - Finished
  - `:failed` - Error occurred
- Execution flow:
  1. Initialize worker, create memory store
  2. Execute CodebaseResearcher with goal and path
  3. Pass research results to ProjectPlanningWorkflow
  4. Write output files via ProjectPlanOutputService
- Returns structured result with:
  - `success` - boolean
  - `project_path` - path to generated project directory
  - `file_references_path` - path to file_references.md
  - `project_plan_path` - path to project_plan.md
  - `research_summary` - summary from CodebaseResearcher
  - `metadata` - timing, states, etc.

**Tests**:
- Test initialization with goal, path, and project_name
- Test inherits from BaseWorker
- Test registers CodebaseResearcher workflow
- Test worker states are correctly defined
- Test state transitions follow expected flow
- Test execute returns structured result (uses real LLM calls)
- Test handles CodebaseResearcher failures gracefully
- Test handles ProjectPlanningWorkflow failures gracefully

---

### 1.2 - Create ProjectPlanningWorkflow Class

**Intent**: Create a workflow that transforms codebase research results into a structured project plan. This workflow receives findings from CodebaseResearcher and uses specialized prompts to generate the file_references.md and project_plan.md content.

**Details**:
- Create `app/workflows/project_planning_workflow.rb`
- Inherits from BaseWorkflow
- Accepts required parameters:
  - `goal` - the project goal
  - `project_name` - name of the project
  - `owner_id` - for memory isolation
  - `research_results` - output from CodebaseResearcher
- Accepts optional parameters:
  - `parent_memory` - parent memory store for context
  - `output_path` - where to write output (default: `docs/projects/`)
- Defines workflow states:
  - `:pending` - Workflow created
  - `:running` - Initializing
  - `:analyzing` - Analyzing research for file references
  - `:structuring` - Creating milestone/step structure
  - `:synthesizing` - Generating final plan content
  - `:complete` - Finished
  - `:failed` - Error occurred
- Execution flow:
  1. Analyze research results to identify existing and planned files
  2. Use FileReferencesPrompt to generate file_references.md content
  3. Use PlanStructurePrompt to decompose goal into milestones and steps
  4. Use PlanSynthesisPrompt to generate final project_plan.md content
- Returns structured result with:
  - `file_references_content` - markdown content for file_references.md
  - `project_plan_content` - markdown content for project_plan.md
  - `milestones` - structured milestone data
  - `existing_files` - list of existing files identified
  - `planned_files` - list of planned files

**Tests**:
- Test initialization with required parameters
- Test inherits from BaseWorkflow
- Test workflow states are correctly defined
- Test execute produces file_references content
- Test execute produces project_plan content
- Test handles empty research results gracefully
- Test content follows expected markdown structure

---

## Milestone 2 - Planning Prompts

Create LLM prompts for generating project plan components.

### 2.1 - Create BasePlanningPrompt Class

**Intent**: Create a base class for all planning-related prompts that provides common functionality and structure for project plan generation.

**Details**:
- Create `app/prompts/planning/base_planning_prompt.rb`
- Inherits from BasePrompt
- Provides common system prompt context explaining:
  - The purpose of project planning
  - The expected output format (markdown)
  - The structure requirements from create-project-plan.md
- Provides helper methods:
  - `format_research_context(research_results)` - formats research for prompts
  - `extract_file_list(research_results)` - extracts file paths from findings
  - `generate_date_prefix` - returns current date in MM-DD-YYYY format
- Sets appropriate default parameters (temperature, etc.)

**Tests**:
- Test inherits from BasePrompt
- Test format_research_context produces expected output
- Test extract_file_list correctly parses research results
- Test generate_date_prefix returns correct format

---

### 2.2 - Create PlanStructurePrompt Class

**Intent**: Create a prompt that generates the milestone and step structure for a project plan. This prompt takes the goal and research findings and outputs a structured breakdown of the work.

**Details**:
- Create `app/prompts/planning/plan_structure_prompt.rb`
- Inherits from BasePlanningPrompt
- Input:
  - `goal` - the project goal
  - `research_context` - formatted research findings
  - `existing_files` - list of existing relevant files
  - `constraints` - any constraints on the plan
- System prompt explains:
  - Milestone guidelines (logical grouping, demonstrable, 3-7 steps)
  - Step guidelines (small, focused, intent-based)
  - Requirement to include Intent, Details, and Tests sections
  - No implementation code rule
- Response schema:
  ```json
  {
    "milestones": [
      {
        "number": 1,
        "title": "string",
        "description": "string",
        "steps": [
          {
            "number": "1.1",
            "title": "string",
            "intent": "string",
            "details": ["string"],
            "tests": ["string"]
          }
        ]
      }
    ]
  }
  ```
- Includes examples from create-project-plan.md for few-shot learning

**Tests**:
- Test produces valid JSON response
- Test milestones have required fields
- Test steps have Intent section
- Test steps have Details section
- Test steps have Tests section
- Test handles complex goals with multiple milestones
- Test handles simple goals with single milestone
- Test respects step size guidelines (not too large)

---

### 2.3 - Create FileReferencesPrompt Class

**Intent**: Create a prompt that generates the file_references.md content. This prompt analyzes research findings to identify existing files and determines what new files need to be created.

**Details**:
- Create `app/prompts/planning/file_references_prompt.rb`
- Inherits from BasePlanningPrompt
- Input:
  - `goal` - the project goal
  - `project_name` - name of the project
  - `research_findings` - findings from CodebaseResearcher
  - `relevant_files` - files identified as relevant
  - `milestones` - structured milestones from PlanStructurePrompt
- System prompt explains:
  - Table format for existing and planned files
  - Document tree structure (Before and Added sections)
  - Requirement to reference step numbers for planned files
- Response schema:
  ```json
  {
    "existing_files": [
      {
        "path": "string",
        "description": "string",
        "relevance": "string"
      }
    ],
    "planned_files": [
      {
        "path": "string",
        "description": "string",
        "created_in": "string (step reference)"
      }
    ],
    "before_tree": "string (ASCII tree)",
    "added_tree": "string (ASCII tree)"
  }
  ```

**Tests**:
- Test produces valid JSON response
- Test existing_files includes discovered files
- Test planned_files includes test files
- Test created_in references valid step numbers
- Test before_tree is valid ASCII tree
- Test added_tree only contains new files
- Test handles projects with no new files

---

### 2.4 - Create PlanSynthesisPrompt Class

**Intent**: Create a prompt that synthesizes the structured milestone data into the final project_plan.md markdown content. This prompt formats the plan according to the create-project-plan.md template.

**Details**:
- Create `app/prompts/planning/plan_synthesis_prompt.rb`
- Inherits from BasePlanningPrompt
- Input:
  - `goal` - the project goal
  - `project_name` - name of the project
  - `milestones` - structured milestones from PlanStructurePrompt
  - `overview` - brief description from research
  - `goals_list` - list of high-level goals
- System prompt explains:
  - Exact markdown format expected
  - Section ordering (Overview, Goals, Milestones)
  - Step formatting (Intent, Details, Tests)
  - Use of horizontal rules between steps
- Response schema:
  ```json
  {
    "markdown": "string (complete project_plan.md content)"
  }
  ```
- Uses few-shot examples from existing project plans

**Tests**:
- Test produces valid markdown
- Test includes Overview section
- Test includes Goals section
- Test includes properly formatted milestones
- Test steps have correct numbering (1.1, 1.2, 2.1, etc.)
- Test steps have Intent, Details, Tests sections
- Test horizontal rules separate steps
- Test markdown renders correctly

---

## Milestone 3 - Output Service

Create the service that writes project plan files.

### 3.1 - Create ProjectPlanOutputService Class

**Intent**: Create a service that writes the generated project plan files to the correct directory structure. This service handles directory creation, file writing, and path management.

**Details**:
- Create `app/services/project_plan_output_service.rb`
- Constructor accepts:
  - `project_name` - name of the project (will be slugified)
  - `base_path` - path to the codebase (for relative path calculation)
  - `output_base` - base output directory (default: `docs/projects/`)
- Provides methods:
  - `project_directory` - returns full path to project directory
  - `write(file_references_content:, project_plan_content:)` - writes both files
  - `write_file_references(content)` - writes file_references.md
  - `write_project_plan(content)` - writes project_plan.md
- Directory naming: `{MM-DD-YYYY}_{slugified_project_name}/`
- Creates directory if it doesn't exist
- Returns hash with:
  - `project_path` - path to project directory
  - `file_references_path` - path to file_references.md
  - `project_plan_path` - path to project_plan.md

**Tests**:
- Test creates project directory with correct date prefix
- Test slugifies project name correctly
- Test writes file_references.md to correct location
- Test writes project_plan.md to correct location
- Test handles existing directory (doesn't overwrite without flag)
- Test returns correct paths
- Test handles special characters in project name

---

## Milestone 4 - Controller and Routes

Create the API endpoint for project planning.

### 4.1 - Create ProjectPlanningController Class

**Intent**: Create a controller that handles both the SPA entry point and API endpoints for project planning. This controller is similar to DndChatController but serves the project planning mode.

**Details**:
- Create `app/controllers/project_planning_controller.rb`
- Inherits from ApplicationController
- Endpoints:
  - `GET /project_planning` - serves the SPA (same as dnd_chat#spa pattern)
  - `POST /project_planning/create` - creates a new project plan
  - `GET /project_planning/status/:id` - gets status of planning job (future async)
- POST `/project_planning/create` request body:
  ```json
  {
    "goal": "string (required)",
    "path": "string (required)",
    "project_name": "string (required)",
    "context": {
      "known_files": ["array"],
      "constraints": "string"
    }
  }
  ```
- POST `/project_planning/create` response:
  ```json
  {
    "success": true,
    "project_path": "string",
    "file_references_path": "string",
    "project_plan_path": "string",
    "research_summary": "string",
    "milestones": [{}]
  }
  ```
- Validates:
  - goal is present
  - path exists and is readable
  - project_name is present and valid
- Add routes to config/routes.rb:
  ```ruby
  get "/project_planning", to: "project_planning#spa"
  post "/project_planning/create", to: "project_planning#create"
  ```

**Tests**:
- Test spa action serves frontend
- Test create with valid parameters returns success
- Test create validates goal presence
- Test create validates path existence
- Test create validates project_name presence
- Test create handles worker failures gracefully
- Test response includes all expected fields
- Test uses real LLM calls (no mocking)

---

## Milestone 5 - Frontend Integration

Add project planning mode to the frontend application.

### 5.1 - Create Project Plan API Module

**Intent**: Create an API module for communicating with the project planning backend. This follows the same pattern as dndChatApi.js.

**Details**:
- Create `frontend/src/api/projectPlanApi.js`
- Export functions:
  - `createProjectPlan({ goal, path, projectName, context })` - POST to create plan
  - `getProjectPlanStatus(id)` - GET status (for future async support)
- Use same error handling pattern as dndChatApi
- Return parsed JSON responses

**Tests**:
- Test createProjectPlan sends correct request body
- Test createProjectPlan handles success response
- Test createProjectPlan handles error response
- Test getProjectPlanStatus sends correct request

---

### 5.2 - Create Project Plan Store

**Intent**: Create a Zustand store for managing project planning state. This follows the same pattern as chatStore.js but for project planning.

**Details**:
- Create `frontend/src/store/projectPlanStore.js`
- State:
  - `goal` - current planning goal
  - `path` - target codebase path
  - `projectName` - project name
  - `loading` - boolean loading state
  - `error` - error message
  - `result` - planning result (paths, summary, milestones)
- Actions:
  - `setGoal(goal)` - set planning goal
  - `setPath(path)` - set codebase path
  - `setProjectName(name)` - set project name
  - `createPlan()` - trigger plan creation
  - `reset()` - clear state
- Use zustand create() pattern

**Tests**:
- Test initial state
- Test setGoal updates goal
- Test setPath updates path
- Test createPlan triggers API call
- Test loading state during API call
- Test error state on failure
- Test result state on success

---

### 5.3 - Create ProjectPlanPage Component

**Intent**: Create the main page component for project planning. This provides a form for inputting planning parameters and displays results.

**Details**:
- Create `frontend/src/components/ProjectPlanPage.jsx`
- Layout:
  - Header with "Project Planner" title
  - Form section with inputs for:
    - Goal (textarea)
    - Path (text input)
    - Project Name (text input)
  - Submit button
  - Loading indicator during planning
  - Results section showing:
    - Success/error status
    - Links to generated files
    - Milestone summary
- Uses projectPlanStore for state management
- Styled to match existing chat UI aesthetics
- Import and use existing CSS patterns

**Tests**:
- Test renders form inputs
- Test submit button triggers createPlan
- Test displays loading state
- Test displays error message
- Test displays success result
- Test displays file paths as links

---

### 5.4 - Create PlanViewer Component

**Intent**: Create a component that displays the generated project plan in a readable format. This component can show the milestone structure and allows expanding/collapsing sections.

**Details**:
- Create `frontend/src/components/PlanViewer.jsx`
- Props:
  - `milestones` - array of milestone objects
  - `fileReferencesPath` - path to file_references.md
  - `projectPlanPath` - path to project_plan.md
- Layout:
  - File paths with copy-to-clipboard buttons
  - Collapsible milestone sections
  - Step cards with Intent, Details, Tests
  - Visual hierarchy matching project plan structure
- Use accordion pattern for milestones
- Highlight test requirements

**Tests**:
- Test renders milestone titles
- Test renders step titles
- Test shows Intent section
- Test shows Details section
- Test shows Tests section
- Test milestones are collapsible
- Test file paths are displayed

---

### 5.5 - Update App.jsx for Mode Routing

**Intent**: Update the main App component to support routing between D&D mode and Project Planning mode based on URL path.

**Details**:
- Modify `frontend/src/App.jsx`
- Add route detection for `/project_planning`
- Render ProjectPlanPage when path matches
- Keep existing D&D chat and inspector routes
- Add mode indicator in UI (optional header showing current mode)
- Pattern:
  ```jsx
  const path = window.location.pathname;
  if (path.startsWith("/project_planning")) {
    return <ProjectPlanPage />;
  }
  if (path.startsWith("/inspector")) {
    return <InspectorPage />;
  }
  return <ChatPage ... />;
  ```

**Tests**:
- Test renders ChatPage for root path
- Test renders InspectorPage for /inspector
- Test renders ProjectPlanPage for /project_planning
- Test mode switching works correctly

---

## Milestone 6 - Integration Testing

Create comprehensive integration tests.

### 6.1 - Create End-to-End Integration Tests

**Intent**: Create integration tests that exercise the full project planning flow against the fixture codebase. These tests validate that all components work together correctly.

**Details**:
- Create `test/integration/project_planner_integration_test.rb`
- Include ResearchTestFactory for fixture access
- Test scenarios:
  - Plan "Add logging to Calculator" on fixture codebase
  - Plan "Create a new service" on fixture codebase
  - Plan with provided context (known files)
- Verify:
  - Output files are created in correct location
  - file_references.md contains expected structure
  - project_plan.md contains expected structure
  - Milestones have proper formatting
  - Steps have Intent, Details, Tests sections
- Use real LLM calls (no mocking per project rules)
- Clean up generated files after tests

**Tests**:
- Test full planning flow produces valid output
- Test file_references.md has Before and Added trees
- Test project_plan.md has correct milestone structure
- Test steps reference correct files
- Test handles complex multi-milestone projects
- Test handles simple single-milestone projects
- Test parallel planning sessions don't conflict

---

### 6.2 - Create Controller Integration Tests

**Intent**: Create integration tests for the ProjectPlanningController that test the full request/response cycle.

**Details**:
- Create `test/controllers/project_planning_controller_test.rb`
- Test POST /project_planning/create with valid params
- Test POST /project_planning/create with invalid params
- Test response structure matches expected format
- Test error handling and messages
- Use fixture codebase for path validation
- Use real LLM calls (no mocking)

**Tests**:
- Test create returns 200 with valid params
- Test create returns 422 with missing goal
- Test create returns 422 with invalid path
- Test create returns 422 with missing project_name
- Test response includes success boolean
- Test response includes file paths on success
- Test response includes error message on failure

---

## Execution Rules

When implementing this project plan:

1. **Complete one step at a time** - Do not jump ahead
2. **Write tests first** - Follow TDD principles
3. **Run tests after each step** - Verify before proceeding
4. **Update file_references.md** - Mark files as created
5. **Commit after each milestone** - Keep atomic, reviewable changes

## Review Checklist

Before finalizing implementation:

- [ ] All worker states and transitions are properly defined
- [ ] CodebaseResearcher integration is working
- [ ] All prompts produce valid structured output
- [ ] Output files match create-project-plan.md format
- [ ] Frontend successfully communicates with backend
- [ ] Mode switching works in App.jsx
- [ ] All tests pass with real LLM calls
- [ ] No require statements added (except in root files)
- [ ] Controller logic is in service objects per project rules

