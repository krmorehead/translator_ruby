---
description: API design patterns for thin controllers with serializers
globs: app/controllers/**/*_controller.rb
alwaysApply: false
---

# API Design Patterns

**Tags**: [architecture, coding, back_end]  
**Applies To**: Rails API controllers  
**Date**: 2026-01-06

## Overview

APIs should be thin, focused layers that validate input, delegate to services, and serialize output. Controllers should never contain business logic - they are purely interface adapters.

## API Architecture

```
API Request Flow
│
├── Controller (thin adapter layer)
│   ├── 1. Validate params
│   │   ├── Use strong parameters
│   │   ├── Type check required fields
│   │   └── Fail fast on invalid input
│   │
│   ├── 2. Call service
│   │   ├── Pass validated params
│   │   ├── Service contains all business logic
│   │   └── Service returns domain objects
│   │
│   └── 3. Serialize response
│       ├── Use serializer class
│       ├── Serializer converts model → JSON
│       └── Return structured JSON
│
└── Three Responsibilities Only
    ├── Validate input
    ├── Delegate to service
    └── Serialize output

Anti-patterns to Avoid:
├── ❌ Business logic in controllers
├── ❌ Direct model manipulation
├── ❌ Inline JSON building
└── ❌ Service instantiation without DI
```

---

## Rules

### [API][!THIN-CONTROLLERS]

**Rule**: Controllers validate params, call services, and serialize. Nothing else.

**Bad Example:**

```ruby
# typed: strict
# ❌ Fat controller with business logic
class Api::ExecutionsController < ApplicationController
  extend T::Sig
  
  sig { void }
  def create
    goal = params["goal"]
    priority = params["priority"]
    
    # ❌ Business logic in controller!
    execution = Execution.new(status: :pending)
    execution.validate_goal(goal)
    execution.set_priority(priority)
    execution.save!
    
    # ❌ Broadcasting in controller!
    ExecutionBroadcaster.new.publish(execution)
    
    # ❌ Inline JSON building!
    render json: {
      id: execution.id.to_s,
      status: execution.status.to_s,
      created_at: execution.created_at.iso8601
    }
  end
end
```

**Good Example:**

```ruby
# typed: strict
# ✅ Thin controller - validate, delegate, serialize
class Api::ExecutionsController < ApplicationController
  extend T::Sig
  
  sig { void }
  def create
    # 1. Validate params
    validated_params = validate_execution_params
    
    # 2. Call service
    service = ExecutionService.new(
      state_store: StateStore.new,
      broadcaster: ExecutionBroadcaster.new
    )
    execution = service.create(
      goal: validated_params["goal"],
      priority: validated_params["priority"]
    )
    
    # 3. Serialize response
    render json: ExecutionSerializer.show(execution: execution), status: :created
  end
  
  private
  
  sig { returns(ActionController::Parameters) }
  def validate_execution_params
    params.require(:execution).permit(:goal, :priority)
  end
end
```

**Why**: Thin controllers are easy to test, change, and understand. Business logic stays in services.

---

### [API][!VALIDATE-PARAMS]

**Rule**: Always validate and type-check parameters. Use strong parameters and string access.

**Good Example:**

```ruby
# typed: strict
class Api::ExecutionsController < ApplicationController
  extend T::Sig
  
  sig { void }
  def show
    # Validate ID format
    execution_id = validate_uuid(params["id"])
    
    # Service call
    service = ExecutionService.new(state_store: StateStore.new)
    execution = service.find(execution_id: execution_id)
    
    render json: ExecutionSerializer.show(execution: execution)
  end
  
  sig { void }
  def create
    # Validate required params
    validated_params = validate_execution_params
    
    goal = validated_params["goal"]
    priority = validated_params["priority"].to_i
    
    # Type validation
    raise ArgumentError, "goal must be a string" unless goal.is_a?(String)
    raise ArgumentError, "priority must be positive" unless priority > 0
    
    service = ExecutionService.new(
      state_store: StateStore.new,
      broadcaster: ExecutionBroadcaster.new
    )
    execution = service.create(goal: goal, priority: priority)
    
    render json: ExecutionSerializer.show(execution: execution), status: :created
  end
  
  private
  
  sig { params(id_string: String).returns(UUID) }
  def validate_uuid(id_string)
    UUID.parse(id_string)
  rescue ArgumentError => e
    render json: { error: "Invalid UUID: #{e.message}" }, status: :bad_request
    raise
  end
  
  sig { returns(ActionController::Parameters) }
  def validate_execution_params
    params.require(:execution).permit(:goal, :priority)
  end
end
```

