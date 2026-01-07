---
description: Context objects and checkpoint system patterns
globs: app/contexts/**/*.rb
alwaysApply: false
---

# Context Objects & Checkpoint System

**Tags**: [architecture, design]  
**Applies To**: Any system with persistent state and versioning needs  
**Date**: 2026-01-05

## Overview

Context objects encapsulate execution environment and state for workflows and agents. Checkpoints track codebase versions through Git integration, enabling rollback and diff capabilities.

**When to use these patterns:**
- Agents need access to execution context
- Code modifications require version tracking
- Rollback capability is needed
- Historical state inspection is required

## Context & Checkpoint Patterns

```
Context Pattern (execution state container)
├── Abstract Base Context
│   ├── Common structure: entries collection, child contexts, metadata
│   ├── Common behavior: add entries, manage hierarchy, serialize
│   └── Hierarchical: Supports nested contexts for organization
│
├── Domain-Specific Context
│   ├── Extends: Base context
│   ├── Adds: Domain parameters (paths, goals, identifiers)
│   └── Validates: Domain constraints in constructor
│
└── Context Hierarchy
    ├── Root Context (main execution)
    │   ├── Research Context (findings)
    │   ├── Execution Context (operations)
    │   └── Error Context (issues)
    └── Serialization: Preserves entire hierarchy

Checkpoint Pattern (version tracking)
├── Singleton Tracker
│   ├── Coordinates: All checkpoint operations
│   ├── Thread-safe: Mutex for concurrent access
│   └── Per-path: Manages multiple repositories
│
├── Checkpoint Service (per VCS root)
│   ├── Detects: File changes automatically
│   ├── Creates: Version control commits
│   ├── Stores: Metadata with commits (git notes, tags, etc.)
│   └── Returns: Checkpoint identifier
│
└── Checkpoint Value Object
    ├── Identifier: VCS commit hash/reference
    ├── Message: Human-readable description
    ├── Timestamp: When created
    ├── Metadata: Execution context (task_id, agent_id, etc.)
    └── Files: List of changed files

Auto-Checkpoint Pattern
├── Detection
│   ├── Check for uncommitted changes
│   ├── Compare current state to last checkpoint
│   └── Trigger on: any file modifications
│
├── Creation
│   ├── Stage all changes
│   ├── Commit with descriptive message
│   ├── Attach metadata (via VCS mechanism)
│   └── Return checkpoint ID
│
└── Benefits
    ├── No manual checkpoint calls needed
    ├── Every modification is tracked
    └── Consistent checkpoint IDs

VCS Integration Pattern
├── Commits as Checkpoints
│   ├── Each checkpoint = VCS commit
│   ├── Commit hash = checkpoint ID
│   └── Portable across systems
│
├── Metadata Storage
│   ├── Git: Use git notes
│   ├── Mercurial: Use commit extras
│   └── SVN: Use properties
│
└── Benefits
    ├── No separate database needed
    ├── Metadata travels with commits
    └── Standard VCS tools work

Agent → Prompt → Tool Hierarchy
├── Agent (owns state machine & context)
│   ├── State Machine: :idle → :running → :complete/:failed
│   ├── Context: Execution environment
│   ├── Controls: Which prompts to use
│   └── Pattern:
│       class Agent
│         @id, @state, @context
│         execute() → delegates to prompt
│       end
│
├── Prompt (builds messages, manages tools)
│   ├── Receives: Context from agent
│   ├── Builds: LLM messages with context
│   ├── Manages: Tool registration & execution
│   └── Pattern:
│       class Prompt
│         @id, @tools, @context
│         execute() → calls LLM, executes tools
│       end
│
└── Tool (performs operations)
    ├── Receives: Parameters from LLM via prompt
    ├── Context injection: Prompt adds base_path, etc.
    ├── Executes: File operations, API calls, etc.
    └── Pattern:
        class Tool
          execute(param1:, param2:) → {result1:, result:2,}
        end

Context Passing Pattern
├── Explicit Parameter Injection
│   ├── Controller creates context
│   ├── Agent receives context
│   ├── Prompt receives context from agent
│   └── No global state
│
├── Validation at Boundaries
│   ├── Constructor validates type
│   ├── Methods validate context is correct type
│   └── Fail fast on type mismatches
│
└── Benefits
    ├── Clear dependencies
    ├── Easy testing
    └── No action-at-a-distance
```

