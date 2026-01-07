---
description: Service object design patterns for Ruby/Rails business logic
globs: app/services/**/*.rb
alwaysApply: false
---

# Service Design Patterns

**Tags**: [coding, design, back_end]  
**Applies To**: Ruby/Rails service layer  
**Date**: 2026-01-06

## Overview

Service objects encapsulate business logic separate from controllers and models. Controllers handle HTTP, services handle business logic, models handle data.

## Service Layer Pattern Tree

```
Service Layer Pattern
│
├── Controller (HTTP layer)
│   ├── Parse params
│   ├── Authenticate user
│   ├── Authorize action
│   ├── Delegate to service
│   └── Render response (use serializer)
│
├── Service (business logic layer)
│   ├── Initialize with dependencies (explicit, no defaults)
│   ├── Validate parameters (types only)
│   ├── Execute business logic
│   ├── Coordinate multiple models
│   ├── Call external APIs
│   └── Return domain objects (not hashes)
│
├── Model (data layer)
│   ├── Represent domain entities
│   ├── Validation
│   ├── Persistence
│   └── Simple queries
│
└── Serializer (presentation layer)
    ├── Transform models to JSON
    ├── show(instance:) for single objects
    └── index(collection:) for arrays

Service Naming:
├── *Service → Operations (AgentSessionService)
├── *Store → Storage (ExecutionStateStore)
└── *Broadcaster → Pub/Sub (ExecutionProgressBroadcaster)
```

---

## Rules

### [SVC][!THIN-CONTROLLERS-DELEGATE-TO-SERVICES]

**Rule**: Controllers delegate to services, handling only HTTP concerns (params, auth, rendering). Business logic belongs in services, not controllers or models.

**Good Example:**

```ruby
# typed: strict

# Controller - thin, HTTP concerns only
class Api::SessionsController < ApplicationController
  extend T::Sig
  
  sig { void }
  def create
    service = AgentSessionService.new(owner_id: current_user.id)
    session = service.create_session(agent_type: params["agent_type"])
    
    render json: SessionSerializer.show(session: session)
  end
end

# Service - business logic
class AgentSessionService
  extend T::Sig
  
  sig { params(owner_id: UUID).void }
  def initialize(owner_id:)
    @id = T.let(UUID.generate, UUID)
    @owner_id = T.let(owner_id, UUID)
  end
  
  sig { params(agent_type: String).returns(AgentSession) }
  def create_session(agent_type:)
    raise TypeError unless agent_type.is_a?(String)
    
    session = AgentSession.new(
      session_id: UUID.generate,
      owner_id: @owner_id,
      agent_type: agent_type,
      status: AgentSession::STATUS_ACTIVE
    )
    
    persist_session(session: session)
    session
  end
  
  private
  
  sig { params(session: AgentSession).void }
  def persist_session(session:)
    # Persistence logic
  end
end
```

**Why**: Thin controllers are easier to test. Business logic in services is reusable across controllers, jobs, and tests.

---

### [SVC][!EXPLICIT-DEPENDENCIES-NO-DEFAULTS]

**Rule**: Inject dependencies explicitly in constructor. No defaults that mask missing dependencies.

**Bad Example:**

```ruby
# ❌ Defaults mask missing dependencies
class ExecutionOrchestrationService
  def initialize(state_store: nil, broadcaster: nil)
    @state_store = state_store || ExecutionStateStore.new  # Silent fallback!
    @broadcaster = broadcaster || ExecutionProgressBroadcaster.new
  end
end

# ❌ Caller doesn't know what's required
service = ExecutionOrchestrationService.new  # Works but wrong!
```

**Good Example:**

```ruby
# typed: strict
# ✅ Explicit, deterministic dependencies
class ExecutionOrchestrationService
  extend T::Sig
  
  sig { params(state_store: StateStore, broadcaster: Broadcaster).void }
  def initialize(state_store:, broadcaster:)
    @id = T.let(UUID.generate, UUID)
    raise TypeError unless state_store.is_a?(StateStore)
    raise TypeError unless broadcaster.is_a?(Broadcaster)
    
    @state_store = T.let(state_store, StateStore)
    @broadcaster = T.let(broadcaster, Broadcaster)
  end
end

# ✅ Dependencies explicit at call site
service = ExecutionOrchestrationService.new(
  state_store: StateStore.new,
  broadcaster: EventBroadcaster.new
)
```

**Why**: No fallbacks means missing dependencies fail immediately at construction, not later during execution. Explicit dependencies make requirements clear.

---

### [SVC][!EXPLICIT-PARAMS-NO-SPLATS]

**Rule**: Define explicit named parameters. No `**params`, `**options`, or catch-all hashes.

**Bad Example:**

```ruby
# ❌ Catch-all hides what's actually needed
def create_entity(**params)
  # What parameters are valid? Unknown!
  entity = Entity.new(**params)
end

def configure(options: {})
  # What options exist? Unknown!
  @timeout = options[:timeout] || 30
end
```

**Good Example:**

```ruby
# typed: strict
# ✅ Explicit parameters are self-documenting
sig { params(name: String, entity_type: String, metadata: T::Hash[Symbol, String]).returns(Entity) }
def create_entity(name:, entity_type:, metadata:)
  raise TypeError unless name.is_a?(String)
  raise TypeError unless entity_type.is_a?(String)
  raise TypeError unless metadata.is_a?(Hash)
  
  Entity.new(
    id: UUID.generate,
    name: name,
    entity_type: entity_type,
    metadata: metadata
  )
end

# ✅ Use T::Struct for complex options
class ServiceOptions < T::Struct
  const :timeout, Integer, default: 30
  const :retry_count, Integer, default: 3
end

sig { params(options: ServiceOptions).void }
def configure(options:)
  @timeout = options.timeout
  @retry_count = options.retry_count
end
```

**Why**: Explicit parameters make method contracts clear. IDEs can autocomplete. Type checkers can verify. No guessing what's valid.

---

## Summary

**Key Principles:**

1. **Thin controllers** - Delegate to services, handle only HTTP
2. **Business logic in services** - Coordinate models, external APIs
3. **Explicit dependencies** - No defaults, fail fast on missing deps
4. **Explicit parameters** - No splats, no catch-all hashes
5. **Return domain objects** - Not hashes, use serializers for JSON
6. **Clear naming** - `*Service`, `*Store`, `*Broadcaster`

**Benefits:**

- Thin, focused controllers
- Reusable business logic
- Testable in isolation
- Clear responsibilities
- Self-documenting method signatures
- Fast failure on missing dependencies

