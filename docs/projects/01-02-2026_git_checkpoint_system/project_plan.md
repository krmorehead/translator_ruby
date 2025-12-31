# Project Plan: Git Checkpoint System

## Overview

Implement a comprehensive Git-based checkpoint system inspired by Cline's snapshot/rollback feature. This system automatically creates Git commits at workflow boundaries, generates diffs for review, and enables rollback to any checkpoint. This provides safety, auditability, and confidence when agents make automated changes to codebases.

## Goals

- Automatically create Git checkpoints at milestone/workflow boundaries
- Generate human-readable diffs for any checkpoint
- Enable rollback to any previous checkpoint
- Track checkpoint metadata (what changed, why, when)
- Integrate seamlessly with Workers and Workflows
- Provide UI-ready data structure for frontend visualization
- Handle edge cases (uncommitted changes, non-git repos, conflicts)

---

## Milestone 1 - Core Git Services

Build the foundational services for Git checkpoint management.

### 1.1 - Create GitCheckpointManager

**Intent**: Create the primary service for managing Git checkpoints. This handles checkpoint creation, listing, and metadata tracking.

**Details**:
- Create as service in app/services/
- Accept parameters on initialization: repository_path, owner_id (for namespacing)
- Methods:
  - create_checkpoint(message:, metadata: {}) → Checkpoint object
  - list_checkpoints(limit: 50) → array of Checkpoint objects
  - get_checkpoint(checkpoint_id) → Checkpoint object
  - checkpoint_exists?(checkpoint_id) → boolean
- Use BashTool for git operations: git add ., git commit, git log, git show
- Checkpoint message format: "[{owner_id}] {message} - {timestamp}"
- Store metadata in commit message body as YAML
- Validate repository is a git repo (has .git directory)
- Handle errors: not a git repo, nothing to commit, git command failures
- Return Checkpoint domain object on creation

**Tests**:
- Test create_checkpoint with message and metadata
- Test checkpoint message formatting
- Test list_checkpoints returns correct objects
- Test get_checkpoint retrieval
- Test checkpoint_exists? validation
- Test error handling for non-git repos
- Test error handling for empty commits

---

### 1.2 - Create GitDiffGenerator

**Intent**: Create a service for generating diffs between checkpoints or between a checkpoint and current state. This enables code review.

**Details**:
- Create as service in app/services/
- Accept repository_path on initialization
- Methods:
  - diff_checkpoint(checkpoint_id, format: :unified) → string (unified diff)
  - diff_between(from_checkpoint_id, to_checkpoint_id) → string
  - diff_files(checkpoint_id) → array of FileDiff objects
  - diff_summary(checkpoint_id) → hash { files_changed:, insertions:, deletions: }
- Use git diff and git show commands
- Support formats: :unified (default), :stat, :name-only
- Parse diff output into structured FileDiff objects
- Handle binary files gracefully (indicate binary, no diff content)
- Calculate statistics: lines added, lines deleted, files changed

**Tests**:
- Test diff_checkpoint generates unified diff
- Test diff_between compares two checkpoints
- Test diff_files returns FileDiff objects
- Test diff_summary calculates statistics correctly
- Test different diff formats
- Test binary file handling
- Test error handling for invalid checkpoint IDs

---

### 1.3 - Create GitRollbackService

**Intent**: Create a service for rolling back to previous checkpoints. This enables undo functionality and safe experimentation.

**Details**:
- Create as service in app/services/
- Accept repository_path on initialization
- Methods:
  - rollback_to(checkpoint_id, strategy: :hard) → boolean
  - can_rollback?(checkpoint_id) → boolean (checks for conflicts)
  - create_backup_before_rollback → backup_checkpoint_id
  - list_rollback_candidates(from_checkpoint_id) → array
- Strategies: :hard (git reset --hard), :soft (git reset --soft), :mixed
- Always create backup checkpoint before rollback with message "Backup before rollback"
- Validate: checkpoint exists, no uncommitted changes (require clean working directory)
- Handle errors: uncommitted changes, invalid checkpoint, git failures
- Return success boolean

