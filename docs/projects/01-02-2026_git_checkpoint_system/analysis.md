# Git Checkpoint System - Analysis Report

## Executive Summary

The Git checkpoint system project plan is **well-designed** and aligns with current codebase patterns. However, there are several opportunities to simplify and integrate more naturally with existing infrastructure:

1. **Already Implemented**: Basic `CheckpointService` exists with git operations ✅
2. **Redundancy**: Several proposed services duplicate functionality in `CheckpointService` and `DiffGenerationService`
3. **Memory Integration**: Need to enhance how checkpoints integrate with `WorkflowMemoryStore`
4. **Domain Models**: The plan's domain models (`Checkpoint`, `FileDiff`) are valuable additions
5. **OOP Compliance**: Existing services follow OOP patterns correctly ✅

---

## Current State Analysis

### What Already Exists

#### 1. CheckpointService (`app/services/checkpoint_service.rb`) ✅
**Status**: IMPLEMENTED and TESTED

**Current Capabilities**:
- ✅ Create git commits with metadata
- ✅ Store metadata in git notes (JSON format)
- ✅ List checkpoints with filtering
- ✅ Validate checkpoint existence
- ✅ Generate diffs between checkpoints
- ✅ Retrieve checkpoint metadata

**Missing from Plan**:
- No rollback functionality
- No `Checkpoint` domain object (returns hashes)
- No checkpoint registry
- No policy system

**Integration**:
- Used in `SisyphusWorker` (lines 222, 259, 525-586)
- Follows OOP patterns correctly
- Proper validation and error handling

#### 2. DiffGenerationService (`app/services/diff_generation_service.rb`) ✅
**Status**: IMPLEMENTED and TESTED

**Current Capabilities**:
- ✅ Generate unified diffs for file changes
- ✅ Handle creation/deletion/modification
- ✅ Binary file detection
- ✅ Workspace-wide diffs from `ChangeSet` objects
- ✅ Diff statistics (lines added/removed/files changed)
- ✅ Multiple output formats (plain, markdown, HTML)

**Missing from Plan**:
- No `FileDiff` domain object (returns strings)
- No git-specific diff parsing

**Integration**:
- Used in `SisyphusWorker` (line 223, 395, 472-499)
- Stateless service pattern
- Proper validation

#### 3. ExecutionOutputService (`app/services/execution_output_service.rb`) ✅
**Status**: IMPLEMENTED and TESTED

**Current Capabilities**:
- ✅ Write comprehensive execution logs
- ✅ Include checkpoint IDs in output
- ✅ Generate markdown and JSON files
- ✅ Organize output by timestamp
- ✅ Include diff summaries

**Integration**:
- Used in `SisyphusWorker` (lines 224, 619-630)
- Already checkpoint-aware

#### 4. WorkflowMemoryStore (`app/models/workflow_memory_store.rb`) ✅
**Status**: IMPLEMENTED

**Current Capabilities**:
- ✅ Record state transitions
- ✅ Record decisions with context
- ✅ Record errors
- ✅ Record outputs
- ✅ Query parent memory
- ✅ Persistence to JSON

**Missing**:
- No explicit checkpoint tracking
- No rollback history

---

## Project Plan Assessment

### Milestone 1 - Core Git Services

#### 1.1 - GitCheckpointManager
**Verdict**: ⚠️ PARTIALLY REDUNDANT

**Overlap with CheckpointService**:
- `create_checkpoint` → Already exists ✅
- `list_checkpoints` → Already exists ✅
- `get_checkpoint` → Already exists ✅
- `checkpoint_exists?` → Already implemented as `validate_checkpoint` ✅

**What's Missing**:
- More structured return types (currently returns hashes)
- Better message formatting
- Registry integration

**Recommendation**: **ENHANCE** existing `CheckpointService` instead of creating new service

---

#### 1.2 - GitDiffGenerator
**Verdict**: ✅ MOSTLY REDUNDANT

**Overlap with DiffGenerationService**:
- Diff generation → Already exists ✅
- Diff statistics → Already exists ✅
- Multiple formats → Already exists ✅

**What's Missing**:
- `FileDiff` domain object for structured diffs
- Git-specific diff parsing (currently uses custom algorithm)

**Recommendation**: **EXTEND** `DiffGenerationService` to add git diff parsing and `FileDiff` objects

---

#### 1.3 - GitRollbackService
**Verdict**: ✅ NEW FUNCTIONALITY REQUIRED

**Current State**: Not implemented

**Plan Requirements**:
- Rollback to checkpoint (git reset)
- Backup before rollback
- Validation of clean working directory
- Multiple strategies (hard/soft/mixed)

**Recommendation**: **CREATE** as new service - this is genuinely new functionality

---

### Milestone 2 - Checkpoint Domain Models

#### 2.1 - Checkpoint Class
**Verdict**: ✅ VALUABLE ADDITION

**Current State**: `CheckpointService` returns raw hashes

**Benefits**:
- Type safety
- Encapsulated behavior
- Better OOP compliance
- Easier testing

**Recommendation**: **CREATE** - This converts hash-based returns to proper domain objects

---

#### 2.2 - CheckpointRegistry Class
**Verdict**: ✅ VALUABLE ADDITION

**Current State**: Checkpoints stored as array of strings in `ExecutionRecord`

**Benefits**:
- Session-scoped checkpoint management
- Query by milestone/metadata
- Better organization

**Recommendation**: **CREATE** - Integrates naturally with `WorkflowMemoryStore`

---

#### 2.3 - FileDiff Class
**Verdict**: ✅ VALUABLE ADDITION

**Current State**: Diffs returned as strings

**Benefits**:
- Structured diff information
- Per-file change tracking
- Better frontend consumption

**Recommendation**: **CREATE** - Complements `DiffGenerationService`

---

### Milestone 3 - Workflow Integration

