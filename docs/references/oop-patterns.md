# OOP Patterns Guide

## Overview

This guide establishes the object-oriented patterns used throughout the translator_ruby codebase. These patterns prioritize **type safety**, **single responsibility**, and **fail-fast validation** over backward compatibility.

## Core Principles

### 1. No Hash-Based State ❌

**BAD - Hash-based entities:**
```ruby
# ❌ NEVER DO THIS
@goal = {
  id: SecureRandom.uuid,
  text: "Complete task",
  status: :pending,
  progress: 0
}

# ❌ Direct hash manipulation
@goal[:status] = :completed
@goal[:progress] = 100
```

**GOOD - Proper classes:**
```ruby
# ✅ ALWAYS DO THIS
@goal = Goals::PrimaryGoal.new(
  goal_text: "Complete task",
  entry_id: entry.id,
  metadata: {}
)

# ✅ Methods encapsulate behavior
@goal.update_status(status: :complete, entry_id: entry.id, progress: 100)
```

### 2. Strict Type Validation ✓

Every class MUST validate all inputs and raise descriptive errors:

```ruby
def initialize(goal_text:, entry_id:, status: NOT_STARTED, metadata: {})
  raise ArgumentError, "goal_text must be a String" unless goal_text.is_a?(String)
  raise ArgumentError, "entry_id must be a String" unless entry_id.is_a?(String)
  raise ArgumentError, "Invalid status: #{status}" unless STATUSES.include?(status)
  
  @goal_text = goal_text
  @entry_id = entry_id
  # ...
end
```

### 3. Single Responsibility Principle

Each class has ONE clear purpose:

- `BaseGoal` - Core goal behavior (status, progress tracking)
- `PrimaryGoal` - Managing sub-goals and hierarchy
- `SubGoal` - Belonging to a parent with priority
- `GoalContext` - Coordinating goals with context entries

### 4. Composition Over Inheritance

Use composition for "has-a" relationships:

```ruby
class PrimaryGoal < BaseGoal
  def initialize(...)
    super
    @sub_goals = []           # Composition: has many SubGoals
    @sub_goal_map = {}        # Fast lookup
  end
  
  def add_sub_goal(...)
    sub_goal = SubGoal.new(...)
    @sub_goals << sub_goal
    sub_goal
  end
end
```

## Class Hierarchy Patterns

### Base Class Pattern

Every entity type should have a base class:

```ruby
module Contexts
  module Goals
    class BaseGoal
      # Constants at the top
      STATUSES = [
        NOT_STARTED = :not_started,
        IN_PROGRESS = :in_progress,
        COMPLETE = :complete,
        FAILED = :failed
      ].freeze

      # Attribute readers
      attr_reader :id, :goal_text, :status, :entries, :progress

      # Initialization with validation
      def initialize(goal_text:, entry_id:, status: NOT_STARTED, metadata: {})
        validate_types!(goal_text, entry_id, status)
        
        @id = SecureRandom.uuid
        @goal_text = goal_text
        @entries = [entry_id]
        @status = status
        @progress = 0
        @created_at = Time.now.utc.iso8601
        @updated_at = Time.now.utc.iso8601
        @metadata = metadata
      end

      # Public interface methods
      def update_status(status:, entry_id:, progress: nil)
        validate_update!(status, entry_id)
        
        @status = status
        @progress = progress unless progress.nil?
        @entries << entry_id
        @updated_at = Time.now.utc.iso8601
      end

      def completed?
        @status == COMPLETE
      end

      # Serialization (see serialization guide)
      def to_h
        {
          id: @id,
          goal_text: @goal_text,
          status: @status,
          entries: @entries,
          progress: @progress,
          created_at: @created_at,
          updated_at: @updated_at,
          metadata: @metadata
        }
      end

      def self.from_h(hash)
        validate_hash!(hash)
        reconstruct_from_hash(hash)
      end

      private

      def validate_types!(goal_text, entry_id, status)
        raise ArgumentError, "goal_text must be a String" unless goal_text.is_a?(String)
        raise ArgumentError, "entry_id must be a String" unless entry_id.is_a?(String)
        raise ArgumentError, "Invalid status: #{status}" unless STATUSES.include?(status)
      end

      def validate_update!(status, entry_id)
        raise ArgumentError, "Invalid status: #{status}" unless STATUSES.include?(status)
        raise ArgumentError, "entry_id must be a String" unless entry_id.is_a?(String)
      end
    end
  end
end
```