**Why**: Validation at the API boundary prevents invalid data from entering the system. Use string access for params.

---

### [API][!STRING-ACCESS]

**Rule**: Always use string keys for parameter access. Use ActionController::Parameters directly.

**Good Example:**

```ruby
# ✅ String access with ActionController::Parameters
validated_params = params.require(:execution).permit(:goal, :priority)
goal = validated_params["goal"]
priority = validated_params["priority"]
```

**Why**: String access keeps parameter handling consistent with Rails conventions and external API patterns. ActionController::Parameters provides string access by default.

---

### [API][!SERVICE-DELEGATION]

**Rule**: Controllers instantiate services and delegate all business logic. Never manipulate models directly.

**Bad Example:**

```ruby
# ❌ Direct model manipulation
def update
  execution = Execution.find(params["id"])
  execution.status = params["status"]
  execution.updated_by = current_user.id
  execution.save!
  
  # ❌ Side effects in controller
  ExecutionBroadcaster.new.publish(execution)
  
  # ❌ Inline JSON!
  render json: { id: execution.id, status: execution.status }
end
```

**Good Example:**

```ruby
# typed: strict
# ✅ Service handles all logic
sig { void }
def update
  execution_id = validate_uuid(params["id"])
  new_status = params["status"].to_sym
  
  service = ExecutionService.new(
    state_store: StateStore.new,
    broadcaster: ExecutionBroadcaster.new
  )
  
  execution = service.update_status(
    execution_id: execution_id,
    status: new_status,
    updated_by: current_user_id
  )
  
  render json: ExecutionSerializer.show(execution: execution)
end

private

sig { returns(UUID) }
def current_user_id
  UUID.parse(current_user.id)
end
```

**Why**: Services encapsulate business logic and side effects. Controllers remain simple adapters.

---

### [API][!SERIALIZER-RESPONSE]

**Rule**: Always use serializer classes for JSON responses. Never inline JSON building.

**Bad Example:**

```ruby
# ❌ Inline JSON building
def show
  execution = Execution.find(params["id"])
  
  render json: {
    id: execution.id.to_s,
    status: execution.status,
    goal: execution.goal,
    created_at: execution.created_at.iso8601,
    metadata: execution.metadata
  }
end

# ❌ Inline JSON
def index
  executions = Execution.all
  render json: executions.map { |ex| { id: ex.id, status: ex.status } }
end
```

**Good Example:**

```ruby
# typed: strict
# ✅ Serializer class handles JSON structure
sig { void }
def show
  execution_id = validate_uuid(params["id"])
  
  service = ExecutionService.new(state_store: StateStore.new)
  execution = service.find(execution_id: execution_id)
  
  render json: ExecutionSerializer.show(execution: execution)
end

sig { void }
def index
  service = ExecutionService.new(state_store: StateStore.new)
  executions = service.list
  
  render json: ExecutionSerializer.index(executions: executions)
end
```

**Why**: Serializers centralize JSON structure, making API contracts explicit and testable.

---

### [API][!ERROR-HANDLING]

**Rule**: Handle errors at the controller level. Return appropriate HTTP status codes.

**Good Example:**

```ruby
# typed: strict
class Api::ExecutionsController < ApplicationController
  extend T::Sig
  
  rescue_from ArgumentError, with: :handle_bad_request
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  
  sig { void }
  def show
    execution_id = validate_uuid(params["id"])
    
    service = ExecutionService.new(state_store: StateStore.new)
    execution = service.find(execution_id: execution_id)
    
    render json: ExecutionSerializer.show(execution: execution)
  end
  
  private
  
  sig { params(error: ArgumentError).void }
  def handle_bad_request(error)
    render json: { error: error.message }, status: :bad_request
  end
  
  sig { params(error: ActiveRecord::RecordNotFound).void }
  def handle_not_found(error)
    render json: { error: "Resource not found" }, status: :not_found
  end
end
```