#### 3.1 - Checkpointable Concern
**Verdict**: ⚠️ NEEDS MODIFICATION

**Issue**: The plan proposes a concern, but `BaseWorker` already has checkpoint integration

**Current Integration** (SisyphusWorker):
```ruby
# Line 256-263: Already has checkpoint service initialization
def initialize_checkpoint_service
  return nil unless File.directory?(File.join(@path, ".git"))
  CheckpointService.new(path: @path)
end

# Line 524-543: Initial checkpoint creation
def create_initial_checkpoint
  checkpoint_id = @checkpoint_service.create_checkpoint(...)
  @execution_record.add_checkpoint(checkpoint_id)
end

# Line 545-585: Milestone checkpoint creation
def create_milestone_checkpoint(milestone)
  checkpoint_id = @checkpoint_service.create_checkpoint(...)
  @execution_record.add_checkpoint(checkpoint_id)
end
```

**Recommendation**: **SKIP** concern, enhance existing `BaseWorker` integration instead

---

#### 3.2 - CheckpointPolicy
**Verdict**: ✅ VALUABLE ADDITION

**Current State**: Hardcoded checkpoint triggers in `SisyphusWorker`

**Benefits**:
- Configurable triggers
- Reusable across workers
- Testable policy logic

**Recommendation**: **CREATE** - Good abstraction for checkpoint rules

---

#### 3.3 - Integrate with BaseWorker
**Verdict**: ✅ PARTIALLY DONE

**Current State**: 
- `SisyphusWorker` has checkpoint integration
- `DaedalusWorker` does not have checkpoints (planning only, no file changes)

**Recommendation**: **ENHANCE** `BaseWorker` with optional checkpoint support

---

### Milestone 4 - Frontend Integration

#### 4.1 - Checkpoint API Endpoint
**Verdict**: ✅ NEW FUNCTIONALITY

**Recommendation**: **CREATE** - Needed for frontend visualization

---

#### 4.2 - Integration Testing
**Verdict**: ✅ REQUIRED

**Current State**: `CheckpointService` has unit tests, no integration tests

**Recommendation**: **CREATE** comprehensive integration tests

---

### Milestone 5 - Advanced Features

**Verdict**: ⏸️ DEFER TO V2

All advanced features (tags, branches, comparison views, cleanup) should be deferred until core system is proven.

---

## OOP Pattern Compliance Review

### ✅ Services Follow OOP Patterns Correctly

#### CheckpointService
```ruby
# ✅ GOOD: Proper initialization with validation
def initialize(path:, **options)
  @path = File.expand_path(path)
  @options = DEFAULT_OPTIONS.merge(options)
  validate_git_repository!
end

# ✅ GOOD: Clear parameter requirements
def create_checkpoint(message, milestone_id: nil, step_ids: nil, ...)
  raise ArgumentError, "message must be a String" unless message.is_a?(String)
  # ...
end

# ✅ GOOD: Returns consistent hash structure
def get_checkpoint(checkpoint_id)
  {
    id: hash,
    message: message,
    timestamp: Time.at(timestamp.to_i),
    files_changed: files_changed,
    metadata: metadata
  }
end
```

**Complies With**:
- Lesson 1: Clear initialization with validation ✅
- Lesson 2: Strict type validation ✅
- Lesson 8: Symbol keys in hashes ✅

---

#### DiffGenerationService
```ruby
# ✅ GOOD: Stateless service
def initialize
  # No instance variables needed
end

# ✅ GOOD: Clear parameter validation
def generate_diff(file_path:, old_content:, new_content:, context_lines: DEFAULT_CONTEXT_LINES)
  validate_diff_params!(file_path, old_content, new_content)
  # ...
end

# ✅ GOOD: Type checking with clear errors
def generate_workspace_diff(change_set)
  raise ArgumentError, "change_set is required" if change_set.nil?
  raise TypeError, "change_set must be an Execution::ChangeSet, got #{change_set.class}" unless change_set.is_a?(Execution::ChangeSet)
end
```

**Complies With**:
- Lesson 2: Strict type validation ✅
- Lesson 3: Descriptive error messages ✅
- Stateless service pattern ✅

---

#### ExecutionOutputService
```ruby
# ✅ GOOD: Options with defaults
def initialize(base_path: nil, **options)
  @base_path = base_path || File.join(Rails.root, DEFAULT_BASE_PATH)
  @options = DEFAULT_OPTIONS.merge(options)
end

# ✅ GOOD: Validation at entry point
def write_execution_output(execution_record, plan_name: nil, ...)
  validate_params!(execution_record)
  # ...
end

# ✅ GOOD: Type checking
def validate_params!(execution_record)
  raise ArgumentError, "execution_record is required" if execution_record.nil?
  raise TypeError, "execution_record must be an Execution::ExecutionRecord, got #{execution_record.class}" unless execution_record.is_a?(Execution::ExecutionRecord)
end
```

**Complies With**:
- Lesson 1: Default options pattern ✅
- Lesson 2: Type validation ✅
- Lesson 3: Clear error messages ✅

---

### ❌ Areas Needing Improvement

#### 1. CheckpointService Returns Hashes Instead of Objects
```ruby
# ❌ BAD: Returns hash instead of domain object
def get_checkpoint(checkpoint_id)
  {
    id: hash,
    message: message,
    timestamp: Time.at(timestamp.to_i),
    files_changed: files_changed,
    metadata: metadata
  }
end
```

**Should Be**:
```ruby
# ✅ GOOD: Returns proper domain object
def get_checkpoint(checkpoint_id)
  Checkpoint.new(
    id: hash,
    message: message,
    timestamp: Time.at(timestamp.to_i),
    files_changed: files_changed,
    metadata: metadata
  )
end
```

**Violates**: Lesson 1 (No Hash-Based State) ❌

---