**Tests**:
- Test rollback_to with hard strategy
- Test rollback_to with soft strategy
- Test backup creation before rollback
- Test can_rollback? validation
- Test error handling for uncommitted changes
- Test error handling for invalid checkpoints
- Integration test: rollback and verify files restored

---

## Milestone 2 - Checkpoint Domain Models

Create domain objects for checkpoints, diff information, and registries.

### 2.1 - Create Checkpoint Class

**Intent**: Create a domain object representing a Git checkpoint with metadata. This provides a structured interface to checkpoint data.

**Details**:
- Implement as PORO in app/models/
- Required attributes: id (git commit hash), message, created_at (timestamp)
- Optional attributes: metadata (hash), author, files_changed (array), stats (hash with insertions/deletions)
- Derive attributes from git commit: parent_id, tree_id
- Provide methods: short_id (first 7 chars), age (time since creation), file_count
- Implement to_h for serialization
- Implement self.from_git_commit(commit_hash, repo_path) class method
- Parse metadata from commit message body (YAML format)
- Validate: id is non-empty string, created_at is Time
- Follow OOP patterns

**Tests**:
- Test initialization with required parameters
- Test from_git_commit class method parses correctly
- Test short_id returns 7 characters
- Test age calculation
- Test file_count from stats
- Test to_h serialization
- Test metadata parsing from commit message
- Test validation

---

### 2.2 - Create CheckpointRegistry Class

**Intent**: Create a registry for tracking and querying checkpoints within a worker/workflow session. This provides session-scoped checkpoint management.

**Details**:
- Implement as PORO in app/models/
- Accept owner_id on initialization
- Attributes: checkpoints (array of Checkpoint), owner_id, created_at
- Methods:
  - add(checkpoint) → add to registry
  - find(checkpoint_id) → Checkpoint or nil
  - latest → most recent Checkpoint
  - for_milestone(milestone_id) → array of Checkpoints
  - count → number of checkpoints
- Optionally persist to JSON file in agent state directory
- Implement to_h and self.from_h for persistence
- Validate: owner_id is string, checkpoints is array

**Tests**:
- Test registry initialization
- Test add method
- Test find method
- Test latest returns most recent
- Test for_milestone filtering
- Test count method
- Test to_h and from_h for persistence
- Test validation

---

### 2.3 - Create FileDiff Class

**Intent**: Create a domain object representing changes to a single file. This enables per-file diff review.

**Details**:
- Implement as PORO in app/models/
- Required attributes: file_path, change_type (:added, :modified, :deleted)
- Optional attributes: insertions (int), deletions (int), diff_content (string), is_binary (boolean)
- Provide methods: changed?, lines_changed, change_summary ("+5 -3")
- Implement to_h and self.from_git_diff(diff_output) class method
- Parse git diff output to extract file path, stats, and content
- Handle binary files (is_binary = true, no diff_content)
- Follow OOP patterns with validation

**Tests**:
- Test initialization with valid parameters
- Test from_git_diff parsing
- Test change_type determination
- Test lines_changed calculation
- Test change_summary formatting
- Test binary file handling
- Test to_h serialization
- Test validation

---

## Milestone 3 - Workflow Integration

Integrate checkpoint system with Workers and Workflows.

### 3.1 - Create Checkpointable Concern

**Intent**: Create a reusable concern that can be included in Workers and Workflows to add checkpoint capabilities.

**Details**:
- Create in lib/concerns/checkpointable.rb
- Provides methods when included:
  - create_checkpoint(message, metadata: {}) → Checkpoint
  - checkpoint_manager → GitCheckpointManager instance
  - checkpoint_registry → CheckpointRegistry instance
  - last_checkpoint → most recent Checkpoint
- Initialize checkpoint_manager with self.path (from Worker)
- Initialize checkpoint_registry with self.owner_id
- Lazily create manager/registry on first use
- Store checkpoint IDs in workflow memory after creation
- Automatically add checkpoint creation to state transition hooks