### Inheritance Pattern

Subclasses extend base functionality:

```ruby
module Contexts
  module Goals
    class PrimaryGoal < BaseGoal
      attr_reader :sub_goals, :sub_goal_map

      def initialize(goal_text:, entry_id:, status: NOT_STARTED, metadata: {})
        # Call parent with explicit parameters
        super(goal_text: goal_text, entry_id: entry_id, status: status, metadata: metadata)
        
        # Initialize subclass-specific state
        @sub_goals = []
        @sub_goal_map = {}
      end

      # Add subclass-specific behavior
      def add_sub_goal(goal_text:, entry_id:, priority: 2, metadata: {})
        validate_sub_goal_params!(goal_text, entry_id, priority)
        
        sub_goal = SubGoal.new(
          goal_text: goal_text,
          entry_id: entry_id,
          parent: self,
          priority: priority,
          metadata: metadata
        )
        
        @sub_goals << sub_goal
        @sub_goal_map[sub_goal.id] = sub_goal
        sub_goal
      end

      # Extend serialization with chaining
      def to_h
        {
          **super,  # Get all parent properties
          sub_goals: @sub_goals.map(&:to_h)  # Add subclass properties
        }
      end

      def self.from_h(hash)
        validate_hash_structure!(hash)
        
        # Reconstruct parent state
        primary_goal = allocate
        restore_base_state!(primary_goal, hash)
        
        # Reconstruct subclass state
        sub_goals = hash[:sub_goals].map { |sg| SubGoal.from_h(sg, parent: primary_goal) }
        primary_goal.instance_variable_set(:@sub_goals, sub_goals)
        primary_goal.instance_variable_set(:@sub_goal_map, build_map(sub_goals))
        
        primary_goal
      end

      private

      def validate_sub_goal_params!(goal_text, entry_id, priority)
        raise ArgumentError, "goal_text must be a String" unless goal_text.is_a?(String)
        raise ArgumentError, "entry_id must be a String" unless entry_id.is_a?(String)
        raise ArgumentError, "priority must be an Integer" unless priority.is_a?(Integer)
      end
    end
  end
end
```

## Validation Patterns

### Parameter Validation

**ALWAYS validate at the entry point:**

```ruby
def add_sub_goal(goal_text:, entry_id:, priority: 2, metadata: {})
  # Validate EVERYTHING
  raise ArgumentError, "goal_text must be a String" unless goal_text.is_a?(String)
  raise ArgumentError, "entry_id must be a String" unless entry_id.is_a?(String)
  raise ArgumentError, "priority must be an Integer" unless priority.is_a?(Integer)
  raise TypeError, "metadata must be a Hash" unless metadata.is_a?(Hash)
  
  # Only proceed with valid inputs
  # ...
end
```

### State Validation

```ruby
def update_status(status:, entry_id:, progress: nil)
  # Validate state transitions
  raise ArgumentError, "Invalid status: #{status}" unless STATUSES.include?(status)
  raise ArgumentError, "Cannot transition from #{@status} to #{status}" if invalid_transition?(@status, status)
  
  # Update state
  @status = status
  @updated_at = Time.now.utc.iso8601
end
```

### Type Validation