#### 2. DiffGenerationService Returns Strings Instead of Objects
```ruby
# ❌ BAD: Returns plain string
def generate_diff(file_path:, old_content:, new_content:, ...)
  # Returns string like:
  # "--- a/file.rb\n+++ b/file.rb\n..."
end
```

**Should Be**:
```ruby
# ✅ GOOD: Returns structured object
def generate_diff(file_path:, old_content:, new_content:, ...)
  FileDiff.new(
    file_path: file_path,
    change_type: :modified,
    insertions: 5,
    deletions: 3,
    diff_content: "--- a/file.rb\n+++ b/file.rb\n...",
    is_binary: false
  )
end
```

**Violates**: Lesson 1 (No Hash-Based State) - Should use objects ❌

---

### ✅ Tools Follow OOP Patterns Correctly

#### BashTool
```ruby
# ✅ GOOD: Inherits from BaseTool
class BashTool < BaseTool
  # ✅ GOOD: Class methods for schema
  def self.name_identifier
    "bash"
  end

  def self.description
    "Execute a bash command and return the output"
  end

  # ✅ GOOD: Clear parameter schema
  def self.parameters_schema
    {
      type: "object",
      properties: {
        command: { type: "string", description: "The bash command to execute" }
      },
      required: ["command"]
    }
  end

  # ✅ GOOD: Structured return with helper methods
  def execute(command:)
    if status.success?
      success_result(stdout).merge(exit_status: status.exitstatus)
    else
      error_result(stderr)
    end
  end
end

# ✅ GOOD: Self-registration
ToolCallService.register_tool(BashTool)
```

**Complies With**:
- Lesson 4: Inheritance pattern ✅
- Lesson 2: Clear interface ✅
- Tool registration pattern ✅

---

### ✅ Workers Follow OOP Patterns Correctly

#### SisyphusWorker
```ruby
# ✅ GOOD: Inherits from BaseWorker
class SisyphusWorker < BaseWorker
  # ✅ GOOD: Explicit state machine definition
  initial_state :pending
  state :running, description: "Initializing execution"
  transition from: :pending, to: :running, on: :start

  # ✅ GOOD: Strong initialization validation
  def initialize(execution_plan:, path:, context: {}, config: {})
    unless execution_plan.is_a?(Planning::Result)
      raise TypeError, "execution_plan must be a Planning::Result, got #{execution_plan.class}"
    end
    # ...
  end

  # ✅ GOOD: Follows Lesson 6 (State Machine Completion)
  def execute
    trigger(:start)
    initialize_execution
    trigger(:initialized)
    execute_all_milestones
    
    result = build_result
    trigger(:finish)  # Complete state machine
    
    # Update metadata AFTER final transition
    result[:metadata][:final_state] = current_state
    result
  end
end
```

**Complies With**:
- Lesson 4: Inheritance ✅
- Lesson 6: State machine completion ✅
- Lesson 2: Type validation ✅

---

#### DaedalusWorker
```ruby
# ✅ GOOD: Follows same patterns as SisyphusWorker
class DaedalusWorker < BaseWorker
  # ✅ GOOD: Validation in constructor
  def initialize(goal:, path:, context: {}, **options)
    validate_init_params!(goal, path)
    super(goal: goal, path: path, context: context, **options)
  end

  # ✅ GOOD: State machine completion
  def execute
    trigger(:start)
    initialize_worker
    trigger(:initialized)
    run_analysis
    trigger(:analyzed)
    run_planning
    trigger(:planned)
    write_output_files
    trigger(:finish)  # Complete transition
    
    build_result
  end
end
```

**Complies With**:
- Lesson 6: State machine completion ✅
- Clean workflow orchestration ✅

---

## Memory Integration Analysis

### Current State

#### SisyphusWorker Memory Usage
```ruby
# Line 218-233: Creates WorkflowMemoryStore
def initialize_execution
  @memory_store = create_memory_store  # WorkflowMemoryStore
  @execution_record = Execution::ExecutionRecord.new(...)
  
  record_decision(
    decision: "initialize_execution",
    reasoning: "Starting execution...",
    evidence: { checkpoint_service_available: @checkpoint_service.present? }
  )
end

# Line 533: Records checkpoint in ExecutionRecord
def create_initial_checkpoint
  checkpoint_id = @checkpoint_service.create_checkpoint(...)
  @execution_record.add_checkpoint(checkpoint_id)  # ← Stored here
  
  record_decision(
    decision: "initial_checkpoint_created",
    reasoning: "Created initial checkpoint...",
    evidence: { checkpoint_id: checkpoint_id }
  )
end
```

**Issue**: Checkpoints stored in two places:
1. `@execution_record.checkpoint_ids` (array of strings)
2. `@memory_store` (as decisions)

**Not Stored**: Checkpoint metadata, relationships, or structured information

---

### Recommended Integration

#### Add Checkpoint Section to WorkflowMemoryStore
```ruby
# app/models/workflow_memory_store.rb
DEFAULT_SECTIONS = {
  state_transitions: [],
  workflow_context: [],
  decisions: [],
  errors: [],
  outputs: [],
  checkpoints: []  # ← NEW: Track checkpoints with metadata
}.freeze

# Record checkpoint creation with full context
def record_checkpoint(checkpoint)
  entry = {
    checkpoint_id: checkpoint.id,
    message: checkpoint.message,
    milestone_id: checkpoint.metadata[:milestone_id],
    step_ids: checkpoint.metadata[:step_ids],
    created_at: checkpoint.created_at,
    files_changed: checkpoint.files_changed,
    state: current_state,
    timestamp: Time.now.utc.iso8601
  }
  @sections[:checkpoints] << entry
  save!
  entry
end

# Query checkpoints by milestone
def checkpoints_for_milestone(milestone_id)
  @sections[:checkpoints].select { |cp| cp[:milestone_id] == milestone_id }
end

# Get latest checkpoint
def latest_checkpoint
  @sections[:checkpoints].last
end
```

