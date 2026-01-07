---
description: Type safety patterns with Sorbet for Ruby
globs: app/**/*.rb
alwaysApply: false
---

# Type Safety with Sorbet

**Tags**: [architecture, coding, back_end]  
**Applies To**: Ruby applications  
**Date**: 2026-01-06

## Overview

Sorbet provides gradual type checking for Ruby, catching type errors at runtime and (with `srb tc`) at static analysis time. This document covers patterns for using Sorbet to ensure type safety across your application.

## Type Safety Architecture

```
Sorbet Type System
│
├── Runtime Type Checking (T.let, sig)
│   ├── Method signatures (sig)
│   │   ├── Parameter types
│   │   └── Return types
│   │
│   ├── Type assertions (T.let, T.cast)
│   │   ├── Variable type declarations
│   │   ├── Boundary type assertions
│   │   └── Type narrowing
│   │
│   └── Type helpers
│       ├── T.nilable(Type) - Allow nil
│       ├── T.any(Type1, Type2) - Union types
│       ├── T::Array[Type] - Typed arrays
│       └── T::Hash[KeyType, ValueType] - Typed hashes
│
├── Static Type Checking (srb tc)
│   ├── Type inference
│   ├── Method call validation
│   ├── Nil safety checks
│   └── Type compatibility verification
│
├── Strictness Levels
│   ├── # typed: false - No checking (default)
│   ├── # typed: true - Basic checking
│   ├── # typed: strict - Strict checking (all methods need sigs)
│   └── # typed: strong - Strongest (no T.untyped, no unchecked calls)
│
└── Common Patterns
    ├── Domain objects with full signatures
    ├── Service objects with typed dependencies
    ├── Controller params with typed access
    └── Factory methods with return types

Best Practices:
├── Start with # typed: strict for new files
├── Use T.let for instance variable types
├── Signature every public method
├── Use T.nilable explicitly when nil is valid
└── Never use T.untyped - always use explicit types (primitives or classes)
```

---

## Rules

### [TYPE][!TYPED-STRICT]

**Rule**: Use `# typed: strict` for all application code. Require signatures on all methods.

**Good Example:**

```ruby
# typed: strict

class ExecutionService
  extend T::Sig
  
  sig { params(state_store: StateStore, broadcaster: Broadcaster).void }
  def initialize(state_store:, broadcaster:)
    @id = T.let(UUID.generate, UUID)
    @state_store = T.let(state_store, StateStore)
    @broadcaster = T.let(broadcaster, Broadcaster)
  end
  
  sig { params(execution_id: UUID, action: String).returns(ExecutionResult) }
  def execute(execution_id:, action:)
    raise TypeError unless execution_id.is_a?(UUID)
    result_data = perform_operation(execution_id: execution_id, action: action)
    ExecutionResult.new(success: true, data: result_data)
  end
  
  private
  
  sig { params(execution_id: UUID, action: String).returns(String) }
  def perform_operation(execution_id:, action:)
    # Implementation
    "operation completed"
  end
end
```

**Why**: Strict typing catches errors at development time and makes interfaces explicit.

---

### [TYPE][!INSTANCE-VAR-TYPES]

**Rule**: Declare types for all instance variables using `T.let`.

**Good Example:**

```ruby
# typed: strict

class Agent
  extend T::Sig
  
  STATES = T.let([:idle, :running, :complete, :failed].freeze, T::Array[Symbol])
  
  sig { params(context: Context).void }
  def initialize(context:)
    @id = T.let(UUID.generate, UUID)
    @state = T.let(:idle, Symbol)
    @context = T.let(context, Context)
  end
  
  sig { returns(UUID) }
  attr_reader :id
  
  sig { returns(Symbol) }
  attr_reader :state
  
  sig { returns(T::Boolean) }
  def idle?
    @state == :idle
  end
  
  sig { returns(T::Boolean) }
  def running?
    @state == :running
  end
  
  private
  
  sig { params(new_state: Symbol).void }
  def transition_to(new_state)
    @state = new_state
  end
end
```

**Why**: Explicit instance variable types prevent accidental type mismatches and nil errors.

---

### [TYPE][!NILABLE-EXPLICIT]

**Rule**: Use `T.nilable(Type)` explicitly when nil is a valid value. Never rely on implicit nil.

**Bad Example:**

