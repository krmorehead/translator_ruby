---
description: Inheritance and hierarchical patterns for class design
globs: app/**/*.rb
alwaysApply: false
---

# Inheritance & Hierarchical Patterns

**Tags**: [architecture, design, coding]  
**Applies To**: Any object-oriented system (Ruby/Rails as reference)  
**Date**: 2026-01-05

## Overview

Inheritance and hierarchical patterns provide structured ways to share behavior across related classes while maintaining clear boundaries and responsibilities. This guide covers base class patterns, context inheritance, hierarchical relationships, and state machines that enforce valid transitions.

**When to use these patterns:**
- Multiple related classes share common behavior
- You need strict interface contracts across implementations
- State transitions must be controlled and validated
- Parent-child relationships require coordinated behavior

## Hierarchy Pattern Tree

```
Context Pattern (manages execution state)
├── AbstractBaseContext
│   ├── Common state: entries, sub_contexts, metadata
│   ├── Common behavior: add entries, manage hierarchy, serialize
│   └── Subclasses define: domain-specific state + validation
│       │
│       ├── DomainContextA (e.g., code modification context)
│       │   ├── Domain state: target_path, goal, execution_id
│       │   └── Domain behavior: methods specific to domain
│       │
│       └── DomainContextB (e.g., research context)
│           ├── Domain state: session_id, focus_area
│           └── Domain behavior: query filtering, results aggregation

Worker Pattern (orchestrates workflows)
├── AbstractBaseWorker
│   ├── State machine: idle → working → complete/error
│   ├── Common state: identifier, owner, child_workflows
│   └── Common behavior: lifecycle, coordination, state tracking
│       │
│       ├── SpecificWorkerA
│       │   ├── Manages: 3-5 specialized workflows
│       │   └── Coordinates: domain-specific execution pipeline
│       │
│       └── SpecificWorkerB
│           ├── Manages: different set of workflows
│           └── Coordinates: different execution strategy

Workflow Pattern (executes tasks)
├── AbstractBaseWorkflow
│   ├── State machine: pending → running → complete/failed
│   ├── Common state: ids (workflow, parent, owner)
│   └── Common behavior: execute, report state, access parent
│       │
│       ├── GranularWorkflow (fine-grained states)
│       │   ├── Extended states: preparing → validating → executing → recording
│       │   └── Provides: detailed progress visibility
│       │
│       └── CoarseWorkflow (simple states)
│           ├── Basic states: running → complete
│           └── Provides: simple coordination
```

---

## Rules

### [ARCH][!BASE-CLASS-CONTRACT]

**Rule**: Create abstract base classes that define the interface contract all subclasses must implement.

**Bad Example:**

```ruby
# ❌ No base class - duplicated code everywhere
class ContextTypeA
  def initialize(param_a:, metadata_field1:, metadata_field2:)
    @entries = []          # Duplicated
    @sub_contexts = {}     # Duplicated
    @param_a = param_a
    @metadata_field1 = metadata_field1  # Unclear parameter explosion
    @metadata_field2 = metadata_field2  # Unclear parameter explosion
    # ... entry management logic duplicated
  end
end

class ContextTypeB
  def initialize(param_b:, metadata_field1:, metadata_field2:)
    @entries = []          # Duplicated again!
    @sub_contexts = {}     # Duplicated again!
    @param_b = param_b
    @metadata_field1 = metadata_field1  # Duplicated again!
    @metadata_field2 = metadata_field2  # Duplicated again!
    # ... same entry logic copy-pasted
  end
end
```

**Good Example:**