**Benefits**:
- Centralized checkpoint tracking
- Rich metadata queries
- Memory persistence
- Timeline reconstruction

---

## Revised Implementation Plan

### Phase 1: Domain Objects (High Priority)

**Goal**: Replace hash returns with proper domain objects

#### 1.1 Create Checkpoint Class
```ruby
# app/models/checkpoint.rb
class Checkpoint
  attr_reader :id, :message, :created_at, :metadata, :files_changed, :author

  def initialize(id:, message:, created_at:, metadata: {}, files_changed: [], author: nil)
    validate_params!(id, message, created_at)
    
    @id = id
    @message = message
    @created_at = created_at
    @metadata = metadata
    @files_changed = files_changed
    @author = author
  end

  def short_id
    id[0..6]
  end

  def age
    Time.now.utc - created_at
  end

  def file_count
    files_changed.size
  end

  def milestone_id
    metadata[:milestone_id]
  end

  def step_ids
    metadata[:step_ids] || []
  end

  def to_h
    {
      id: id,
      message: message,
      created_at: created_at,
      metadata: metadata,
      files_changed: files_changed,
      author: author
    }
  end

  def self.from_hash(hash)
    new(
      id: hash[:id],
      message: hash[:message],
      created_at: Time.parse(hash[:created_at]),
      metadata: hash[:metadata] || {},
      files_changed: hash[:files_changed] || [],
      author: hash[:author]
    )
  end

  private

  def validate_params!(id, message, created_at)
    raise ArgumentError, "id must be a non-empty String" unless id.is_a?(String) && !id.empty?
    raise ArgumentError, "message must be a String" unless message.is_a?(String)
    raise ArgumentError, "created_at must be a Time" unless created_at.is_a?(Time)
  end
end
```

**Test Coverage**:
- Initialization validation
- Attribute accessors
- Helper methods (short_id, age, file_count)
- Metadata accessors (milestone_id, step_ids)
- Serialization (to_h, from_hash)

---

#### 1.2 Create FileDiff Class
```ruby
# app/models/file_diff.rb
class FileDiff
  CHANGE_TYPES = [
    ADDED = :added,
    MODIFIED = :modified,
    DELETED = :deleted
  ].freeze

  attr_reader :file_path, :change_type, :insertions, :deletions, :diff_content, :is_binary

  def initialize(file_path:, change_type:, insertions: 0, deletions: 0, diff_content: nil, is_binary: false)
    validate_params!(file_path, change_type)
    
    @file_path = file_path
    @change_type = change_type
    @insertions = insertions
    @deletions = deletions
    @diff_content = diff_content
    @is_binary = is_binary
  end

  def changed?
    insertions > 0 || deletions > 0
  end

  def lines_changed
    insertions + deletions
  end

  def change_summary
    return "Binary file" if is_binary
    "+#{insertions} -#{deletions}"
  end

  def to_h
    {
      file_path: file_path,
      change_type: change_type,
      insertions: insertions,
      deletions: deletions,
      diff_content: diff_content,
      is_binary: is_binary
    }
  end

  def self.from_git_diff(diff_output)
    # Parse git diff output format
    # Extract file path, change type, stats
    # Return FileDiff instance
  end

  private

  def validate_params!(file_path, change_type)
    raise ArgumentError, "file_path must be a non-empty String" unless file_path.is_a?(String) && !file_path.empty?
    raise ArgumentError, "change_type must be one of: #{CHANGE_TYPES.join(', ')}" unless CHANGE_TYPES.include?(change_type)
  end
end
```

**Test Coverage**:
- Initialization validation
- Change type validation
- Helper methods (changed?, lines_changed, change_summary)
- Binary file handling
- Git diff parsing
- Serialization

---

#### 1.3 Create CheckpointRegistry Class
```ruby
# app/models/checkpoint_registry.rb
class CheckpointRegistry
  attr_reader :owner_id, :checkpoints, :created_at

  def initialize(owner_id:)
    validate_owner_id!(owner_id)
    
    @owner_id = owner_id
    @checkpoints = []
    @checkpoint_map = {}
    @created_at = Time.now.utc
  end

  def add(checkpoint)
    validate_checkpoint!(checkpoint)
    
    @checkpoints << checkpoint
    @checkpoint_map[checkpoint.id] = checkpoint
    checkpoint
  end

  def find(checkpoint_id)
    @checkpoint_map[checkpoint_id]
  end

  def latest
    @checkpoints.last
  end

  def for_milestone(milestone_id)
    @checkpoints.select { |cp| cp.milestone_id == milestone_id }
  end

  def count
    @checkpoints.size
  end

  def to_h
    {
      owner_id: owner_id,
      checkpoints: @checkpoints.map(&:to_h),
      created_at: @created_at.iso8601
    }
  end

  def self.from_hash(hash)
    registry = allocate
    registry.instance_variable_set(:@owner_id, hash[:owner_id])
    registry.instance_variable_set(:@created_at, Time.parse(hash[:created_at]))
    
    checkpoints = hash[:checkpoints].map { |cp_hash| Checkpoint.from_hash(cp_hash) }
    registry.instance_variable_set(:@checkpoints, checkpoints)
    registry.instance_variable_set(:@checkpoint_map, build_map(checkpoints))
    
    registry
  end

  private

  def validate_owner_id!(owner_id)
    raise ArgumentError, "owner_id must be a non-empty String" unless owner_id.is_a?(String) && !owner_id.empty?
  end

  def validate_checkpoint!(checkpoint)
    raise TypeError, "checkpoint must be a Checkpoint, got #{checkpoint.class}" unless checkpoint.is_a?(Checkpoint)
  end

  def self.build_map(checkpoints)
    checkpoints.each_with_object({}) { |cp, map| map[cp.id] = cp }
  end
end
```

