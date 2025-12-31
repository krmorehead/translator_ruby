# Project Plan: Plan Agent Worker

## Overview

Create a PlanAgentWorker inspired by Cline's "Plan Mode" that analyzes user requests, explores the codebase, and generates structured execution plans with milestones and steps. Unlike Cline's synchronous approval model, this worker operates autonomously but produces transparent, reviewable plans that can be executed by the Act Agent Worker.

## Goals

- Create a worker that generates detailed execution plans from user requests
- Analyze relevant code to understand implementation context
- Produce structured plans with milestones, steps, and rationale
- Enable plan review before execution (future Act Agent integration)
- Follow our OOP patterns and state machine architecture

---

## Milestone 1 - Core Worker and Workflow Infrastructure

Build the foundational worker class and workflow orchestration for plan generation.

### 1.1 - Create PlanAgentWorker Class

**Intent**: Create the main worker class that orchestrates plan generation. This provides the entry point and state management for the planning process.

**Details**:
- Extend BaseWorker with state machine
- Define states: pending → running → analyzing → planning → writing → complete/failed
- Accept parameters: goal (what to accomplish), path (codebase root), context (optional hints)
- Register workflows: CodebaseAnalysisWorkflow, PlanGenerationWorkflow
- Create memory store (ResearchMemoryStore) for tracking decisions
- Implement execute method orchestrating the full pipeline
- Store analysis results and generated plan in instance variables
- Generate unique owner_id for memory isolation

**Tests**:
- Test worker initialization with required parameters
- Test state transitions through the full lifecycle
- Test error handling and failed state transitions
- Test memory store creation and isolation
- Test workflow registration

---

### 1.2 - Create PlanGenerationWorkflow

**Intent**: Create the workflow responsible for generating the actual execution plan. This workflow takes analysis results and produces a structured plan with milestones and steps.

**Details**:
- Extend BaseWorkflow with state machine
- Accept parameters: goal, analysis_results, owner_id, parent_memory
- Initialize workflow memory (WorkflowMemoryStore)
- Use PlanGenerationPrompt to convert analysis into structured plan
- Call GenericLLMClient with planning prompt
- Parse LLM response into ExecutionPlan object
- Record plan generation decisions to memory
- Handle errors and mark workflow as failed on LLM errors

**Tests**:
- Test workflow initialization and state transitions
- Test plan generation from analysis results
- Test LLM client integration
- Test memory recording during generation
- Test error handling with invalid LLM responses

---

### 1.3 - Create CodebaseAnalysisWorkflow

**Intent**: Create the workflow that analyzes the codebase to understand context for plan generation. This provides the "research" phase before planning.

**Details**:
- Extend BaseWorkflow with state machine
- Accept parameters: goal, path, owner_id, parent_memory
- Initialize workflow memory
- Use tools (FileTreeTool, GrepTool, ReadFileTool) to explore codebase
- Use CodebaseAnalysisPrompt to identify relevant files
- Build analysis results hash with: relevant_files, patterns, constraints, context
- Limit analysis depth to prevent excessive exploration (configurable max_depth)
- Record analysis decisions to memory
- **Note**: This workflow performs lightweight, targeted analysis for planning context. It is distinct from ResearchWorkflow (used by CodebaseResearcher) which does deeper, iterative exploration with sub-question decomposition. CodebaseAnalysisWorkflow focuses on identifying files and patterns relevant to the specific planning goal

**Tests**:
- Test workflow initialization
- Test tool integration (file tree, grep, read file)
- Test analysis result structure
- Test depth limiting
- Test memory recording

---

## Milestone 2 - Plan Domain Models

Create the domain objects representing execution plans, milestones, and steps.

### 2.1 - Create ExecutionPlan Class

**Intent**: Create the top-level plan object that contains milestones, steps, and metadata. This is the primary result object returned by the PlanAgentWorker.

**Details**:
- Implement as PORO in app/models/planning/
- Required attributes: goal, milestones (array of PlanMilestone), created_at, metadata
- Optional attributes: constraints, assumptions, risks
- Provide methods: milestone_count, step_count, add_milestone
- Implement to_h for serialization (recursive with milestones)
- Implement self.from_h for deserialization
- Validate: goal is non-empty string, milestones is array
- Follow OOP patterns: strict validation, fail-fast

**Tests**:
- Test initialization with valid parameters
- Test validation failures with invalid data
- Test add_milestone method
- Test milestone_count and step_count methods
- Test to_h serialization (includes all milestones)
- Test from_h deserialization and round-trip
- Test metadata handling

---

### 2.2 - Create PlanStep Class