```ruby
def add_sub_context(name, context)
  # Strict type checking - no duck typing
  raise TypeError, "context must be a BaseContext, got #{context.class}" unless context.is_a?(BaseContext)
  
  @sub_contexts[name.to_sym] = context
  context
end
```

## Error Messages

**Be specific and actionable:**

```ruby
# ❌ BAD
raise "Invalid input"

# ✅ GOOD
raise ArgumentError, "goal_text must be a String, got #{goal_text.class}"

# ✅ BETTER
raise ArgumentError, "goal_text must be a non-empty String, got #{goal_text.inspect}"

# ✅ BEST
raise ArgumentError, "Expected goal_text to be a String but got #{goal_text.class}. " \
                     "Example: 'Complete the project'"
```

## Testing Patterns

### Test Real Objects, Not Hashes

```ruby
# ❌ BAD - Testing hash structure
test "goal has correct structure" do
  goal = { id: "123", text: "Task", status: :pending }
  assert_equal "Task", goal[:text]
end

# ✅ GOOD - Testing object behavior
test "goal tracks status changes" do
  goal = Goals::BaseGoal.new(goal_text: "Task", entry_id: "e1")
  goal.update_status(status: Goals::BaseGoal::IN_PROGRESS, entry_id: "e2")
  
  assert_equal :in_progress, goal.status
  assert_includes goal.entries, "e2"
end
```

### Test Validation

```ruby
test "validates goal_text is a String" do
  error = assert_raises(ArgumentError) do
    Goals::BaseGoal.new(goal_text: 123, entry_id: "e1")
  end
  assert_match(/goal_text must be a String/, error.message)
end
```

### Test Serialization Round-Trips

```ruby
test "serializes and deserializes correctly" do
  original = Goals::PrimaryGoal.new(goal_text: "Test", entry_id: "e1")
  original.add_sub_goal(goal_text: "Sub", entry_id: "e2", priority: 1)
  
  hash = original.to_h
  reconstructed = Goals::PrimaryGoal.from_h(hash)
  
  assert_equal original.id, reconstructed.id
  assert_equal original.goal_text, reconstructed.goal_text
  assert_equal 1, reconstructed.sub_goals.size
end
```

## Common Patterns

### Factory Pattern for Complex Creation

```ruby
class GoalContext
  def add_sub_goal(goal_text, priority: 2, metadata: {})
    # Validate first
    raise TypeError, "Primary goal must be set first" unless @primary_goal
    
    # Create entry
    entry = add(content: "Sub-goal: #{goal_text}", topics: ["goal"], source: "goal_context")
    
    # Create and link goal
    sub_goal = @primary_goal.add_sub_goal(
      goal_text: goal_text,
      entry_id: entry.id,
      priority: priority,
      metadata: metadata
    )
    
    # Update entry with goal id
    entry.metadata[:goal_id] = sub_goal.id
    
    sub_goal
  end
end
```

### Builder Pattern for Complex Objects

```ruby
class GoalBuilder
  def initialize(goal_text)
    @goal_text = goal_text
    @priority = 1
    @metadata = {}
  end

  def with_priority(priority)
    @priority = priority
    self  # Return self for chaining
  end

  def with_metadata(metadata)
    @metadata = metadata
    self
  end

  def build(entry_id)
    PrimaryGoal.new(
      goal_text: @goal_text,
      entry_id: entry_id,
      metadata: @metadata.merge(priority: @priority)
    )
  end
end

# Usage:
goal = GoalBuilder.new("Complete project")
  .with_priority(1)
  .with_metadata(type: "milestone")
  .build(entry.id)
```

## Directory Structure

Organize related classes into modules/directories:

```
app/models/contexts/
├── goals/
│   ├── base_goal.rb
│   ├── primary_goal.rb
│   └── sub_goal.rb
├── entries/
│   ├── base_entry.rb
│   ├── research_entry.rb
│   ├── scene_entry.rb
│   └── message_entry.rb
├── actions/
│   ├── base_action.rb
│   └── tool_action.rb
└── workflow/
    ├── state_transition.rb
    ├── decision.rb
    └── workflow_error.rb
```