**Test Coverage**:
- Initialization validation
- Add checkpoint (with type checking)
- Find by ID
- Latest checkpoint
- Filter by milestone
- Count
- Serialization (to_h, from_hash)

---

### Phase 2: Enhance Existing Services

#### 2.1 Update CheckpointService to Return Domain Objects
```ruby
# app/services/checkpoint_service.rb

# Change return type
def create_checkpoint(message, **metadata_params)
  # ... existing code ...
  
  # Build Checkpoint object instead of returning string
  Checkpoint.new(
    id: checkpoint_id,
    message: full_message,
    created_at: Time.now.utc,
    metadata: build_metadata(**metadata_params),
    files_changed: get_files_changed(checkpoint_id)
  )
end

def get_checkpoint(checkpoint_id)
  return nil unless validate_checkpoint(checkpoint_id)
  
  # ... existing parsing code ...
  
  # Return Checkpoint object instead of hash
  Checkpoint.new(
    id: hash,
    message: message,
    created_at: Time.at(timestamp.to_i),
    metadata: checkpoint_metadata(checkpoint_id),
    files_changed: files_changed
  )
end

def list_checkpoints(limit: 20)
  # ... existing code ...
  
  # Return array of Checkpoint objects
  result[:output].split("\n").map do |line|
    hash, message, timestamp = line.split("|", 3)
    Checkpoint.new(
      id: hash,
      message: message,
      created_at: Time.at(timestamp.to_i),
      metadata: checkpoint_metadata(hash)
    )
  end
end

private

def get_files_changed(checkpoint_id)
  result = run_git_command("show --name-only --pretty=format:'' #{checkpoint_id}")
  result[:output].split("\n").reject(&:empty?)
end
```

**Benefits**:
- Type safety
- Cleaner API
- Better testing
- OOP compliance ✅

**Tests to Update**:
- All tests expecting hashes must expect Checkpoint objects
- Add tests for Checkpoint attributes
- Test error handling

---

#### 2.2 Update DiffGenerationService to Return FileDiff Objects
```ruby
# app/services/diff_generation_service.rb

def generate_diff(file_path:, old_content:, new_content:, context_lines: DEFAULT_CONTEXT_LINES)
  validate_diff_params!(file_path, old_content, new_content)

  # Handle binary files
  if binary_content?(old_content) || binary_content?(new_content)
    return FileDiff.new(
      file_path: file_path,
      change_type: determine_change_type(old_content, new_content),
      is_binary: true
    )
  end

  # Determine change type
  change_type = if new_content.nil?
    FileDiff::DELETED
  elsif old_content.nil? || old_content.empty?
    FileDiff::ADDED
  else
    FileDiff::MODIFIED
  end

  # Generate diff content
  diff_content = case change_type
  when FileDiff::DELETED
    generate_deletion_diff(file_path, old_content)
  when FileDiff::ADDED
    generate_creation_diff(file_path, new_content)
  else
    generate_modification_diff(file_path, old_content, new_content, context_lines)
  end

  # Calculate stats
  stats = calculate_stats(diff_content)

  FileDiff.new(
    file_path: file_path,
    change_type: change_type,
    insertions: stats[:insertions],
    deletions: stats[:deletions],
    diff_content: diff_content
  )
end

# Keep string version for backward compatibility
def generate_diff_string(file_path:, old_content:, new_content:, context_lines: DEFAULT_CONTEXT_LINES)
  file_diff = generate_diff(
    file_path: file_path,
    old_content: old_content,
    new_content: new_content,
    context_lines: context_lines
  )
  file_diff.diff_content
end

private

def calculate_stats(diff_content)
  lines = diff_content.split("\n")
  {
    insertions: lines.count { |l| l.start_with?("+") && !l.start_with?("+++") },
    deletions: lines.count { |l| l.start_with?("-") && !l.start_with?("---") }
  }
end
```

**Benefits**:
- Structured diff information
- Better frontend consumption
- OOP compliance ✅

---

### Phase 3: Enhance Memory Integration

#### 3.1 Add Checkpoint Section to WorkflowMemoryStore
```ruby
# app/models/workflow_memory_store.rb

DEFAULT_SECTIONS = {
  state_transitions: [],
  workflow_context: [],
  decisions: [],
  errors: [],
  outputs: [],
  checkpoints: []  # ← NEW
}.freeze

# Record checkpoint creation
def record_checkpoint(checkpoint)
  raise TypeError, "checkpoint must be a Checkpoint" unless checkpoint.is_a?(Checkpoint)
  
  entry = {
    checkpoint_id: checkpoint.id,
    short_id: checkpoint.short_id,
    message: checkpoint.message,
    milestone_id: checkpoint.milestone_id,
    step_ids: checkpoint.step_ids,
    files_changed: checkpoint.files_changed,
    file_count: checkpoint.file_count,
    created_at: checkpoint.created_at.iso8601,
    state: current_state,
    timestamp: Time.now.utc.iso8601
  }
  @sections[:checkpoints] << entry
  save!
  entry
end

# Query checkpoints
def checkpoints_for_milestone(milestone_id)
  @sections[:checkpoints].select { |cp| cp[:milestone_id] == milestone_id }
end

def latest_checkpoint
  @sections[:checkpoints].last
end

def checkpoint_count
  @sections[:checkpoints].size
end

def get_checkpoint(checkpoint_id)
  @sections[:checkpoints].find { |cp| cp[:checkpoint_id] == checkpoint_id }
end
```