```ruby
# ✅ Base class defines common interface
class AbstractContext
  attr_reader :entries, :sub_contexts

  def initialize
    @entries = []
    @sub_contexts = {}
    initialize_indexes
  end

  # Common behavior all contexts share
  def add_entry(entry)
    validate_entry!(entry)
    @entries << entry
    update_indexes(entry)
  end

  def add_child_context(name, context)
    validate_context_type!(context)
    @sub_contexts[name.to_sym] = context
  end

  protected

  def initialize_indexes
    # Hook for subclasses
  end
end

# ✅ Subclasses extend with domain-specific behavior
class DomainSpecificContext < AbstractContext
  extend T::Sig
  
  sig { returns(String) }
  attr_reader :domain_param_a
  
  sig { returns(Integer) }
  attr_reader :domain_param_b

  sig { params(domain_param_a: String, domain_param_b: Integer).void }
  def initialize(domain_param_a:, domain_param_b:)
    super()  # Initialize base context first
    
    # Domain-specific validation
    validate_domain_params!(domain_param_a, domain_param_b)
    
    # Domain-specific state
    @domain_param_a = domain_param_a
    @domain_param_b = domain_param_b
  end

  # Domain-specific behavior
  def domain_specific_operation
    # Uses base class @entries and @sub_contexts
    entries.filter { |e| relevant_to_domain?(e) }
  end
end
```

**Why**: Base classes eliminate duplication, enforce consistent interfaces, and make adding new subclasses trivial.

---

### [ARCH][!EXPLICIT-SUPER]

**Rule**: Always call `super` explicitly with parameters in subclass constructors to ensure proper initialization chain.

**Bad Example:**

```ruby
# ❌ Implicit super call causes confusion
class SisyphusContext < BaseContext
  def initialize(codebase_path:, plan_goal:, execution_id:)
    # No super call - base class not initialized!
    @codebase_path = codebase_path
    @plan_goal = plan_goal
    @execution_id = execution_id
  end
end

# Result: @entries and @sub_contexts are nil
context = SisyphusContext.new(codebase_path: "/path", plan_goal: "goal", execution_id: "id")
context.add(content: "test", topics: ["test"], source: "test")
# NoMethodError: undefined method `<<' for nil:NilClass
```

**Good Example:**

```ruby
# ✅ Explicit super with clear initialization
class SisyphusContext < BaseContext
  def initialize(codebase_path:, plan_goal:, execution_id:)
    super()  # Explicit call to BaseContext#initialize
    
    # Now safe to use base class functionality
    @codebase_path = codebase_path
    @plan_goal = plan_goal
    @execution_id = execution_id
  end
end

# Works correctly
context = SisyphusContext.new(codebase_path: "/path", plan_goal: "goal", execution_id: "id")
context.add(content: "test", topics: ["test"], source: "test")  # ✅ Works
```

**Why**: Explicit super makes the initialization chain visible and prevents subtle bugs from missed base class setup.

---

### [ARCH][!HIERARCHICAL-VALIDATION]

**Rule**: Validate type relationships in hierarchical structures to enforce contracts.

**Bad Example:**

```ruby
# ❌ No type checking - accepts anything
class BaseContext
  def add_sub_context(name, context)
    @sub_contexts[name.to_sym] = context  # Could be anything!
  end
end

# Chaos ensues
context = BaseContext.new
context.add_sub_context(:child, "not a context")  # Accepted
context.add_sub_context(:other, {entries: []})     # Accepted
context.add_sub_context(:wrong, nil)                # Accepted
```

**Good Example:**

```ruby
# ✅ Strict type validation enforces hierarchy
class BaseContext
  def add_sub_context(name, context)
    unless context.is_a?(BaseContext)
      raise ArgumentError, "context must be a BaseContext, got #{context.class}"
    end
    
    @sub_contexts[name.to_sym] = context
    context
  end
end

# Type safety enforced
context = BaseContext.new
context.add_sub_context(:child, "not a context")
# ArgumentError: context must be a BaseContext, got String

child_context = SisyphusContext.new(codebase_path: "/path", ...)
context.add_sub_context(:sisyphus, child_context)  # ✅ Works
```

**Why**: Type validation prevents corruption of hierarchical structures and catches integration errors immediately.

---

### [ARCH][!STATE-MACHINE-ENFORCEMENT]

**Rule**: Use state machines to enforce valid state transitions and prevent illegal state changes.

**Bad Example:**

```ruby
# ❌ Manual state tracking with no validation
class Workflow
  attr_accessor :state

  def initialize
    @state = :pending
  end

  def run
    @state = :running
    execute_work
    @state = :complete
  rescue => e
    @state = :failed
  end