**Tests**:
- Test concern can be included in class
- Test create_checkpoint method
- Test checkpoint_manager initialization
- Test checkpoint_registry initialization
- Test last_checkpoint retrieval
- Test memory integration

---

### 3.2 - Create CheckpointPolicy

**Intent**: Create a policy object that determines when checkpoints should be automatically created. This provides configurable checkpoint triggers.

**Details**:
- Create as service in app/services/
- Accept configuration: checkpoint_on (array of triggers)
- Triggers: :milestone_start, :milestone_end, :workflow_start, :workflow_end, :step_complete, :error
- Methods:
  - should_checkpoint?(event, context) → boolean
  - checkpoint_message_for(event, context) → string
- Default policy: checkpoint on milestone_end and error
- Context includes: worker_id, milestone_id, step_id, error_message
- Generate appropriate checkpoint messages based on event
- Allow custom policies to be defined per worker

**Tests**:
- Test default policy triggers
- Test should_checkpoint? logic for each trigger
- Test checkpoint_message_for generates appropriate messages
- Test custom policy configuration
- Test context parameter usage

---

### 3.3 - Integrate with BaseWorker

**Intent**: Update BaseWorker to automatically create checkpoints based on policy. This makes checkpointing seamless for all workers.

**Details**:
- Include Checkpointable concern in BaseWorker
- Add checkpoint_policy attribute (defaults to CheckpointPolicy.new)
- Add on_transition hook that checks checkpoint_policy
- If policy says checkpoint, call create_checkpoint with appropriate message
- Store checkpoint IDs in worker's memory_store
- Provide disable_checkpoints flag for testing
- Add checkpoint_count method
- Add rollback_to_last_checkpoint method for error recovery

**Tests**:
- Test BaseWorker includes Checkpointable
- Test automatic checkpoint creation on transitions
- Test checkpoint_policy is configurable
- Test disable_checkpoints flag
- Test checkpoint storage in memory
- Test rollback_to_last_checkpoint

---

## Milestone 4 - Frontend Integration and Polish

Prepare checkpoint data for frontend visualization and add polish.

### 4.1 - Create Checkpoint API Endpoint

**Intent**: Create API endpoints for frontend to query checkpoints and request rollbacks.

**Details**:
- Add routes in config/routes.rb:
  - GET /api/v1/checkpoints - list all checkpoints
  - GET /api/v1/checkpoints/:id - get checkpoint details
  - GET /api/v1/checkpoints/:id/diff - get diff for checkpoint
  - POST /api/v1/checkpoints/:id/rollback - rollback to checkpoint
- Create Api::V1::CheckpointsController
- Methods: index, show, diff, rollback
- Use GitCheckpointManager and GitDiffGenerator
- Return JSON with checkpoint data and file diffs
- Require authentication (future: add auth middleware)
- Handle errors gracefully with appropriate status codes

**Tests**:
- Test GET /checkpoints returns checkpoint list
- Test GET /checkpoints/:id returns checkpoint details
- Test GET /checkpoints/:id/diff returns diff content
- Test POST /checkpoints/:id/rollback performs rollback
- Test error handling for invalid IDs
- Test JSON response format

---

### 4.2 - Integration Testing

**Intent**: Create comprehensive integration tests for the full checkpoint system.

**Details**:
- Create test/integration/checkpoint_integration_test.rb
- Test scenarios:
  1. Worker creates checkpoints automatically during execution
  2. List checkpoints and retrieve details
  3. Generate diffs for checkpoints
  4. Rollback to previous checkpoint and verify files restored
  5. Multiple rollbacks in sequence
  6. Error handling with invalid operations
- Use ActAgentWorker with simple plan for real-world scenario
- Verify checkpoint registry persists correctly
- Verify memory contains checkpoint metadata

**Tests**:
- Integration test: automatic checkpoint creation
- Integration test: checkpoint listing and retrieval
- Integration test: diff generation
- Integration test: rollback and restore
- Integration test: sequential rollbacks
- Integration test: error handling