**Update `summarize` method**:
```ruby
def summarize
  transitions = @sections[:state_transitions]
  checkpoints = @sections[:checkpoints]
  
  {
    workflow_name: workflow_name,
    workflow_id: workflow_id,
    owner_id: owner_id,
    started_at: @started_at.iso8601,
    current_state: current_state,
    transition_count: transitions.size,
    decision_count: @sections[:decisions].size,
    error_count: @sections[:errors].size,
    checkpoint_count: checkpoints.size,  # ← NEW
    states_visited: transitions.map { |t| t[:to] }.uniq,
    total_duration: Time.now.utc - @started_at
  }
end
```

---

#### 3.2 Update SisyphusWorker to Use Enhanced Memory
```ruby
# app/workers/sisyphus_worker.rb

def create_initial_checkpoint
  return unless checkpoint_service_available?
  
  # Create checkpoint returns Checkpoint object now
  checkpoint = @checkpoint_service.create_checkpoint(
    "Execution start: #{@execution_plan.goal}",
    execution_id: @owner_id,
    milestone_id: "initial"
  )
  
  # Store in both places
  @execution_record.add_checkpoint(checkpoint.id)
  @memory_store.record_checkpoint(checkpoint)  # ← NEW: Store in memory
  
  record_decision(
    decision: "initial_checkpoint_created",
    reasoning: "Created initial checkpoint before execution",
    evidence: {
      checkpoint_id: checkpoint.id,
      short_id: checkpoint.short_id,
      files_changed: checkpoint.file_count
    }
  )
end

def create_milestone_checkpoint(milestone)
  return unless checkpoint_service_available?
  
  trigger(:checkpoint)
  
  checkpoint = @checkpoint_service.create_checkpoint(
    "#{milestone.title} - Complete",
    milestone_id: milestone.number.to_s,
    execution_id: @owner_id,
    step_ids: milestone.steps.map(&:number)
  )
  
  @execution_record.add_checkpoint(checkpoint.id)
  @memory_store.record_checkpoint(checkpoint)  # ← NEW
  
  emit_progress(:checkpoint_created, {
    milestone_number: milestone.number,
    checkpoint_id: checkpoint.id,
    short_id: checkpoint.short_id
  })
  
  record_decision(
    decision: "milestone_checkpoint_created",
    reasoning: "Created checkpoint for milestone: #{milestone.title}",
    evidence: {
      milestone_number: milestone.number,
      checkpoint_id: checkpoint.id,
      short_id: checkpoint.short_id,
      steps_completed: milestone.step_count,
      files_changed: checkpoint.file_count
    }
  )
  
  trigger(:next_milestone)
rescue StandardError => e
  Rails.logger.error "[SisyphusWorker] Failed to create milestone checkpoint: #{e.message}"
  
  record_decision(
    decision: "checkpoint_failed",
    reasoning: "Failed to create checkpoint: #{e.message}",
    evidence: { milestone_number: milestone.number, error: e.message }
  )
end
```

**Benefits**:
- Centralized checkpoint tracking
- Rich queries by milestone
- Memory persistence
- Timeline reconstruction

---

### Phase 4: Create Rollback Service

#### 4.1 Create GitRollbackService
```ruby
# app/services/git_rollback_service.rb

class GitRollbackService
  STRATEGIES = [
    HARD = :hard,
    SOFT = :soft,
    MIXED = :mixed
  ].freeze

  attr_reader :path, :checkpoint_service

  def initialize(path:)
    @path = File.expand_path(path)
    @checkpoint_service = CheckpointService.new(path: path)
    validate_git_repository!
  end

  # Rollback to a checkpoint
  # @param checkpoint [Checkpoint, String] Checkpoint object or ID
  # @param strategy [Symbol] Rollback strategy (:hard, :soft, :mixed)
  # @param create_backup [Boolean] Whether to create backup before rollback
  # @return [Boolean] Success
  def rollback_to(checkpoint, strategy: HARD, create_backup: true)
    checkpoint_id = extract_checkpoint_id(checkpoint)
    validate_rollback!(checkpoint_id, strategy)
    
    # Create backup
    backup_checkpoint = create_backup_checkpoint if create_backup
    
    # Perform rollback
    result = execute_rollback(checkpoint_id, strategy)
    
    if result[:success]
      Rails.logger.info "[GitRollbackService] Rolled back to #{checkpoint_id} (strategy: #{strategy})"
      Rails.logger.info "[GitRollbackService] Backup checkpoint: #{backup_checkpoint.id}" if backup_checkpoint
      true
    else
      Rails.logger.error "[GitRollbackService] Rollback failed: #{result[:error]}"
      false
    end
  rescue StandardError => e
    Rails.logger.error "[GitRollbackService] Rollback error: #{e.message}"
    false
  end

  # Check if rollback is possible
  # @param checkpoint [Checkpoint, String] Checkpoint object or ID
  # @return [Boolean, Hash] true if can rollback, or hash with :can_rollback and :reason
  def can_rollback?(checkpoint)
    checkpoint_id = extract_checkpoint_id(checkpoint)
    
    # Check if checkpoint exists
    unless @checkpoint_service.validate_checkpoint(checkpoint_id)
      return { can_rollback: false, reason: "Checkpoint does not exist" }
    end
    
    # Check for uncommitted changes
    if has_uncommitted_changes?
      return { can_rollback: false, reason: "Uncommitted changes in working directory" }
    end
    
    { can_rollback: true }
  end

  # List rollback candidates (checkpoints that can be rolled back to)
  # @param from_checkpoint [Checkpoint, String, nil] Starting checkpoint (default: HEAD)
  # @return [Array<Checkpoint>] List of checkpoint objects
  def list_rollback_candidates(from_checkpoint = nil)
    from_id = from_checkpoint ? extract_checkpoint_id(from_checkpoint) : "HEAD"
    @checkpoint_service.list_checkpoints.select do |checkpoint|
      checkpoint_reachable_from?(checkpoint.id, from_id)
    end
  end

  # Create backup checkpoint before rollback
  # @return [Checkpoint] Backup checkpoint
  def create_backup_checkpoint
    @checkpoint_service.create_checkpoint(
      "Backup before rollback to #{Time.now.utc.iso8601}",
      backup: true,
      created_by: "GitRollbackService"
    )
  end

  private

  def validate_git_repository!
    unless File.directory?(File.join(@path, ".git"))
      raise ArgumentError, "Path #{@path} is not a git repository"
    end
  end

  def extract_checkpoint_id(checkpoint)
    case checkpoint
    when Checkpoint
      checkpoint.id
    when String
      checkpoint
    else
      raise TypeError, "checkpoint must be a Checkpoint or String, got #{checkpoint.class}"
    end
  end

  def validate_rollback!(checkpoint_id, strategy)
    raise ArgumentError, "checkpoint_id is required" if checkpoint_id.nil? || checkpoint_id.empty?
    
    unless STRATEGIES.include?(strategy)
      raise ArgumentError, "Invalid strategy: #{strategy}. Must be one of: #{STRATEGIES.join(', ')}"
    end
    
    unless @checkpoint_service.validate_checkpoint(checkpoint_id)
      raise ArgumentError, "Checkpoint does not exist: #{checkpoint_id}"
    end
    
    if has_uncommitted_changes?
      raise RuntimeError, "Cannot rollback with uncommitted changes. Commit or stash changes first."
    end
  end

  def has_uncommitted_changes?
    result = run_git_command("status --porcelain")
    result[:success] && !result[:output].strip.empty?
  end

  def execute_rollback(checkpoint_id, strategy)
    strategy_flag = case strategy
    when HARD then "--hard"
    when SOFT then "--soft"
    when MIXED then "--mixed"
    end
    
    result = run_git_command("reset #{strategy_flag} #{checkpoint_id}")
    
    {
      success: result[:success],
      error: result[:success] ? nil : result[:output]
    }
  end

  def checkpoint_reachable_from?(target_id, from_id)
    # Check if target_id is an ancestor of from_id
    result = run_git_command("merge-base --is-ancestor #{target_id} #{from_id}")
    result[:exit_status] == 0
  end

  def run_git_command(cmd)
    full_cmd = "cd #{@path} && git #{cmd}"
    stdout, stderr, status = Open3.capture3(full_cmd)
    
    {
      success: status.success?,
      output: status.success? ? stdout : stderr,
      exit_status: status.exitstatus
    }
  end
end
```

