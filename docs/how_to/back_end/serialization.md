---
description: Serializer class patterns for JSON API responses
globs: app/serializers/**/*.rb
alwaysApply: false
---

# Serializer Class Patterns

**Tags**: [coding, back_end]  
**Applies To**: Ruby/Rails JSON serialization  
**Date**: 2026-01-06

## Overview

Serializer classes convert domain models to JSON for API responses. Models handle domain logic, serializers handle JSON structure. Never add serialization methods to models.

## Serialization Architecture

```
Serializer System
│
├── Serializer Class (single responsibility)
│   ├── Takes model as input
│   ├── Reads model properties via getters
│   ├── Structures JSON output
│   └── Returns hash ready for JSON
│
├── Model (no serialization methods)
│   ├── Has attr_readers for properties
│   └── NO JSON methods
│
└── Flow
    ├── Controller → Service → Model
    ├── Model → Serializer → Hash
    └── Hash → JSON → HTTP Response

Separation of Concerns:
├── Models: Domain logic and state
├── Serializers: JSON structure
└── Controllers: Validation and routing
```

---

## Rules

### [SER][!SERIALIZER-CLASSES-NOT-MODELS]

**Rule**: Create dedicated serializer classes with `show(instance:)` and `index(collection:)` methods. Never add serialization methods to models. Always use keyword arguments.

**Bad Example:**

```ruby
# ❌ Serialization on model + positional args
class Execution
  def as_json
    { id: @id, status: @status }  # ❌ Wrong layer!
  end
end

# ❌ Positional arguments
ExecutionSerializer.show(execution)  # What is this?
```

**Good Example:**

```ruby
# typed: strict

# ✅ Clean model - no serialization
class Execution
  extend T::Sig
  
  sig { returns(UUID) }
  attr_reader :id
  
  sig { returns(Symbol) }
  attr_reader :status
  
  sig { returns(Time) }
  attr_reader :started_at
  
  sig { params(status: Symbol).void }
  def initialize(status: :pending)
    @id = T.let(UUID.generate, UUID)
    @status = T.let(status, Symbol)
    @started_at = T.let(Time.now.utc, Time)
  end
end

# ✅ Dedicated serializer with keyword args
class ExecutionSerializer
  extend T::Sig
  
  sig { params(execution: Execution).returns(T::Hash[Symbol, T.any(String, Symbol)]) }
  def self.show(execution:)  # ✅ Keyword arg
    {
      id: execution.id.to_s,
      status: execution.status,
      started_at: execution.started_at.iso8601
    }
  end
  
  sig { params(executions: T::Array[Execution]).returns(T::Array[T::Hash[Symbol, T.any(String, Symbol)]]) }
  def self.index(executions:)  # ✅ Keyword arg
    executions.map { |execution| show(execution: execution) }
  end
end

# ✅ Self-documenting calls
ExecutionSerializer.show(execution: execution)
ExecutionSerializer.index(executions: executions)
```

**Why**: Serializers separate concerns - models handle domain logic, serializers handle JSON structure. Keyword arguments make calls self-documenting.

---

### [SER][!USE-GETTERS-NOT-INSTANCE-VARS]

**Rule**: Serializers read model properties via getters. Never access instance variables directly.

**Good Example:**

```ruby
# typed: strict
class ExecutionSerializer
  extend T::Sig
  
  sig { params(execution: Execution).returns(T::Hash[Symbol, T.any(String, Symbol, Integer)]) }
  def self.show(execution:)
    {
      id: execution.id.to_s,        # ✅ Via getter
      status: execution.status,     # ✅ Via getter
      priority: execution.priority  # ✅ Via getter
    }
  end
end
```

**Why**: Getters respect encapsulation and allow models to control access.

---

### [SER][!NESTED-SERIALIZERS]

**Rule**: Use nested serializers for complex objects. Don't inline nested serialization.

**Good Example:**