end

# Can set any state directly - chaos!
workflow = Workflow.new
workflow.state = :bananas  # No validation
workflow.state = :running
workflow.state = :pending  # Invalid transition allowed
```

**Good Example:**

```ruby
# ✅ State machine with enforced transitions
class BaseWorkflow
  include StateMachine

  initial_state :pending

  state :pending,  description: "Workflow created, not yet started"
  state :running,  description: "Workflow is executing"
  state :complete, description: "Workflow finished successfully"
  state :failed,   description: "Workflow encountered an error"

  # Define ONLY valid transitions
  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :complete, on: :finish
  transition from: [:pending, :running], to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  # Auto-record transitions
  on_transition do |from, to, event, payload|
    record_state_change(from, to, event, payload)
  end
end

# Usage - only valid transitions allowed
workflow = StepExecutionWorkflow.new(owner_id: "owner", parent_id: "parent")
workflow.start!       # ✅ pending → running
workflow.finish!      # ✅ running → complete
workflow.retry!       # ✅ failed → pending

workflow.start!       # InvalidTransitionError: Cannot transition from complete to running
```

**Why**: State machines make state transitions explicit, prevent invalid states, and provide audit trails automatically.

---

### [ARCH][!GRANULAR-STATE-MACHINES]

**Rule**: Extend base state machines with granular states for complex workflows while maintaining valid transition graph.

**Bad Example:**

```ruby
# ❌ Redefining everything from scratch
class StepExecutionWorkflow
  attr_accessor :state

  def initialize
    @state = :pending
  end

  def execute
    @state = :context_assembly  # Made up state
    # ... work
    @state = :validating
    # ... no validation of transitions
  end
end
```

**Good Example:**

```ruby
# ✅ Extend base state machine with specific states
class StepExecutionWorkflow < BaseWorkflow
  # Inherit base states (pending, running, complete, failed)
  
  # Add workflow-specific granular states
  state :assembling_context, description: "Gathering needed context"
  state :planning,           description: "Planning tool call sequence"
  state :validating,         description: "Validating tool parameters"
  state :executing,          description: "Executing tools"
  state :recording,          description: "Recording results"

  # Define granular transition flow
  transition from: :pending,            to: :running,            on: :start
  transition from: :running,            to: :assembling_context, on: :initialized
  transition from: :assembling_context, to: :planning,           on: :context_assembled
  transition from: :planning,           to: :validating,         on: :planned
  transition from: :validating,         to: :executing,          on: :validated
  transition from: :executing,          to: :recording,          on: :executed
  transition from: :recording,          to: :complete,           on: :finish
  
  # Failure can happen from any work state
  transition from: [:running, :assembling_context, :planning, :validating, :executing, :recording],
             to: :failed, on: :fail
end

# Usage with granular control
workflow = StepExecutionWorkflow.new(owner_id: "owner", parent_id: "parent")
workflow.start!              # pending → running
workflow.initialized!        # running → assembling_context
workflow.context_assembled!  # assembling_context → planning
workflow.planned!            # planning → validating
workflow.validated!          # validating → executing
workflow.executed!           # executing → recording
workflow.finish!             # recording → complete

# Each transition is explicit and validated
```

**Why**: Granular states provide visibility into long-running processes while maintaining the safety of enforced transitions.

---

### [ARCH][!PARENT-CHILD-COORDINATION]

**Rule**: Establish clear parent-child relationships with explicit references and coordinated behavior.

**Bad Example:**

```ruby
# ❌ Implicit relationships with no coordination
class Worker
  def initialize
    @workflows = []
  end

  def add_workflow(workflow_class)
    workflow = workflow_class.new
    @workflows << workflow
    # No relationship established
  end
end

class Workflow
  def initialize
    # No parent reference
    # Can't access parent state
  end
