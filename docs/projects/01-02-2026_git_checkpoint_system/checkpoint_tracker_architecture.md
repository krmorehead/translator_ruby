# CheckpointTracker Singleton Architecture

## Overview

The checkpoint system has been refactored to use a **singleton pattern** that automatically tracks codebase state and creates checkpoints only when the codebase has changed. This eliminates the need for manual checkpoint management and ensures every memory entry is tied to a specific codebase state.

## Design Principles

### 1. Singleton Pattern for Global State

**CheckpointTracker** is a singleton that tracks the current checkpoint for each repository path. This provides:
- **Single source of truth** for current codebase state
- **Automatic checkpoint creation** only when changes are detected
- **Thread-safe access** via mutex synchronization
- **No dependency injection** - accessible from anywhere via `CheckpointTracker.instance`

### 2. Automatic Checkpoint ID in Memory Records

Every record method in **WorkflowMemoryStore** automatically captures the current checkpoint ID:
- `record_state_transition` - Records checkpoint with state changes
- `record_decision` - Records checkpoint with decisions
- `record_context` - Records checkpoint with context additions
- `record_error` - Records checkpoint when errors occur
- `record_output` - Records checkpoint with outputs

This ensures **every memory entry** is associated with the exact codebase state at that moment.

### 3. Required Parameters, No Nil Checks

Following strict OOP principles:
- `WorkflowMemoryStore` requires `path` parameter (no optional/nil)
- All instance variables initialized on construction
- No defensive `return nil unless @path` checks
- Fail fast with clear error messages if requirements not met

## Implementation

### CheckpointTracker Singleton

```ruby
class CheckpointTracker
  include Singleton

  def current_id(path:, message: nil, milestone_id: nil, worker_id: nil)
    @mutex.synchronize do
      service = checkpoint_service_for(path)
      last_checkpoint = @checkpoints_by_path[path]

      # Only create new checkpoint if codebase has changed
      if last_checkpoint.nil? || codebase_changed?(service)
        checkpoint = create_checkpoint(service, message, milestone_id, worker_id)
        @checkpoints_by_path[path] = checkpoint
        checkpoint.id
      else
        last_checkpoint.id
      end
    end
  end

  # Check if working directory has uncommitted changes
  def codebase_changed?(service)
    service.has_uncommitted_changes?
  end
end
```

**Key Features:**
- Returns existing checkpoint ID if no changes detected
- Automatically creates checkpoint when changes are present
- Thread-safe with mutex synchronization
- Caches last checkpoint per path

### WorkflowMemoryStore Integration

```ruby
class WorkflowMemoryStore
  def initialize(owner_id:, workflow_id:, workflow_name:, path:)
    raise ArgumentError, "path is required" if path.nil? || path.empty?
    
    @path = path
    @last_transition_at = Time.now.utc  # Always initialized
  end

  def record_decision(decision:, rationale:, context: {})
    entry = {
      decision: decision,
      rationale: rationale,
      context: context,
      state: current_state,
      timestamp: Time.now.utc.iso8601,
      checkpoint_id: current_checkpoint_id  # Automatic!
    }
    @sections[:decisions] << entry
    save!
    entry
  end

  private

  def current_checkpoint_id
    CheckpointTracker.instance.current_id(path: extract_repo_path)
  end

  def extract_repo_path
    # Walk up directory tree to find .git directory
    current = File.expand_path(@path)
    while current != "/"
      return current if File.directory?(File.join(current, ".git"))
      current = File.dirname(current)
    end
    raise "No Git repository found for path: #{@path}"
  end
end
```

**Key Features:**
- Path is required, not optional
- No nil checks - path is always valid
- Checkpoint ID automatically captured on every record
- Finds repository root from workflow path

## Benefits

### 1. Deterministic Behavior
- No "maybe" methods - either create checkpoint or return existing
- Checkpoints created based on actual codebase changes
- No manual checkpoint creation needed

### 2. Memory-Checkpoint Coupling
- Every memory entry has a checkpoint_id
- Easy to query "what was the codebase state when this decision was made?"
- Enables time-travel debugging and state reconstruction

### 3. Simplified Architecture
- BaseWorker doesn't need checkpoint logic
- No Checkpointable concern needed
- Workers don't pass checkpoint services around
- Memory store handles everything automatically

### 4. No Backward Compatibility Overhead
- Clean break from old patterns
- Required parameters enforced
- No defensive coding
- Fail fast on missing requirements

## Usage Examples

### Creating Checkpoints Automatically

```ruby
# Just record to memory - checkpoint ID is automatic
memory_store.record_decision(
  decision: "Implement feature X",
  rationale: "Required for milestone 1"
)

# Checkpoint ID is captured automatically
# If codebase changed since last checkpoint, new one is created
# If no changes, uses existing checkpoint ID
```

### Querying Checkpoint History

```ruby
# Get all decisions with their checkpoint IDs
decisions = memory_store.get_section(:decisions)
decisions.each do |decision|
  puts "#{decision[:decision]} @ checkpoint #{decision[:checkpoint_id]}"
end

# Get checkpoint details from CheckpointTracker
checkpoint = CheckpointTracker.instance.current_checkpoint(path: repo_path)
```

### Force Checkpoint Creation

```ruby
# For milestone boundaries, force a checkpoint even if no changes
CheckpointTracker.instance.force_checkpoint(
  path: repo_path,
  message: "Milestone 1 complete",
  milestone_id: "m1"
)
```

## Testing

CheckpointTracker is fully tested with 12 tests covering:
- Singleton behavior
- Automatic checkpoint creation
- Change detection
- Multiple repository paths
- Cache management
- Thread safety

WorkflowMemoryStore tests verify:
- Required path parameter
- Automatic checkpoint ID capture
- Repository path extraction
- All record methods include checkpoint_id

## Migration Impact

### Removed
- ❌ Checkpointable concern
- ❌ BaseWorker checkpoint integration
- ❌ Manual checkpoint service passing
- ❌ Optional path parameters with nil defaults
- ❌ Defensive nil checks throughout

### Added
- ✅ CheckpointTracker singleton
- ✅ Automatic checkpoint ID in all memory records
- ✅ Required path parameter in WorkflowMemoryStore
- ✅ Repository path extraction logic
- ✅ `has_uncommitted_changes?` in CheckpointService

## Next Steps

1. ✅ CheckpointTracker singleton implemented
2. ✅ WorkflowMemoryStore integration complete
3. ⏳ API endpoints for frontend
4. ⏳ Integration tests for full lifecycle
5. ⏳ Documentation updates

## References

- `lib/checkpoint_tracker.rb` - Singleton implementation
- `app/models/workflow_memory_store.rb` - Memory integration
- `app/services/checkpoint_service.rb` - Git operations
- `docs/references/oop-patterns.md` - Design patterns (Lessons 20 & 21)