## Lessons Learned from Real Refactorings

### Parameter Naming Consistency

**Problem:** When creating related classes, inconsistent parameter names cause confusion and errors.

```ruby
# ❌ BAD - Inconsistent naming
class StateTransition
  def initialize(from:, to:, event:)  # Short names
    @from_state = from
    @to_state = to
  end
end

class WorkflowContext
  def record_transition(from_state:, to_state:, event:)  # Long names
    # This mismatch causes errors!
    StateTransition.new(from_state: from_state, to_state: to_state, event: event)
  end
end
```

```ruby
# ✅ GOOD - Consistent naming
class StateTransition
  def initialize(from:, to:, event:)
    @from_state = from  # Internal naming can differ
    @to_state = to
  end
end

class WorkflowContext
  def record_transition(from:, to:, event:)  # Match the class's API
    StateTransition.new(from: from, to: to, event: event)
  end
end
```

**Lesson:** Keep parameter names consistent across related classes, even if internal attribute names differ.

### Collections: attr_reader vs Methods

**Problem:** Should collections be exposed directly or through methods?

```ruby
# ❌ BAD - Filtering entries every time
class WorkflowContext
  def transitions
    @entries.select { |e| e.metadata[:entity_type] == :transition }
  end
end
```

```ruby
# ✅ GOOD - Dedicated collection with attr_reader
class WorkflowContext
  attr_reader :transitions  # Direct access to collection

  def initialize
    @transitions = []  # Dedicated storage
  end

  def record_transition(...)
    transition = Workflow::StateTransition.new(...)
    @transitions << transition  # Store object directly
    transition
  end
end
```

**Lesson:** When you have domain entities, store them in dedicated collections rather than filtering from a general list.

### Testing Collections of Objects

**Update tests to check object types, not metadata:**

```ruby
# ❌ BAD - Testing metadata
test "has transitions" do
  context.record_transition(from: :a, to: :b, event: :go)
  
  transitions = context.entries.select { |e| e.metadata[:entity_type] == :transition }
  assert_equal 1, transitions.size
end
```

```ruby
# ✅ GOOD - Testing actual objects
test "has transitions" do
  transition = context.record_transition(from: :a, to: :b, event: :go)
  
  assert_instance_of Workflow::StateTransition, transition
  assert_equal 1, context.transitions.size
  assert context.transitions.all? { |t| t.is_a?(Workflow::StateTransition) }
end
```

**Lesson:** Test that methods return and store actual objects, not hashes with magic metadata keys.

### Refactoring Pitfalls

**Watch out for these common issues when refactoring to OOP:**

1. **Orphaned method parameters** - Old code may pass parameters that no longer exist
   ```ruby
   # ❌ Old code still using removed parameter
   load_sub_contexts_from_h(context, data, context_registry)
   
   # ✅ Remove all references to removed parameters
   load_sub_contexts_from_h(context, data)
   ```

2. **Accessor patterns** - Ensure readers exist for new collections
   ```ruby
   # ❌ Forgot to add reader
   def initialize
     @transitions = []  # No attr_reader!
   end
   
   # ✅ Add attr_reader
   attr_reader :transitions
   
   def initialize
     @transitions = []
   end
   ```

3. **Return types changed** - Methods that returned entries now return objects
   ```ruby
   # ❌ Test expects entry
   entry = context.record_transition(...)
   assert_equal :transition, entry.metadata[:entity_type]
   
   # ✅ Test expects object
   transition = context.record_transition(...)
   assert_instance_of StateTransition, transition
   ```

### Safe Refactoring Process

When refactoring from hashes to OOP:

1. **Create the new classes first** - Get them working independently
2. **Update the context** - Change how entities are stored
3. **Run tests and read errors carefully** - They tell you what's broken
4. **Update tests to use objects** - Change assertions to check types
5. **Remove old code** - Delete hash-based patterns completely
6. **Check integration tests** - Ensure the full system works