**Test Coverage**:
- Initialization validation
- Rollback with different strategies
- Backup creation
- can_rollback? validation
- Uncommitted changes detection
- List rollback candidates
- Error handling

---

### Phase 5: Create Checkpoint Policy

#### 5.1 Create CheckpointPolicy
```ruby
# app/services/checkpoint_policy.rb

class CheckpointPolicy
  TRIGGERS = [
    MILESTONE_START = :milestone_start,
    MILESTONE_END = :milestone_end,
    WORKFLOW_START = :workflow_start,
    WORKFLOW_END = :workflow_end,
    STEP_COMPLETE = :step_complete,
    ERROR = :error
  ].freeze

  DEFAULT_TRIGGERS = [MILESTONE_END, ERROR].freeze

  attr_reader :checkpoint_on

  def initialize(checkpoint_on: DEFAULT_TRIGGERS)
    @checkpoint_on = Array(checkpoint_on).map(&:to_sym) & TRIGGERS
    @checkpoint_on = DEFAULT_TRIGGERS if @checkpoint_on.empty?
  end

  # Determine if a checkpoint should be created
  # @param event [Symbol] Event that occurred
  # @param context [Hash] Context about the event
  # @return [Boolean] Whether to create checkpoint
  def should_checkpoint?(event, context = {})
    raise ArgumentError, "event is required" if event.nil?
    
    event_sym = event.to_sym
    return false unless TRIGGERS.include?(event_sym)
    
    @checkpoint_on.include?(event_sym)
  end

  # Generate checkpoint message for event
  # @param event [Symbol] Event that occurred
  # @param context [Hash] Context with worker_id, milestone_id, step_id, etc
  # @return [String] Checkpoint message
  def checkpoint_message_for(event, context = {})
    case event.to_sym
    when MILESTONE_START
      milestone_title = context[:milestone_title] || "Milestone #{context[:milestone_id]}"
      "Starting: #{milestone_title}"
      
    when MILESTONE_END
      milestone_title = context[:milestone_title] || "Milestone #{context[:milestone_id]}"
      "Completed: #{milestone_title}"
      
    when WORKFLOW_START
      workflow_name = context[:workflow_name] || "Workflow"
      "#{workflow_name} started"
      
    when WORKFLOW_END
      workflow_name = context[:workflow_name] || "Workflow"
      "#{workflow_name} completed"
      
    when STEP_COMPLETE
      step_title = context[:step_title] || "Step #{context[:step_id]}"
      "Step complete: #{step_title}"
      
    when ERROR
      error_message = context[:error_message] || "Error occurred"
      "Error checkpoint: #{error_message}"
      
    else
      "Checkpoint: #{event}"
    end
  end

  # Get metadata for checkpoint based on context
  # @param context [Hash] Context with worker_id, milestone_id, etc
  # @return [Hash] Metadata for checkpoint
  def checkpoint_metadata(context = {})
    metadata = {}
    metadata[:worker_id] = context[:worker_id] if context[:worker_id]
    metadata[:milestone_id] = context[:milestone_id] if context[:milestone_id]
    metadata[:step_id] = context[:step_id] if context[:step_id]
    metadata[:step_ids] = context[:step_ids] if context[:step_ids]
    metadata[:execution_id] = context[:execution_id] if context[:execution_id]
    metadata[:error_message] = context[:error_message] if context[:error_message]
    metadata
  end

  def to_h
    {
      checkpoint_on: @checkpoint_on
    }
  end
end
```