```ruby
# ❌ Implicit nilability
sig { params(user_id: String).void }
def initialize(user_id:)
  @user_id = user_id
  @cached_user = nil  # Type unclear!
end

sig { returns(User) }
def user
  @cached_user ||= User.find(@user_id)
end
```

**Good Example:**

```ruby
# ✅ Explicit nilability
sig { params(user_id: String).void }
def initialize(user_id:)
  @id = T.let(SecureRandom.uuid, String)
  @user_id = T.let(user_id, String)
  @cached_user = T.let(nil, T.nilable(User))
end

sig { returns(User) }
def user
  @cached_user ||= User.find(@user_id)
end
```

**Why**: Explicit nilability makes it clear when nil is expected vs a bug.

---

### [TYPE][!TYPED-ARRAYS-HASHES]

**Rule**: Use typed arrays and hashes with `T::Array[Type]` and `T::Hash[K, V]`.

**Good Example:**

```ruby
# typed: strict

class ContextEntry
  extend T::Sig
  
  sig { params(content: String, tags: T::Array[String]).void }
  def initialize(content:, tags:)
    @id = T.let(UUID.generate, UUID)
    @content = T.let(content, String)
    @tags = T.let(tags, T::Array[String])
    @metadata = T.let({}, T::Hash[Symbol, String])
  end
  
  sig { returns(T::Array[String]) }
  attr_reader :tags
  
  sig { params(key: Symbol, value: String).void }
  def add_metadata(key, value)
    @metadata[key] = value
  end
  
end
```

**Why**: Typed collections ensure homogeneous data and catch element type errors.

---

### [TYPE][!UUID-TYPE]

**Rule**: Create a UUID type for type-safe identifiers. Never use plain String for IDs.

**Good Example:**

```ruby
# typed: strict

# Define UUID type
class UUID < T::Struct
  extend T::Sig
  
  const :value, String
  
  sig { returns(String) }
  def to_s
    @value
  end
  
  sig { params(value: String).returns(UUID) }
  def self.generate
    new(value: SecureRandom.uuid)
  end
  
  sig { params(value: String).returns(UUID) }
  def self.parse(value)
    unless value.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
      raise ArgumentError, "Invalid UUID format: #{value}"
    end
    new(value: value)
  end
end

# Use UUID type in domain objects
class Execution
  extend T::Sig
  
  sig { returns(UUID) }
  attr_reader :id
  
  sig { params(status: Symbol).void }
  def initialize(status: :pending)
    @id = T.let(UUID.generate, UUID)
    @status = T.let(status, Symbol)
  end
end

# Type-safe method signatures
class ExecutionService
  extend T::Sig
  
  sig { params(execution_id: UUID).returns(Execution) }
  def find(execution_id:)
    # execution_id is guaranteed to be a UUID, not just any string
    Execution.find_by(id: execution_id.to_s)
  end
end
```

**Why**: UUID type prevents accidentally passing arbitrary strings as IDs and provides validation.

---

### [TYPE][!BOUNDARY-ASSERTIONS]

**Rule**: Use type assertions at system boundaries (params, API responses, external data).

**Good Example:**

```ruby
# typed: strict

class ExecutionsController < ApplicationController
  extend T::Sig
  
  sig { void }
  def create
    # Type assertion at boundary
    execution_params = T.let(params.require(:execution).permit(:goal, :priority), ActionController::Parameters)
    
    goal = T.cast(execution_params["goal"], String)
    priority = T.cast(execution_params["priority"], String)
    
    service = ExecutionService.new(
      state_store: StateStore.new,
      broadcaster: Broadcaster.new
    )
    
    result = service.execute(goal: goal, priority: priority)
    
    render json: result, status: :created
  end
end
```

**Why**: Boundaries are where type safety can break - assert types explicitly.

---

## Patterns

### Pattern: Domain Object with Full Type Safety

```ruby
# typed: strict

class Execution
  extend T::Sig
  
  STATUSES = T.let([:pending, :running, :complete, :failed].freeze, T::Array[Symbol])
  
  sig { returns(UUID) }
  attr_reader :id
  
  sig { returns(Symbol) }
  attr_reader :status
  
  sig { returns(Time) }
  attr_reader :started_at
  
  sig { returns(T::Hash[Symbol, String]) }
  attr_reader :metadata
  
  sig { params(status: Symbol, metadata: T::Hash[Symbol, String]).void }
  def initialize(status: :pending, metadata: {})
    @id = T.let(UUID.generate, UUID)
    raise TypeError unless status.is_a?(Symbol)
    @status = T.let(status, Symbol)
    @started_at = T.let(Time.now.utc, Time)
    @metadata = T.let(metadata, T::Hash[Symbol, String])
  end
  
  sig { returns(Execution) }
  def start
    Execution.new(status: :running, metadata: @metadata)
  end
  
  sig { returns(T::Boolean) }
  def pending?
    @status == :pending
  end
  
end
```