end
```

**Good Example:**

```ruby
# ✅ Explicit parent-child with ID-based coordination
class BaseWorker
  extend T::Sig
  
  sig { returns(UUID) }
  attr_reader :owner_id
  
  sig { returns(T::Hash[UUID, Workflow]) }
  attr_reader :workflows

  sig { params(owner_id: UUID).void }
  def initialize(owner_id:)
    @id = T.let(UUID.generate, UUID)
    @owner_id = T.let(owner_id, UUID)
    @workflows = T.let({}, T::Hash[UUID, Workflow])
    register_with_graph
  end

  sig { params(workflow_class: T.class_of(Workflow), goal: String, priority: Integer).returns(Workflow) }
  def create_workflow(workflow_class, goal:, priority:)
    workflow = workflow_class.new(
      owner_id: @owner_id,
      parent_id: @owner_id,  # Worker is parent
      goal: goal,
      priority: priority
    )
    @workflows[workflow.workflow_id] = workflow
    workflow
  end
end

class BaseWorkflow
  attr_reader :workflow_id, :owner_id, :parent_id

  def initialize(owner_id:, parent_id:)
    @workflow_id = SecureRandom.uuid
    @owner_id = owner_id
    @parent_id = parent_id
  end

  # Access parent through service
  def parent_memory
    return nil if is_root?
    service = ContextGraphService.instance
    parent_node = service.find_by_id(@parent_id)
    parent_node&.memory_store
  end

  def is_root?
    @parent_id == @owner_id
  end
end

# Hierarchical context access
workflow = worker.create_workflow(ResearchWorkflow)
workflow.parent_memory  # Access worker's memory
```

**Why**: Explicit parent-child relationships enable coordinated behavior and hierarchical data access.

---

## Patterns

### Pattern: Abstract Base Class

**Structure:**

```ruby
module Contexts
  class BaseContext
    # 1. Define interface methods all subclasses must support
    attr_reader :entries, :sub_contexts

    def initialize
      # 2. Initialize common state
      @entries = []
      @sub_contexts = {}
    end

    # 3. Provide common implementations
    def add(content:, topics:, source:, metadata: {})
      entry = Entries::BaseEntry.new(
        content: content,
        topics: topics,
        source: source,
        metadata: metadata
      )
      add_entry(entry)
    end

    # 4. Protected helpers for subclasses
    protected

    def add_entry(entry)
      @entries << entry
      index_entry(entry)
      entry
    end

    # 5. Entry management
  end
end
```

**Usage:**

```ruby
# Subclass extends base with specific behavior
module Contexts
  class SisyphusContext < BaseContext
    extend T::Sig
    
    sig { returns(String) }
    attr_reader :codebase_path
    
    sig { returns(String) }
    attr_reader :plan_goal
    
    sig { returns(UUID) }
    attr_reader :execution_id

    sig { params(codebase_path: String, plan_goal: String, execution_id: UUID).void }
    def initialize(codebase_path:, plan_goal:, execution_id:)
      super()  # Initialize base context

      # Validate subclass-specific parameters
      validate_sisyphus_params!(codebase_path, plan_goal, execution_id)

      # Store subclass-specific state
      @codebase_path = File.expand_path(codebase_path)
      @plan_goal = plan_goal
      @execution_id = execution_id
    end

    # Subclass-specific methods
    def with_current_position(milestone: nil, step: nil)
      self.class.new(
        codebase_path: @codebase_path,
        plan_goal: @plan_goal,
        execution_id: @execution_id,
        current_milestone: milestone,
        current_step: step
      )
    end

    # Domain-specific methods
        sisyphus_context: {
          codebase_path: @codebase_path,
          plan_goal: @plan_goal,
          execution_id: @execution_id
        }
      }
    end

    private

    def validate_sisyphus_params!(codebase_path, plan_goal, execution_id)
      raise TypeError, "codebase_path must be a String" unless codebase_path.is_a?(String)
      raise ArgumentError, "codebase_path cannot be empty" if codebase_path.strip.empty?
      raise ArgumentError, "Invalid directory: #{codebase_path}" unless Dir.exist?(File.expand_path(codebase_path))
      # ... more validation
    end
  end