---

## Rules

### [ARCH][!AGENT-STATE-MACHINE]

**Rule**: Every agent has @id = SecureRandom.uuid and a clean state machine (:idle → :running → :complete/:failed).

**Good Example:**

```ruby
# typed: strict
# ✅ Clean agent with state machine
class Agent
  extend T::Sig
  
  STATES = T.let([:idle, :running, :complete, :failed].freeze, T::Array[Symbol])
  
  sig { returns(String) }
  attr_reader :id
  
  sig { returns(Symbol) }
  attr_reader :state
  
  sig { returns(Context) }
  attr_reader :context
  
  sig { params(context: Context).void }
  def initialize(context:)
    @id = T.let(SecureRandom.uuid, String)
    @state = T.let(:idle, Symbol)
    @context = T.let(context, Context)
  end
  
  sig { returns(Result) }
  def execute
    transition_to(:running)
    
    prompt = ActionPrompt.new(context: @context)
    result = prompt.execute
    
    transition_to(:complete)
    result
  rescue => error
    transition_to(:failed)
    raise
  end
  
  sig { returns(T::Boolean) }
  def idle?
    @state == :idle
  end
  
  sig { returns(T::Boolean) }
  def running?
    @state == :running
  end
  
  sig { returns(T::Boolean) }
  def complete?
    @state == :complete
  end
  
  sig { returns(T::Boolean) }
  def failed?
    @state == :failed
  end
  
  private
  
  sig { params(new_state: Symbol).void }
  def transition_to(new_state)
    raise "Invalid state: #{new_state}" unless STATES.include?(new_state)
    @state = new_state
  end
end
```

**Why**: Deterministic state transitions, unique IDs for tracking after creation.

---

### [ARCH][!BASECONTEXT-PATTERN]

**Rule**: All context classes extend BaseContext for consistent interface and hierarchical support.

**Bad Example:**

```ruby
# ❌ Each context is its own island
class SisyphusContext 
  attr_accessor :codebase_path, :entries
  
  def initialize(codebase_path:)
    @id = SecureRandom.uuid
    @codebase_path = codebase_path
    @entries = []  # Different structure each time
  end
end

class DaedalusContext
  attr_accessor :session_id, :items  # Different naming!
  
  def initialize(session_id:)
    @id = SecureRandom.uuid
    @session_id = session_id
    @items = []
  end
end
```

**Good Example:**

```ruby
# typed: strict
# ✅ Base pattern defines common interface
class ExecutionContext
  extend T::Sig
  
  sig { returns(String) }
  attr_reader :id
  
  sig { returns(T::Array[ContextEntry]) }
  attr_reader :entries

  sig { void }
  def initialize
    @id = T.let(UUID.generate, UUID)
    @entries = T.let([], T::Array[ContextEntry])
    @metadata = T.let({}, T::Hash[Symbol, String])
  end

  sig { params(content: String, tags: T::Array[String]).void }
  def add_entry(content:, tags: [])
    entry = ContextEntry.new(content: content, tags: tags)
    @entries << entry
  end

end

# Subclasses add domain-specific fields
class TaskContext < ExecutionContext
  extend T::Sig
  
  sig { returns(String) }
  attr_reader :task_id
  
  sig { returns(String) }
  attr_reader :goal

  sig { params(task_id: UUID, goal: String).void }
  def initialize(task_id:, goal:)
    super()  # Gets @id from parent
    @task_id = T.let(task_id, UUID)
    @goal = T.let(goal, String)
  end

end
```

**Why**: Consistent interfaces enable polymorphic usage, common serialization, and hierarchical sub-contexts.

---

### [ARCH][!EXPLICIT-CONTEXT-PASSING]

**Rule**: Pass context objects explicitly as parameters, not implicit global state.

**Bad Example:**