**Intent**: Create the individual step object representing a single actionable task. Steps are the atomic units of execution plans.

**Details**:
- Implement as PORO in app/models/planning/
- Required attributes: title, intent, details (array), tests (array)
- Optional attributes: estimated_duration, dependencies (step IDs), file_changes
- Attributes: id (UUID), order_index, status (:pending, :in_progress, :complete, :skipped)
- Provide methods: pending?, complete?, mark_complete, mark_skipped
- Implement to_h and self.from_h
- Validate: title and intent are non-empty strings, details and tests are arrays
- Follow OOP patterns with strict validation

**Tests**:
- Test initialization with required and optional parameters
- Test validation on all attributes
- Test status query methods (pending?, complete?)
- Test status update methods (mark_complete, mark_skipped)
- Test to_h serialization
- Test from_h deserialization
- Test dependencies handling

---

### 2.3 - Create PlanMilestone Class

**Intent**: Create the milestone object that groups related steps into logical phases. Milestones provide high-level organization to plans.

**Details**:
- Implement as PORO in app/models/planning/
- Required attributes: title, description, steps (array of PlanStep)
- Optional attributes: success_criteria, estimated_duration
- Attributes: id (UUID), order_index, status (derived from steps)
- Provide methods: step_count, add_step, progress (percentage complete), completed?
- Implement to_h (recursive with steps) and self.from_h
- Validate: title is non-empty string, steps is array of PlanStep instances
- Follow OOP patterns

**Tests**:
- Test initialization with valid parameters
- Test add_step method
- Test step_count method
- Test progress calculation (0-100% based on completed steps)
- Test completed? method (all steps complete)
- Test to_h serialization with nested steps
- Test from_h deserialization with step reconstruction
- Test validation

---

## Milestone 3 - Planning Prompts

Create the prompt classes that guide LLM interactions during planning.

### 3.1 - Create PlanGenerationPrompt

**Intent**: Create the prompt that instructs the LLM to generate a structured execution plan from analysis results. This is the core planning intelligence.

**Details**:
- Extend BasePrompt
- Accept parameters: goal, analysis_results, context (optional)
- Build system message explaining plan structure (milestones → steps)
- Include examples of well-structured plans
- Specify output format: JSON with milestones array
- Each milestone must have: title, description, steps array
- Each step must have: title, intent, details array, tests array
- Emphasize: steps should be small, testable, incremental
- Include analysis results (relevant files, patterns, constraints) in context
- Specify response_format: json_object for structured output

**Tests**:
- Test prompt initialization
- Test system message includes plan structure guidance
- Test user message includes goal and analysis results
- Test response format is json_object
- Test prompt renders correctly
- Test optional context parameter

---

### 3.2 - Create CodebaseAnalysisPrompt

**Intent**: Create the prompt that guides the LLM in analyzing the codebase to identify relevant files and patterns. This provides context for planning.

**Details**:
- Extend BasePrompt
- Accept parameters: goal, file_tree (from FileTreeTool), path
- Build system message explaining analysis task
- Instruct LLM to identify: relevant files, patterns to follow, constraints, existing similar implementations
- Provide file tree structure in user message
- Request specific file paths to examine
- Specify JSON output with: relevant_files array, patterns array, constraints array, recommended_tools array
- Limit to top 10-15 most relevant files

**Tests**:
- Test prompt initialization
- Test system message structure
- Test file tree inclusion in user message
- Test JSON output format specification
- Test prompt rendering

---

### 3.3 - Create StepRefinementPrompt

**Intent**: Create a prompt for refining individual plan steps based on feedback or additional context. This enables iterative plan improvement (future feature).

**Details**:
- Extend BasePrompt
- Accept parameters: step (PlanStep), feedback, context
- Build system message explaining refinement task
- Include current step details in user message
- Include feedback/suggestions
- Request refined step with same structure
- Specify JSON output matching PlanStep structure

**Tests**:
- Test prompt initialization with step and feedback
- Test system message structure
- Test step serialization in user message
- Test feedback inclusion
- Test JSON output format

---

## Milestone 4 - Output and Integration

Create the output service and integrate all components.

### 4.1 - Create PlanOutputService

**Intent**: Create a service responsible for writing plan files to the filesystem in a structured format. This makes plans reviewable and executable.

**Details**:
- Create as service in app/services/
- Accept parameters: execution_plan, base_path (codebase root)
- Generate output directory: docs/plans/{timestamp}_{sanitized_goal}/
- Write plan.md with markdown formatting: overview, goals, milestones with steps
- Write plan.json with full ExecutionPlan serialization
- Write metadata.json with: created_at, goal, worker_id, analysis_summary
- Return hash with file paths: plan_path, json_path, metadata_path
- Create directories if they don't exist