end
```

---

### Pattern: State Machine with Transitions

**Structure:**

```ruby
class BaseWorkflow
  include StateMachine

  # 1. Define initial state
  initial_state :pending

  # 2. Define all possible states
  state :pending,  description: "Workflow created, not yet started"
  state :running,  description: "Workflow is executing"
  state :complete, description: "Workflow finished successfully"
  state :failed,   description: "Workflow encountered an error"

  # 3. Define valid transitions only
  transition from: :pending, to: :running, on: :start
  transition from: :running, to: :complete, on: :finish
  transition from: [:pending, :running], to: :failed, on: :fail
  transition from: :failed, to: :pending, on: :retry

  # 4. Add transition hooks
  on_transition do |from, to, event, payload|
    log_transition(from, to, event)
    record_state_to_memory(from, to, event, payload)
  end
end
```

**Extension for Granular States:**

```ruby
class StepExecutionWorkflow < BaseWorkflow
  # 5. Add domain-specific states
  state :assembling_context, description: "Gathering needed context"
  state :planning,           description: "Planning tool call sequence"
  state :validating,         description: "Validating tool parameters"
  state :executing,          description: "Executing tools"
  state :recording,          description: "Recording results"

  # 6. Define granular transition graph
  transition from: :pending,            to: :running,            on: :start
  transition from: :running,            to: :assembling_context, on: :initialized
  transition from: :assembling_context, to: :planning,           on: :context_assembled
  transition from: :planning,           to: :validating,         on: :planned
  transition from: :validating,         to: :executing,          on: :validated
  transition from: :executing,          to: :recording,          on: :executed
  transition from: :recording,          to: :complete,           on: :finish

  # 7. Error handling from any work state
  transition from: [:running, :assembling_context, :planning, :validating, :executing, :recording],
             to: :failed, on: :fail
end
```

---

### Pattern: Hierarchical Parent-Child Relationships

**Structure:**

```ruby
# Parent class (Worker)
class BaseWorker
  extend T::Sig
  
  sig { returns(UUID) }
  attr_reader :owner_id
  
  sig { returns(T::Hash[UUID, Workflow]) }
  attr_reader :workflows
  
  sig { returns(MemoryStore) }
  attr_reader :memory_store

  sig { params(owner_id: UUID).void }
  def initialize(owner_id:)
    @id = T.let(UUID.generate, UUID)
    @owner_id = T.let(owner_id, UUID)
    @workflows = T.let({}, T::Hash[UUID, Workflow])
    @memory_store = T.let(MemoryStore.new(owner_id: owner_id), MemoryStore)
    register_with_context_graph
  end

  sig { params(workflow_class: T.class_of(Workflow), goal: String, priority: Integer).returns(Workflow) }
  def create_workflow(workflow_class, goal:, priority:)
    workflow = workflow_class.new(
      owner_id: @owner_id,
      parent_id: @owner_id,  # Worker is parent
      goal: goal,
      priority: priority
    )
    @workflows[workflow.workflow_id] = workflow
    
    # Register relationship in graph
    ContextGraphService.instance.link(
      parent_id: @owner_id,
      child_id: workflow.workflow_id
    )
    
    workflow
  end

  protected

  def register_with_context_graph
    ContextGraphService.instance.register_node(
      WorkerNode.new(
        node_id: @owner_id,
        worker: self,
        memory_store: @memory_store
      )
    )
  end
end

# Child class (Workflow)
class BaseWorkflow
  attr_reader :workflow_id, :owner_id, :parent_id, :workflow_memory

  def initialize(owner_id:, parent_id:)
    @workflow_id = SecureRandom.uuid
    @owner_id = owner_id
    @parent_id = parent_id
    @workflow_memory = WorkflowMemoryStore.new(
      workflow_id: @workflow_id,
      owner_id: @owner_id
    )
    register_with_context_graph
  end

  # Navigate to parent through graph
  def parent_memory
    return nil if is_root?
    service = ContextGraphService.instance
    parent_node = service.find_by_id(@parent_id)
    parent_node&.memory_store
  end

  def is_root?
    @parent_id == @owner_id
  end

  protected

  def register_with_context_graph
    ContextGraphService.instance.register_node(
      WorkflowNode.new(
        node_id: @workflow_id,
        workflow: self,
        workflow_memory: @workflow_memory
      )
    )
  end