**Why**: Consistent error responses and appropriate status codes make APIs predictable.

---

## Patterns

### Pattern: Complete CRUD API

```ruby
# typed: strict

class Api::ExecutionsController < ApplicationController
  extend T::Sig
  
  rescue_from ArgumentError, with: :handle_bad_request
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  
  # GET /api/executions
  sig { void }
  def index
    service = ExecutionService.new(state_store: StateStore.new)
    executions = service.list
    
    render json: executions.map { |ex| ExecutionSerializer.new(ex).as_json }
  end
  
  # GET /api/executions/:id
  sig { void }
  def show
    execution_id = validate_uuid(params["id"])
    
    service = ExecutionService.new(state_store: StateStore.new)
    execution = service.find(execution_id: execution_id)
    
    render json: ExecutionSerializer.new(execution).as_json
  end
  
  # POST /api/executions
  sig { void }
  def create
    validated_params = validate_execution_params
    
    service = ExecutionService.new(
      state_store: StateStore.new,
      broadcaster: ExecutionBroadcaster.new
    )
    
    execution = service.create(
      goal: validated_params["goal"],
      priority: validated_params["priority"].to_i
    )
    
    render json: ExecutionSerializer.new(execution).as_json, status: :created
  end
  
  # PATCH /api/executions/:id
  sig { void }
  def update
    execution_id = validate_uuid(params["id"])
    validated_params = validate_execution_params
    
    service = ExecutionService.new(
      state_store: StateStore.new,
      broadcaster: ExecutionBroadcaster.new
    )
    
    execution = service.update(
      execution_id: execution_id,
      goal: validated_params["goal"],
      priority: validated_params["priority"]&.to_i
    )
    
    render json: ExecutionSerializer.new(execution).as_json
  end
  
  # DELETE /api/executions/:id
  sig { void }
  def destroy
    execution_id = validate_uuid(params["id"])
    
    service = ExecutionService.new(
      state_store: StateStore.new,
      broadcaster: ExecutionBroadcaster.new
    )
    
    service.delete(execution_id: execution_id)
    
    head :no_content
  end
  
  private
  
  sig { params(id_string: String).returns(UUID) }
  def validate_uuid(id_string)
    UUID.parse(id_string)
  end
  
  sig { returns(ActionController::Parameters) }
  def validate_execution_params
    params.require(:execution).permit(:goal, :priority)
  end
  
  sig { params(error: ArgumentError).void }
  def handle_bad_request(error)
    render json: { error: error.message }, status: :bad_request
  end
  
  sig { params(error: ActiveRecord::RecordNotFound).void }
  def handle_not_found(error)
    render json: { error: "Resource not found" }, status: :not_found
  end
end
```

---

## Checklist

- [ ] Controllers have no business logic
- [ ] All params validated with strong parameters
- [ ] String access for all params (no symbol keys)
- [ ] Type checking on required fields
- [ ] Services instantiated with dependency injection
- [ ] All business logic delegated to services
- [ ] Serializer classes used for all JSON responses
- [ ] No serialization methods on models
- [ ] Appropriate HTTP status codes
- [ ] Error handling with rescue_from
- [ ] UUID validation for IDs
- [ ] Every action follows: validate → delegate → serialize

---

## Summary

**Key Principles:**

1. **Thin controllers** - Validate, delegate, serialize only
2. **Strong parameters** - Use permit/require for validation
3. **Service delegation** - All business logic in services
4. **Serializer classes** - Explicit JSON structure
5. **Error handling** - Consistent status codes and messages
6. **No model serialization** - Models have no JSON methods

**Benefits:**

- Easy to test (minimal controller logic)
- Easy to change (business logic isolated)
- Consistent API responses
- Clear separation of concerns
- Type-safe with Sorbet

**When to Use:**

- All API endpoints
- Any JSON responses
- RESTful resources
- Service-oriented architecture