```ruby
# typed: strict

# Individual serializers
class MessageSerializer
  extend T::Sig
  
  sig { params(message: Message).returns(T::Hash[Symbol, String]) }
  def self.show(message:)
    {
      id: message.id.to_s,
      role: message.role,
      content: message.content
    }
  end
  
  sig { params(messages: T::Array[Message]).returns(T::Array[T::Hash[Symbol, String]]) }
  def self.index(messages:)
    messages.map { |message| show(message: message) }
  end
end

class ConfigSerializer
  extend T::Sig
  
  sig { params(config: Config).returns(T::Hash[Symbol, T.any(String, Integer)]) }
  def self.show(config:)
    {
      model: config.model,
      timeout: config.timeout
    }
  end
end

# Composed serializer
class AgentSessionSerializer
  extend T::Sig
  
  sig { params(session: AgentSession).returns(T::Hash[Symbol, T.untyped]) }
  def self.show(session:)
    {
      session_id: session.session_id.to_s,
      messages: MessageSerializer.index(messages: session.messages),
      config: ConfigSerializer.show(config: session.config)
    }
  end
  
  sig { params(sessions: T::Array[AgentSession]).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
  def self.index(sessions:)
    sessions.map { |session| show(session: session) }
  end
end
```

**Why**: Nested serializers keep serialization logic modular and reusable.

---

### [SER][!MULTIPLE-VIEWS]

**Rule**: Use view parameter for different representations of same model.

**Good Example:**

```ruby
# typed: strict
class ExecutionSerializer
  extend T::Sig
  
  sig { params(execution: Execution, view: Symbol).returns(T::Hash[Symbol, T.untyped]) }
  def self.show(execution:, view: :default)
    case view
    when :minimal
      { id: execution.id.to_s, status: execution.status }
    when :detailed
      {
        id: execution.id.to_s,
        status: execution.status,
        started_at: execution.started_at.iso8601,
        metadata: execution.metadata,
        logs: execution.logs
      }
    else
      {
        id: execution.id.to_s,
        status: execution.status,
        started_at: execution.started_at.iso8601
      }
    end
  end
  
  sig { params(executions: T::Array[Execution], view: Symbol).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
  def self.index(executions:, view: :default)
    executions.map { |execution| show(execution: execution, view: view) }
  end
end

# Usage
ExecutionSerializer.show(execution: execution, view: :minimal)
ExecutionSerializer.show(execution: execution, view: :detailed)
```

**Why**: Different endpoints can use different views of the same model without duplication.

---

## Pattern: Controller Integration

```ruby
# typed: strict
class Api::ExecutionsController < ApplicationController
  extend T::Sig
  
  sig { void }
  def index
    service = ExecutionService.new(state_store: StateStore.new)
    executions = service.list
    
    render json: ExecutionSerializer.index(executions: executions)
  end
  
  sig { void }
  def show
    service = ExecutionService.new(state_store: StateStore.new)
    execution = service.find(execution_id: UUID.parse(params["id"]))
    
    render json: ExecutionSerializer.show(execution: execution, view: :detailed)
  end
  
  sig { void }
  def create
    service = ExecutionService.new(state_store: StateStore.new)
    execution = service.create(
      goal: params.fetch("goal"),
      priority: params.fetch("priority").to_i
    )
    
    render json: ExecutionSerializer.show(execution: execution), status: :created
  end
end
```

---

## Checklist

- [ ] No serialization methods on models
- [ ] Serializer class for each model
- [ ] `show(instance:)` for single objects
- [ ] `index(collection:)` for arrays
- [ ] Keyword arguments everywhere
- [ ] Serializers read via getters only
- [ ] Nested serializers for complex objects
- [ ] Type signatures on all methods

---

## Summary

**Key Principles:**

1. **Dedicated serializers** - One per model, separate from models
2. **show/index methods** - Consistent naming with keyword args
3. **Read via getters** - Never access instance variables
4. **Nested serializers** - Compose for complex objects
5. **Multiple views** - Use view parameter for different representations
6. **Type-safe** - Full Sorbet signatures

**Benefits:**

- Clear separation of concerns
- Easy to change JSON structure
- Testable in isolation
- Reusable across endpoints
- Self-documenting with keyword args