end
```

**Usage:**

```ruby
# Create hierarchical structure
worker = ProjectPlannerWorker.new(
  owner_id: "user123",
  goal: "Build authentication system",
  context: {}
)

# Worker creates child workflows with parent reference
research_workflow = worker.create_workflow(
  ResearchWorkflow,
  target_path: "/path/to/codebase"
)

planning_workflow = worker.create_workflow(
  ProjectPlanningWorkflow,
  research_results: research_workflow.result
)

# Workflows can access parent data
research_workflow.parent_memory  # Access worker's memory
planning_workflow.parent_memory  # Access worker's memory

# Parent can coordinate children
worker.workflows.each do |id, workflow|
  puts "#{workflow.class}: #{workflow.current_state}"
end
```

---

### Pattern: Error Recovery and Retry Logic

**Structure:**

```ruby
class BaseWorkflow
  include StateMachine

  # Define retry transition
  transition from: :failed, to: :pending, on: :retry

  # Track retry attempts
  attr_reader :retry_count, :max_retries

  def initialize(owner_id:, parent_id:, max_retries: 3)
    @retry_count = 0
    @max_retries = max_retries
    super
  end

  # Automatic retry with backoff
  def execute_with_retry
    start!
    execute_work
    finish!
  rescue => error
    handle_failure(error)
  end

  protected

  def handle_failure(error)
    @retry_count += 1
    
    if @retry_count <= @max_retries
      sleep_duration = exponential_backoff(@retry_count)
      Rails.logger.warn("Workflow #{workflow_id} failed, retrying in #{sleep_duration}s (attempt #{@retry_count}/#{@max_retries})")
      
      sleep(sleep_duration)
      retry!  # State transition: failed → pending
      execute_with_retry
    else
      Rails.logger.error("Workflow #{workflow_id} failed after #{@max_retries} attempts: #{error.message}")
      fail!(error: error.message)
    end
  end

  def exponential_backoff(attempt)
    [2 ** attempt, 60].min  # Max 60 seconds
  end
end
```

**Agent-Specific Error Recovery:**

```ruby
class AgentWorker < BaseWorker
  DEFAULT_MAX_ITERATIONS = 50
  DEFAULT_MAX_ACTIONS = 100

  sig { returns(Integer) }
  attr_reader :iteration_count
  
  sig { returns(Integer) }
  attr_reader :action_count

  sig { params(goal: String, context: Context, max_iterations: Integer).void }
  def initialize(goal:, context:, max_iterations: 100)
    super(goal: goal, context: context)
    @iteration_count = T.let(0, Integer)
    @action_count = T.let(0, Integer)
    @max_iterations = T.let(max_iterations, Integer)
    @max_iterations = options.fetch(:max_iterations, DEFAULT_MAX_ITERATIONS)
    @max_actions = options.fetch(:max_actions, DEFAULT_MAX_ACTIONS)
  end

  def execute
    start!
    initialized!
    
    loop do
      break if goal_reached? || limits_exceeded?
      
      planning!
      action = select_next_action
      
      action_selected!
      execute_action(action)
      
      action_completed!
      evaluate_progress
      
      @iteration_count += 1
      @action_count += 1
      
      if should_continue?
        continue!  # evaluating → planning
      else
        goal_reached!  # evaluating → synthesizing
        break
      end
    end
    
    synthesizing!
    synthesize_results
    finish!
  rescue => error
    fail!(error: error.message)
    raise
  end

  protected

  def limits_exceeded?
    @iteration_count >= @max_iterations || @action_count >= @max_actions
  end
end
```

---

## Real-World Examples

### Example 1: Context Hierarchy with Sub-Contexts

```ruby
# Create parent context
main_context = SisyphusContext.new(
  codebase_path: "/project/path",
  plan_goal: "Implement authentication",
  execution_id: SecureRandom.uuid
)

# Add domain-specific sub-contexts
research_context = BaseContext.new
research_context.add(
  content: "Found existing auth patterns in /lib/auth",
  topics: ["authentication", "research"],
  source: "codebase_analysis"
)
main_context.add_sub_context(:research, research_context)