```ruby
# ❌ Implicit global context
class GlobalContext
  @@current_context = nil
  
  def self.set(context)
    @@current_context = context
  end
  
  def self.get
    @@current_context
  end
end

class Agent
  def execute
    # Magic global access - where did this come from?
    context = GlobalContext.get
    context.add_entry(content: "Action complete", tags: ["execution"])
  end
end
```

**Good Example:**

```ruby
# ✅ Explicit parameter injection
class Agent
  def initialize(context:)
    @id = SecureRandom.uuid
    @context = context
    @state = :idle
  end
  
  def execute
    @state = :running
    @context.add_entry(content: "Action complete", tags: ["execution"])
    
    # Pass context to prompt
    prompt = ActionPrompt.new(context: @context)
    result = prompt.execute
    
    @state = :complete
    result
  end
end

# Usage - explicit everywhere
context = TaskContext.new(task_id: "task-123", goal: "Complete action")
agent = Agent.new(context: context)
agent.execute
```

**Why**: Explicit parameters make dependencies obvious, enable testing, and prevent action-at-a-distance bugs.

---

### [ARCH][!CHECKPOINT-AUTO-TRACKING]

**Rule**: CheckpointTracker automatically creates checkpoints when codebase changes. No manual checkpoint management.

**Bad Example:**

```ruby
# ❌ Manual checkpoint creation everywhere
class Agent
  def execute_task(task)
    # Do work
    modify_state(task)
    
    # Remember to create checkpoint - easy to forget!
    create_checkpoint("Milestone #{milestone.number} complete")
  end
  
  def execute_step(step)
    # Do work
    modify_files(step)
    
    # Oops, forgot to create checkpoint!
  end
end
```

**Good Example:**

```ruby
# ✅ Automatic checkpoint tracking
class Agent
  def execute_milestone(milestone)
    # Do work
    modify_files(milestone)
    
    # CheckpointTracker automatically detects changes
    checkpoint_id = CheckpointTracker.instance.current_id(path: @project_path)
    
    # Checkpoint created automatically if changes detected
    broadcast_milestone_completed(
      milestone_number: milestone.number,
      checkpoint_id: checkpoint_id  # Always has valid ID
    )
  end
  
  def execute_step(step)
    modify_files(step)
    
    # Automatic checkpoint - no need to remember
    checkpoint_id = CheckpointTracker.instance.current_id(path: @project_path)
  end
end
```

**Why**: Automatic tracking eliminates human error, ensures every modification is tracked, and provides consistent checkpoint IDs.

---

### [ARCH][!CHECKPOINT-METADATA]

**Rule**: Store execution metadata in Git notes, not separate databases. Checkpoints are self-contained.

**Bad Example:**

```ruby
# ❌ Checkpoint data split across systems
class CheckpointService
  def create_checkpoint(message, milestone_id:)
    # Create git commit
    commit_hash = run_git("commit -m '#{message}'")
    
    # Store metadata in database - now split!
    CheckpointMetadata.create(
      commit_hash: commit_hash,
      milestone_id: milestone_id,
      worker_id: @worker_id
    )
  end
end

# Problem: Git history doesn't show metadata
# Problem: Database and git can get out of sync
```

**Good Example:**

```ruby
# ✅ Metadata stored in git notes
class CheckpointService
  def create_checkpoint(message, milestone_id: nil, worker_id: nil)
    # Create commit
    commit_hash = run_git("commit -m '#{message}'")
    
    # Store metadata in git notes (part of git repo)
    metadata = {
      milestone_id: milestone_id,
      worker_id: worker_id,
      created_at: Time.now.utc.iso8601
    }
    
    run_git("notes add -m '#{metadata.to_json}' #{commit_hash}")
    
    # Everything self-contained in git
  end
  
  def checkpoint_metadata(commit_hash)
    result = run_git("notes show #{commit_hash}")
    JSON.parse(result, symbolize_names: true)
  end
end

# Benefits:
# - Git clone includes all metadata
# - No database sync issues
# - Metadata travels with commits
```

**Why**: Git notes keep metadata with commits, eliminate sync issues, and make checkpoints portable.

---

### [ARCH][!SINGLETON-TRACKER]

**Rule**: Use singleton CheckpointTracker for coordinated access across workers and workflows.

**Bad Example:**