---

### 4.3 - Documentation and Examples

**Intent**: Document the checkpoint system for developers and users.

**Details**:
- Create docs/references/checkpoint_system.md
- Document: architecture, automatic checkpoints, manual checkpoints, rollback
- Explain checkpoint policy and configuration
- Provide usage examples: creating checkpoints, viewing diffs, rolling back
- Document API endpoints for frontend integration
- Include diagrams: checkpoint lifecycle, rollback flow
- Document best practices: when to checkpoint, rollback strategies
- Document limitations: requires git repo, clean working directory

**Tests**:
- Manual review of documentation completeness
- Verify all examples are runnable
- Check accuracy of API documentation

---

## Milestone 5 - Advanced Features

Add advanced checkpoint features for power users.

### 5.1 - Checkpoint Tags and Branches

**Intent**: Enable tagging important checkpoints and creating branches for experimentation.

**Details**:
- Add tag_checkpoint(checkpoint_id, tag_name) to GitCheckpointManager
- Add create_branch_from_checkpoint(checkpoint_id, branch_name)
- Tags stored as git tags: "agent/{owner_id}/{tag_name}"
- Branches created with git checkout -b
- List tagged checkpoints separately
- Enable rollback to tagged checkpoints by tag name

**Tests**:
- Test tag_checkpoint creates git tag
- Test create_branch_from_checkpoint
- Test rollback to tagged checkpoint by name
- Test tag name validation

---

### 5.2 - Checkpoint Comparison View

**Intent**: Create a service for comparing two checkpoints side-by-side.

**Details**:
- Add compare_checkpoints(from_id, to_id) to GitDiffGenerator
- Return structured comparison: files changed, unified diffs, statistics
- Group changes by directory
- Highlight significant changes (large additions/deletions)
- Format output for frontend consumption

**Tests**:
- Test compare_checkpoints returns correct structure
- Test directory grouping
- Test statistics calculation
- Test formatting

---

### 5.3 - Checkpoint Cleanup

**Intent**: Implement garbage collection for old checkpoints to prevent repo bloat.

**Details**:
- Add cleanup_old_checkpoints(keep_count: 50) to GitCheckpointManager
- Keep most recent N checkpoints, delete older ones
- Never delete tagged checkpoints
- Use git rebase to remove commits (dangerous - document clearly)
- Alternative: squash commits into summary commits
- Configurable retention policy

**Tests**:
- Test cleanup keeps recent checkpoints
- Test cleanup respects keep_count
- Test tagged checkpoints are preserved
- Test cleanup in real git repo (integration test)

---

## Execution Guidelines

1. Implement one step at a time in order
2. Write tests before implementation (TDD)
3. Test with real Git repositories (use tmp directories)
4. Run full test suite after each step
5. Commit after completing each milestone
6. Update file_references.md as files are created
7. Follow OOP patterns strictly
8. Handle Git errors gracefully
9. Document Git command usage clearly
10. Test rollback scenarios carefully (data loss potential)

## Success Criteria

- [ ] Checkpoints are created automatically at workflow boundaries
- [ ] Diffs can be generated for any checkpoint
- [ ] Rollback successfully restores previous state
- [ ] Checkpoint metadata is tracked and queryable
- [ ] Integration with Workers is seamless
- [ ] API endpoints work correctly
- [ ] All tests pass with >90% coverage
- [ ] Documentation is complete and accurate
- [ ] Edge cases are handled gracefully
- [ ] Frontend can consume checkpoint data

## Safety Considerations

**Important**: This system modifies Git history and file contents. Key safety measures:

1. Always require clean working directory before checkpoint/rollback
2. Create backup checkpoint before any rollback
3. Never force push or rewrite published history
4. Clearly warn users about data loss potential
5. Test rollback logic extensively
6. Provide dry-run mode for testing
7. Log all checkpoint and rollback operations
8. Store checkpoint metadata redundantly (memory + git)