execution_context = BaseContext.new
execution_context.add(
  content: "Executed: Created AuthController",
  topics: ["execution", "authentication"],
  source: "step_execution"
)
main_context.add_sub_context(:execution, execution_context)

# Navigate hierarchy
main_context.get_sub_context(:research)  # Access research findings
main_context.get_sub_context(:execution)  # Access execution results

# Access context data
entries = main_context.entries
# [
#   sub_contexts: {
#     research: { entries: [...], sub_contexts: {} },
#     execution: { entries: [...], sub_contexts: {} }
#   },
#   sisyphus_context: {
#     codebase_path: "/project/path",
#     plan_goal: "Implement authentication",
#     execution_id: "..."
#   }
# }

# Access sub-contexts
research = main_context.get_sub_context(:research)  # ✅ Access nested contexts
```

### Example 2: Multi-Workflow Orchestration with State Tracking

```ruby
# Worker orchestrates multiple workflows
class ProjectPlannerWorker < BaseWorker
  register_workflow ResearchWorkflow
  register_workflow ProjectPlanningWorkflow

  def execute
    start!
    
    # Execute research workflow
    research = create_workflow(ResearchWorkflow, target_path: @context[:path])
    research.execute
    
    # Wait for research to complete
    until research.complete? || research.failed?
      sleep 1
    end
    
    if research.failed?
      fail!(error: "Research failed: #{research.error}")
      return
    end
    
    # Execute planning workflow with research results
    planning = create_workflow(
      ProjectPlanningWorkflow,
      research_results: research.result,
      goal: @goal
    )
    planning.execute
    
    # Wait for planning to complete
    until planning.complete? || planning.failed?
      sleep 1
    end
    
    if planning.failed?
      fail!(error: "Planning failed: #{planning.error}")
      return
    end
    
    # Success - consolidate results
    @result = {
      research: research.result,
      plan: planning.result
    }
    finish!
  end
end

# Usage with state visibility
worker = ProjectPlannerWorker.new(
  owner_id: "user123",
  goal: "Build feature X",
  context: {path: "/project"}
)

# Track state changes
worker.on_transition do |from, to, event|
  puts "Worker: #{from} → #{to} (#{event})"
end

worker.execute

# Check final state
puts worker.current_state  # :complete or :failed
puts worker.result  # Consolidated results from both workflows
```

---

## Checklist

When implementing inheritance and hierarchical patterns:

- [ ] Base class defines common interface all subclasses must support
- [ ] Subclasses call `super` explicitly in constructors
- [ ] Type validation enforces hierarchy contracts (`.is_a?` checks)
- [ ] State machines define all valid states and transitions
- [ ] Invalid state transitions raise errors immediately
- [ ] Parent-child relationships use explicit IDs, not direct references
- [ ] Child classes can navigate to parent through service/registry
- [ ] Serialization includes entire hierarchy (sub-contexts, child workflows)
- [ ] Deserialization restores complete hierarchy
- [ ] Error recovery uses state transitions (failed → pending on retry)
- [ ] Retry logic includes exponential backoff and max attempts
- [ ] State transition hooks record changes to memory/logs
- [ ] Documentation explains when to subclass vs compose

---

## Summary

**Key Principles:**

1. **Base classes** define interfaces, subclasses add specialization
2. **Explicit super** ensures proper initialization chain
3. **Type validation** enforces hierarchical contracts
4. **State machines** prevent invalid transitions
5. **Parent-child relationships** enable coordinated behavior
6. **Error recovery** uses state transitions with retry logic

**Benefits:**

- Eliminates code duplication through inheritance
- Enforces consistent interfaces across implementations
- Prevents invalid state transitions automatically
- Enables hierarchical data access and coordination
- Makes adding new subclasses/workflows trivial
- Provides audit trail of state changes
- Supports graceful error recovery and retries

**When to Use:**

- Multiple related classes share common behavior
- State transitions must be controlled
- Parent-child coordination is required
- Long-running processes need granular state visibility
- Error recovery and retry logic is needed