**Tests**:
- Test service initialization
- Test directory creation
- Test plan.md generation with proper formatting
- Test plan.json serialization
- Test metadata.json creation
- Test returned file paths are correct
- Test handling of existing directories

---

### 4.2 - Integrate Worker Pipeline

**Intent**: Wire up all components in PlanAgentWorker.execute to create the complete planning pipeline.

**Details**:
- In execute method:
  1. trigger(:start) and initialize_worker (create memory)
  2. trigger(:initialized) and run CodebaseAnalysisWorkflow
  3. Store analysis results, trigger(:analyzed)
  4. Run PlanGenerationWorkflow with analysis results
  5. Store plan result, trigger(:planned)
  6. Run PlanOutputService to write files
  7. trigger(:finish), return result object
- Result object includes: execution_plan, output_paths, analysis_summary, metadata
- Record all decisions to memory with rationale
- Handle errors at each phase, mark_failed on exceptions

**Tests**:
- Test full pipeline execution end-to-end
- Test state transitions at each phase
- Test analysis → planning → output flow
- Test memory recording throughout
- Test error handling at each phase
- Test final result structure

---

### 4.3 - Integration Testing

**Intent**: Create comprehensive integration tests that verify the complete system working together.

**Details**:
- Create integration test file: test/integration/plan_agent_integration_test.rb
- Test complete planning flow with real codebase
- Test plan output files are created correctly
- Test memory persistence across workflow boundaries
- Test error recovery and retry logic
- Use fixtures for predictable LLM responses (or real LLM with simple goals)
- Verify plan quality: has milestones, has steps, steps have tests

**Tests**:
- Integration test: complete planning flow
- Integration test: plan file generation
- Integration test: memory accumulation
- Integration test: error handling and recovery
- Integration test: plan structure validation

---

## Milestone 5 - Documentation and Polish

Complete the implementation with documentation and refinements.

### 5.1 - Create Documentation

**Intent**: Document the PlanAgentWorker API, usage patterns, and examples for other developers.

**Details**:
- Create docs/references/workers/plan_agent_worker.md
- Document: purpose, architecture, state machine, workflows used
- Provide usage examples: basic, with context, error handling
- Document result structure and output files
- Document integration with future ActAgentWorker
- Include state machine diagram
- Document memory structure and sections

**Tests**:
- Manual review of documentation completeness
- Verify all examples are runnable
- Check accuracy of API documentation

---

### 5.2 - Add Error Messages and Logging

**Intent**: Improve observability and debugging with clear error messages and structured logging.

**Details**:
- Review all error handling in worker and workflows
- Ensure ArgumentError messages are descriptive
- Add Rails.logger calls at key decision points
- Log: workflow starts/completions, analysis findings count, plan milestone count
- Log errors with full context (state, goal, step)
- Follow existing logging patterns from ProjectPlannerWorker

**Tests**:
- Test error messages are descriptive
- Manual verification of log output during execution
- Verify logs include relevant context

---

### 5.3 - Performance Optimization

**Intent**: Ensure the planning process is efficient and doesn't make excessive LLM calls or file reads.

**Details**:
- Review CodebaseAnalysisWorkflow for excessive file reading
- Implement caching for file tree results
- Limit grep results to prevent overwhelming context
- Add configurable max_analysis_depth parameter
- Add configurable max_files_to_analyze parameter
- Monitor token usage and optimize prompts
- Add timing instrumentation to workflows

**Tests**:
- Test configurable depth limiting works
- Test file analysis doesn't read more than max_files
- Benchmark planning time for typical goals
- Verify token usage is reasonable

---

## Execution Guidelines

1. Implement one step at a time in order
2. Write tests before implementation (TDD)
3. Run full test suite after each step
4. Commit after completing each milestone
5. Update file_references.md as files are created
6. Follow OOP patterns strictly (validation, fail-fast, state machines)
7. Reference existing workers (ProjectPlannerWorker, CodebaseResearcher) for patterns
8. Use consistent error handling and logging

## Success Criteria

- [ ] PlanAgentWorker can generate plans from simple goals
- [ ] Plans have logical milestone structure
- [ ] Steps are small, testable, and incremental
- [ ] All tests pass with >90% coverage
- [ ] Plans are written to docs/plans/ directory
- [ ] Memory is persisted throughout the process
- [ ] Error handling is robust at all phases
- [ ] Documentation is complete and accurate
- [ ] Integration tests validate end-to-end flow