---

### Pattern: Service with Typed Dependencies

```ruby
# typed: strict

class OrchestrationService
  extend T::Sig
  
  sig { params(state_store: StateStore, broadcaster: Broadcaster, context: Context).void }
  def initialize(state_store:, broadcaster:, context:)
    @id = T.let(UUID.generate, UUID)
    @state_store = T.let(state_store, StateStore)
    @broadcaster = T.let(broadcaster, Broadcaster)
    @context = T.let(context, Context)
  end
  
  sig { params(execution_id: UUID).returns(OrchestrationResult) }
  def execute(execution_id:)
    raise TypeError unless execution_id.is_a?(UUID)
    
    # Orchestrate workflow
    execution = start_execution(execution_id)
    broadcast_progress(execution)
    
    OrchestrationResult.new(success: true, execution_id: execution.id)
  end
  
  private
  
  sig { params(execution_id: UUID).returns(Execution) }
  def start_execution(execution_id)
    execution = Execution.new(status: :running)
    @state_store.save(execution_id, execution)
    execution
  end
  
  sig { params(execution: Execution).void }
  def broadcast_progress(execution)
    @broadcaster.publish(
      channel: "executions",
      event: "progress",
      data: ExecutionSerializer.show(execution: execution)
    )
  end
end
```

---

### Pattern: Factory with Return Types

```ruby
# typed: strict

class ContextFactory
  extend T::Sig
  
  sig { params(type: String, options: T::Hash[Symbol, String]).returns(BaseContext) }
  def self.build(type:, options:)
    case type
    when "code"
      CodeContext.new(
        codebase_path: options.fetch(:codebase_path),
        goal: options.fetch(:goal)
      )
    when "research"
      ResearchContext.new(
        topic: options.fetch(:topic)
      )
    else
      raise ArgumentError, "Unknown context type: #{type}"
    end
  end
end
```

---

## Integration with Rails

### Typed Controllers

```ruby
# typed: strict

class Api::ExecutionsController < ApplicationController
  extend T::Sig
  
  sig { void }
  def show
    execution_id = UUID.parse(params["id"])
    execution = Execution.find(execution_id)
    
    render json: ExecutionSerializer.show(execution: execution)
  end
  
  sig { void }
  def create
    service = T.let(
      ExecutionService.new(
        state_store: StateStore.new,
        broadcaster: ExecutionBroadcaster.new
      ),
      ExecutionService
    )
    
    result = service.execute(
      goal: execution_params.fetch(:goal),
      priority: execution_params.fetch(:priority)
    )
    
    render json: result, status: :created
  end
  
  private
  
  sig { returns(ActionController::Parameters) }
  def execution_params
    params.require(:execution).permit(:goal, :priority)
  end
end
```

---

## Checklist

- [ ] All files have `# typed: strict` header
- [ ] All public methods have `sig` signatures
- [ ] Instance variables declared with `T.let`
- [ ] `T.nilable` used explicitly for optional values
- [ ] Arrays and hashes are typed (`T::Array`, `T::Hash`)
- [ ] Type assertions at boundaries (params, external data)
- [ ] Constants have explicit types with `T.let`
- [ ] Return types match actual returns

---

## Summary

**Key Principles:**

1. **Strict by default** - Use `# typed: strict` for application code
2. **Explicit instance variables** - `T.let` for all `@variables`
3. **Nilable explicit** - `T.nilable(Type)` when nil is valid
4. **Typed collections** - `T::Array[Type]`, `T::Hash[K,V]`
5. **UUID for IDs** - Use UUID type, not String
6. **Boundary assertions** - Type checks at system edges

**Benefits:**

- Catch type errors at development time
- Self-documenting interfaces with signatures
- IDE autocomplete and navigation
- Refactoring confidence with type checking
- Nil safety through explicit `T.nilable`

**When to Use:**

- All application code (models, services, controllers)
- Domain objects and value objects
- Service layer with dependency injection
- Factories and builders
- Any code that will be reused or extended