```ruby
# ❌ Each worker creates its own tracker
class Agent
  def initialize(path:)
    @id = SecureRandom.uuid
    @checkpoint_service = CheckpointService.new(path: path)
  end
  
  def current_checkpoint
    @checkpoint_service.current_checkpoint_id
  end
end

class Agent
  def initialize(path:)
    # Different instance - no coordination!
    @checkpoint_service = CheckpointService.new(path: path)
  end
end

# Result: Agents don't know about each other's checkpoints
```

**Good Example:**

```ruby
# ✅ Singleton ensures coordination
class CheckpointTracker
  include Singleton

  def initialize
    @id = SecureRandom.uuid
    @checkpoints_by_path = {}
    @checkpoint_services = {}
    @mutex = Mutex.new
  end

  sig { params(path: String).returns(T.nilable(UUID)) }
  def current_id(path:)
    @mutex.synchronize do
      service = checkpoint_service_for(path)
      checkpoint_id = service.current_checkpoint_id
      @checkpoints_by_path[path] = service.get_checkpoint(checkpoint_id)
      checkpoint_id
    end
  end

  private

  def checkpoint_service_for(path)
    @checkpoint_services[path] ||= CheckpointService.new(path: path)
  end
end

# All workers use the same tracker
class Agent
  def current_checkpoint
    CheckpointTracker.instance.current_id(path: @project_path)
  end
end

class Agent
  def current_checkpoint
    CheckpointTracker.instance.current_id(path: @project_path)
  end
end
```

**Why**: Singleton ensures all workers see the same checkpoints, prevents race conditions, and coordinates checkpoint creation.

---

## Patterns

### Pattern: Context with Validation

```ruby
module Contexts
  class SisyphusContext < BaseContext
    attr_reader :codebase_path, :plan_goal, :execution_id

    def initialize(codebase_path:, plan_goal:, execution_id:)
      super()  # Initialize base context

      # Type validation
      raise TypeError, "codebase_path must be a String" unless codebase_path.is_a?(String)
      raise TypeError, "plan_goal must be a String" unless plan_goal.is_a?(String)
      raise TypeError, "execution_id must be a String" unless execution_id.is_a?(String)

      # Value validation
      raise ArgumentError, "codebase_path cannot be empty" if codebase_path.strip.empty?
      raise ArgumentError, "plan_goal cannot be empty" if plan_goal.strip.empty?

      # Path validation
      expanded_path = File.expand_path(codebase_path)
      raise ArgumentError, "codebase_path must exist: #{codebase_path}" unless Dir.exist?(expanded_path)

      @codebase_path = expanded_path
      @plan_goal = plan_goal
      @execution_id = execution_id
    end

    # Domain-specific methods
        sisyphus_context: {
          codebase_path: @codebase_path,
          plan_goal: @plan_goal,
          execution_id: @execution_id
        }
      }
    end

    # Validation helper
    def self.validate!(obj)
      unless obj.is_a?(SisyphusContext)
        raise TypeError, "Expected SisyphusContext, got #{obj.class}"
      end
    end
  end
end
```

---

### Pattern: Checkpoint Service with Metadata