## Key Takeaways

1. **Always use proper classes, never hashes** for domain entities
2. **Validate everything** at method entry points
3. **Fail fast** with descriptive errors
4. **Use composition** for "has-a" relationships
5. **Chain serialization** with `**super` pattern
6. **Test real objects** and their behavior
7. **No backward compatibility** - only support proper types
8. **Single responsibility** - one purpose per class
9. **Keep parameter names consistent** across related classes
10. **Use dedicated collections** instead of filtering general lists

## Migration Checklist

When refactoring from hashes to OOP:

- [ ] Create base class with core behavior
- [ ] Add strict type validation
- [ ] Implement to_h/from_h (see serialization guide)
- [ ] Create subclasses for specialization
- [ ] Update all usage sites to use objects
- [ ] Write comprehensive tests
- [ ] Remove all hash-based code
- [ ] Update documentation

### Lesson 6: State Machine Completion Pattern

**Problem:** State machines must complete their full transition cycle. Building result objects with state information before final transition creates timing bugs.

**Bad Pattern:**
```ruby
# ❌ BAD: Captures state before transition completes
def execute
  trigger(:start)
  do_work
  trigger(:working)
  @result = build_result  # current_state = :working
  # Never calls trigger(:finish)!
end

def build_result
  { final_state: current_state }  # Returns :working instead of :complete
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Complete state machine, then update metadata
def execute
  trigger(:start)
  do_work
  trigger(:working)
  @result = build_result        # Build with intermediate state
  trigger(:finish)              # Complete the state machine
  @result[:metadata][:final_state] = current_state  # Update with actual final state
  @result
end
```

**Key Principles:**
1. **Always complete state transitions** - Every state machine path should end at a terminal state
2. **Capture dynamic state after transitions** - Don't freeze state prematurely
3. **Return values from execute** - Makes result accessible and testable
4. **Update metadata post-transition** - Ensure accuracy of state information

---

### Lesson 7: Inheritance and Optional Parameters

**Problem:** Parent class requires parameter, but not all subclasses need it. Forcing all subclasses to provide meaningless values violates LSP.

**Bad Pattern:**
```ruby
# ❌ BAD: Forces all subclasses to provide tools even when unused
class ToolCallPrompt < BasePrompt
  def initialize(tools:)  # Required parameter
    raise ArgumentError if tools.nil?
    @tools = tools
    super()
  end
end

class FileRelevancePrompt < ToolCallPrompt
  # Has to call super with dummy value!
  def initialize
    super(tools: [])  # Meaningless empty array
  end
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Default parameter, subclasses override when needed
class ToolCallPrompt < BasePrompt
  attr_reader :tools
  
  def initialize(tools: [])  # Optional with sensible default
    @tools = Array(tools)
    super()
  end
end

class ActionDetectionPrompt < ToolCallPrompt
  def initialize(tools:)
    raise ArgumentError if tools.nil? || tools.empty?
    super(tools: tools)  # Enforces requirement at subclass level
  end
end

class FileRelevancePrompt < ToolCallPrompt
  # No initialize needed - uses parent default
end
```

**Key Principles:**
1. **Make parent class flexible** - Use defaults for optional behavior
2. **Let subclasses enforce constraints** - Each subclass knows its own requirements
3. **Document parameter purpose** - Clarify when tools are actually used
4. **Use meaningful defaults** - Empty array, not nil, for collections

**Why This Matters:**
- Subclasses aren't forced into unnatural patterns
- Code self-documents which prompts use which features
- Easier to add new subclasses without boilerplate
- Follows Liskov Substitution Principle

---

## References

- [Serialization Guide](./serialization-guide.md)
- SOLID Principles
- Ruby Style Guide
- Domain-Driven Design patterns