**Test Coverage**:
- Initialization with custom triggers
- Default triggers
- should_checkpoint? logic for each trigger
- checkpoint_message_for generates appropriate messages
- checkpoint_metadata extracts relevant context
- Invalid trigger handling

---

### Phase 6: API Endpoints

#### 6.1 Create Checkpoints Controller
```ruby
# app/controllers/api/v1/checkpoints_controller.rb

module Api
  module V1
    class CheckpointsController < ApplicationController
      before_action :set_checkpoint_service
      before_action :set_checkpoint, only: [:show, :diff, :rollback]

      # GET /api/v1/checkpoints
      def index
        limit = params[:limit]&.to_i || 50
        checkpoints = @checkpoint_service.list_checkpoints(limit: limit)
        
        render json: { checkpoints: checkpoints.map(&:to_h) }
      end

      # GET /api/v1/checkpoints/:id
      def show
        render json: { checkpoint: @checkpoint.to_h }
      end

      # GET /api/v1/checkpoints/:id/diff
      def diff
        other_id = params[:other_checkpoint_id]
        diff = if other_id
          @checkpoint_service.diff_checkpoint(@checkpoint.id, other_id)
        else
          @checkpoint_service.diff_since_checkpoint(@checkpoint.id)
        end
        
        render json: {
          checkpoint_id: @checkpoint.id,
          other_checkpoint_id: other_id,
          diff: diff
        }
      end

      # POST /api/v1/checkpoints/:id/rollback
      def rollback
        strategy = params[:strategy]&.to_sym || :hard
        create_backup = params[:create_backup] != "false"
        
        rollback_service = GitRollbackService.new(path: checkpoint_path)
        
        # Check if can rollback
        can_rollback_result = rollback_service.can_rollback?(@checkpoint)
        unless can_rollback_result[:can_rollback]
          render json: {
            success: false,
            error: can_rollback_result[:reason]
          }, status: :unprocessable_entity
          return
        end
        
        # Perform rollback
        success = rollback_service.rollback_to(@checkpoint, strategy: strategy, create_backup: create_backup)
        
        if success
          render json: {
            success: true,
            checkpoint_id: @checkpoint.id,
            strategy: strategy
          }
        else
          render json: {
            success: false,
            error: "Rollback failed"
          }, status: :internal_server_error
        end
      end

      private

      def set_checkpoint_service
        @checkpoint_service = CheckpointService.new(path: checkpoint_path)
      rescue ArgumentError => e
        render json: { error: e.message }, status: :bad_request
      end

      def set_checkpoint
        checkpoint_id = params[:id]
        @checkpoint = @checkpoint_service.get_checkpoint(checkpoint_id)
        
        unless @checkpoint
          render json: { error: "Checkpoint not found" }, status: :not_found
        end
      end

      def checkpoint_path
        # Default to current project root
        # In production, this might come from session/auth
        Rails.root.to_s
      end
    end
  end
end
```

**Routes**:
```ruby
# config/routes.rb

namespace :api do
  namespace :v1 do
    resources :checkpoints, only: [:index, :show] do
      member do
        get :diff
        post :rollback
      end
    end
  end
end
```

**Test Coverage**:
- GET /checkpoints returns list
- GET /checkpoints/:id returns checkpoint details
- GET /checkpoints/:id/diff returns diff
- POST /checkpoints/:id/rollback performs rollback
- Error handling for invalid IDs
- Error handling for rollback failures

---

## Summary of Changes

### ✅ Phase 1: Domain Objects (Required)
- **CREATE**: `Checkpoint` class
- **CREATE**: `FileDiff` class
- **CREATE**: `CheckpointRegistry` class
- **Tests**: Full test coverage for all domain objects

### ✅ Phase 2: Enhance Existing Services (Required)
- **UPDATE**: `CheckpointService` to return `Checkpoint` objects
- **UPDATE**: `DiffGenerationService` to return `FileDiff` objects
- **UPDATE**: All tests to expect domain objects instead of hashes
- **Maintain**: Backward compatibility with string methods where needed

### ✅ Phase 3: Memory Integration (Required)
- **UPDATE**: `WorkflowMemoryStore` to add `checkpoints` section
- **UPDATE**: `SisyphusWorker` to record checkpoints in memory
- **Benefits**: Rich queries, timeline reconstruction, persistence

### ✅ Phase 4: Rollback Service (Required)
- **CREATE**: `GitRollbackService`
- **Features**: Multiple strategies, backup creation, validation
- **Tests**: Full test coverage

### ✅ Phase 5: Checkpoint Policy (Recommended)
- **CREATE**: `CheckpointPolicy`
- **Benefits**: Configurable triggers, reusable logic
- **Tests**: Full test coverage

### ✅ Phase 6: API Endpoints (Recommended)
- **CREATE**: `Api::V1::CheckpointsController`
- **Routes**: RESTful endpoints for frontend
- **Tests**: Full integration test coverage

### ❌ NOT NEEDED
- `GitCheckpointManager` - Redundant with `CheckpointService`
- `GitDiffGenerator` - Redundant with `DiffGenerationService`
- `Checkpointable` concern - Better to enhance `BaseWorker`

### ⏸️ DEFER TO V2
- Checkpoint tags and branches
- Checkpoint comparison views
- Checkpoint cleanup/garbage collection

---

## Conclusion

The Git Checkpoint System project plan is **well-conceived** but contains **significant overlap** with existing services. The revised implementation plan:

1. **Eliminates redundancy** by enhancing existing services
2. **Adds value** with proper domain objects
3. **Improves OOP compliance** by replacing hashes with classes
4. **Integrates naturally** with `WorkflowMemoryStore`
5. **Maintains consistency** with existing patterns

The checkpoint system should **grow organically** from what's already there rather than creating parallel infrastructure.