```ruby
class CheckpointService
  attr_reader :path

  def initialize(path:)
    @id = SecureRandom.uuid
    @path = File.expand_path(path)
    validate_git_repository!
  end

  def create_checkpoint(message, milestone_id: nil, step_ids: nil, worker_id: nil)
    # Create commit
    checkpoint_id = create_git_commit(message)
    
    # Build metadata
    metadata = {
      milestone_id: milestone_id,
      step_ids: step_ids,
      worker_id: worker_id,
      created_at: Time.now.utc.iso8601
    }.compact
    
    # Store in git notes
    store_metadata(checkpoint_id, metadata) unless metadata.empty?
    
    # Get files changed
    files_changed = get_files_changed(checkpoint_id)
    
    # Return checkpoint object
    Checkpoint.new(
      id: checkpoint_id,
      message: message,
      created_at: Time.now.utc,
      metadata: metadata,
      files_changed: files_changed
    )
  end

  def current_checkpoint_id
    # Return cached if no changes
    @current_checkpoint ||= get_checkpoint(current_commit_id)
    return @current_checkpoint.id unless has_uncommitted_changes?

    # Create checkpoint for changes
    checkpoint = create_checkpoint("Auto-checkpoint at #{Time.now.utc.iso8601}")
    @current_checkpoint = checkpoint
    checkpoint.id
  end

  def diff_since_checkpoint(checkpoint_id)
    validate_checkpoint!(checkpoint_id)
    
    result = run_git("diff #{checkpoint_id}..HEAD")
    result[:output]
  end

  private

  def create_git_commit(message)
    run_git("add -A")
    run_git("commit -m '#{escape_message(message)}'")
    run_git("rev-parse HEAD").strip
  end

  def store_metadata(checkpoint_id, metadata)
    json = metadata.to_json
    run_git("notes add -m '#{escape_message(json)}' #{checkpoint_id}")
  end

  def get_files_changed(checkpoint_id)
    result = run_git("show --name-only --pretty=format:'' #{checkpoint_id}")
    result.split("\n").reject(&:empty?)
  end

  def has_uncommitted_changes?
    result = run_git("diff HEAD")
    !result.strip.empty?
  end
end
```

---

## Real-World Examples

### Example: Agent with Context

```ruby
class TaskExecutionAgent
  def initialize(owner_id:, parent_id:, context:)
    @id = SecureRandom.uuid
    super(owner_id: owner_id, parent_id: parent_id)
    
    # Validate context type
    raise TypeError unless context.is_a?(BaseContext)
    @context = context
  end

  def execute
    start!
    
    # Add execution entry to context
    @context.add(
      content: "Starting step execution",
      topics: ["execution", "step"],
      source: "TaskExecutionAgent"
    )
    
    # Execute with context
    result = execute_with_context(@context)
    
    # Record result to context
    @context.add(
      content: "Step complete: #{result.summary}",
      topics: ["execution", "result"],
      source: "TaskExecutionAgent"
    )
    
    finish!
    result
  end
end
```

### Example: Automatic Checkpoint Tracking

```ruby
class ExecutionAgent
  def perform(plan_path, project_path, execution_id)
    @project_path = project_path
    @execution_id = execution_id
    @broadcaster = ExecutionProgressBroadcaster.new
    
    # Load plan
    plan = load_plan(plan_path)
    
    plan.milestones.each_with_index do |milestone, idx|
      # Execute milestone
      @broadcaster.broadcast_milestone_started(
        execution_id: @execution_id,
        milestone_number: idx + 1
      )
      
      execute_milestone(milestone)
      
      # Checkpoint is automatically created when files change
      checkpoint_id = CheckpointTracker.instance.current_id(path: @project_path)
      
      @broadcaster.broadcast_milestone_completed(
        execution_id: @execution_id,
        milestone_number: idx + 1,
        checkpoint_id: checkpoint_id  # Always valid
      )
    end
  end
end
```

---

## Checklist

When implementing context and checkpoint patterns:

- [ ] All contexts extend BaseContext
- [ ] Context validation in constructors (type, value, path)
- [ ] Contexts passed explicitly as parameters
- [ ] Context serialization includes base + subclass data
- [ ] Sub-contexts support hierarchical organization
- [ ] CheckpointTracker used as singleton
- [ ] Checkpoints auto-created on file changes
- [ ] Metadata stored in Git notes, not separate DB
- [ ] Checkpoint IDs are Git commit hashes
- [ ] Diff capability between checkpoints
- [ ] Rollback capability to previous checkpoints
- [ ] Files changed tracked in checkpoint metadata

---

## Summary

**Key Principles:**

1. **BaseContext** defines common interface
2. **Explicit passing** of context objects
3. **Automatic checkpoint** tracking on file changes
4. **Git notes** store metadata with commits
5. **Singleton tracker** coordinates access

**Benefits:**

- Consistent context interface across workflows
- Type-safe context validation
- Automatic checkpoint creation eliminates errors
- Self-contained checkpoints (metadata in git)
- Coordinated checkpoint access across workers

**When to Use:**

- Agents need execution environment
- Code modifications require versioning
- Rollback capability needed
- Historical state inspection required
- Multiple workers need coordinated checkpoints

