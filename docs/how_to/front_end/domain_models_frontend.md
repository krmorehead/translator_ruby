---
description: Domain model patterns for frontend TypeScript classes
globs: app/frontend/models/**/*.ts
alwaysApply: false
---

# Frontend OOP Patterns

**Tags**: [coding, design, front_end]  
**Applies To**: JavaScript/TypeScript frontend applications  
**Date**: 2026-01-05

## Overview

Frontend domain models that mirror backend classes exactly, enabling type-safe operations and seamless TypeScript migration.

## Frontend Domain Model Tree

```
Frontend Models (JavaScript/TypeScript)
│
├── Base Classes
│   │
│   └── BaseEntity
│       ├── Static Constants:
│       │   ├── STATUS_PENDING = "pending"
│       │   ├── STATUS_ACTIVE = "active"
│       │   ├── STATUS_COMPLETE = "complete"
│       │   └── STATUS_FAILED = "failed"
│       │
│       ├── Constructor:
│       │   ├── Validates base params (id, status, createdAt)
│       │
│       ├── Common methods:
│       │   ├── isPending() → boolean
│       │   ├── isComplete() → boolean
│       │   └── toJSON() → object
│       │
│       └── Subclasses:
│           │
│           ├── WorkflowEntity extends BaseEntity
│           │   ├── Private fields:
│           │   │   ├── _id: string
│           │   │   ├── _type: string
│           │   │   ├── _status: string
│           │   │   ├── _parentId: string
│           │   │   ├── _sequenceNumber: number (optional)
│           │   │   ├── _createdAt: string
│           │   │   ├── _resolvedBy: string (optional)
│           │   │   └── _resolvedAt: string (optional)
│           │   │
│           │   ├── Constructor:
│           │   │   ├── super({id, status, createdAt})
│           │   │   ├── Validate: type is valid
│           │   │   └── Validate: parentId present
│           │   │
│           │   ├── Getters (read-only):
│           │   │   ├── get id() { return this._id; }
│           │   │   ├── get type() { return this._type; }
│           │   │   ├── get status() { return this._status; }
│           │   │   ├── get parentId() { return this._parentId; }
│           │   │   └── get sequenceNumber() { return this._sequenceNumber; }
│           │   │
│           │   ├── Query methods:
│           │   │   ├── isPending() { return this._status === STATUS_PENDING; }
│           │   │   ├── isActive() { return this._status === STATUS_ACTIVE; }
│           │   │   ├── isComplete() { return this._status === STATUS_COMPLETE; }
│           │   │   └── isResolved() { return this.isComplete() || this.isFailed(); }
│           │   │
│           │   ├── Mutation methods:
│           │   │   ├── activate(userId) → updates this._status
│           │   │   │     sets this._activatedBy
│           │   │   │     status: STATUS_ACTIVE,
│           │   │   │     resolvedBy: userId,
│           │   │   │     resolvedAt: new Date().toISOString()
│           │   │   │   })
│           │   │   │
│           │   │   └── complete(result) → new WorkflowEntity({
│           │   │         ...this.toJSON(),
│           │   │         status: STATUS_COMPLETE,
│           │   │         result: result,
│           │   │         resolvedAt: new Date().toISOString()
│           │   │       })
│           │   │
│           │   ├── Serialization:
│           │   │   ├── toJSON() → {
│           │   │   │     id: this._id,
│           │   │   │     type: this._type,
│           │   │   │     status: this._status,
│           │   │   │     parentId: this._parentId,
│           │   │   │     sequenceNumber: this._sequenceNumber,
│           │   │   │     resolvedBy: this._resolvedBy,
│           │   │   │     resolvedAt: this._resolvedAt
│           │   │   │   }
│           │   │   │
│           │   │   └── static fromJSON(json) → new WorkflowEntity({
│           │   │         id: json.id,
│           │   │         type: json.type,
│           │   │         status: json.status,
│           │   │         ...
│           │   │       })
│           │   │
│           │   └── Validation in constructor:
│           │       ├── if (!id) throw new Error('id required')
│           │       ├── if (!VALID_TYPES.includes(type)) throw new Error('invalid type')
│           │       └── if (!parentId) throw new Error('parentId required')
│           │
│           └── StateEntity extends BaseEntity
│               ├── Fields: id, status, path, metadata, startedAt
│               ├── Methods: isPending(), isActive(), isComplete(), isFailed()
│               └── Similar structure to WorkflowEntity
│
├── Entity Models (with identity)
│   │
│   ├── Session
│   │   ├── Private fields:
│   │   │   ├── _sessionId: string
│   │   │   ├── _sessionType: string
│   │   │   ├── _status: "active" | "closed"
│   │   │   ├── _startedAt: Date
│   │   │   └── _items: Array<Item>
│   │   │
│   │   ├── Constructor:
│   │   │   ├── Validate: sessionId present
│   │   │   └── Validate: sessionType in VALID_TYPES
│   │   │
│   │   ├── Methods:
│   │   │   ├── isActive() → boolean
│   │   │   ├── addItem(item) → new Session(...)
│   │   │   └── close() → new Session({..., status: "closed"})
│   │   │
│   │   └── Serialization:
│   │       ├── toJSON() → {...}
│   │       └── static fromJSON(json) → new Session(...)
│   │
│   ├── Message
│   │   ├── Fields: id, role, content, timestamp
│   │   └── Methods: isUser(), isAssistant(), isSystem()
│   │
│   └── Task
│       ├── Fields: id, status, description, metadata
│       └── Methods: isPending(), isActive(), isComplete()
│
├── Value Objects (no identity)
│   │
│   ├── Snapshot
│   │   ├── Fields: id, description, timestamp, metadata, changes
│   │   └── Methods: hasChanges(), getChangeCount()
│   │
│   └── Action
│       ├── Fields: id, name, parameters, result
│       └── Methods: isComplete(), hasError()
│
├── Factory Pattern
│   │
│   └── WorkflowEntityFactory
│       ├── static buildStep(params) → WorkflowEntity
│       │   └── new WorkflowEntity({
│       │         id: `approval-${Date.now()}`,
│       │         type: 'step',
│       │         status: WorkflowEntity.STATUS_PENDING,
│       │         executionId: params.executionId,
│       │         stepNumber: params.stepNumber,
│       │         createdAt: new Date().toISOString()
│       │       })
│       │
│       └── static buildMilestone(params) → WorkflowEntity
│           └── new WorkflowEntity({
│                 id: `approval-${Date.now()}`,
│                 type: 'milestone',
│                 status: WorkflowEntity.STATUS_PENDING,
│                 executionId: params.executionId,
│                 milestoneNumber: params.milestoneNumber,
│                 createdAt: new Date().toISOString()
│               })
│
└── Usage Example Flow
    │
    ├── 1. API returns JSON:
    │   {
    │     id: "entity-123",
    │     type: "workflow",
    │     status: "pending",
    │     parent_id: "parent-456",
    │     sequence_number: 1
    │   }
    │
    ├── 2. Deserialize to domain object:
    │   const entity = WorkflowEntity.fromJSON(json);
    │
    ├── 3. Use methods (type-safe):
    │   if (entity.isPending()) {
    │     showModal(entity);
    │   }
    │
    ├── 4. Transform (mutates):
    │   entity.activate('user@example.com');
    │
    ├── 5. Verify state:
    │   console.log(entity.status);     // "active"
    │
    └── 6. Serialize for API:
        await fetch('/api/entities', {
          method: 'POST',
          body: JSON.stringify(entity.toJSON())
        });

Mirror Backend Example:
Backend (Ruby)                  Frontend (JavaScript)
┌─────────────────────┐        ┌──────────────────────┐
│ class WorkflowEntity          │ class WorkflowEntity {
│   STATUS_PENDING = "pending" │   static STATUS_PENDING = "pending"
│                               │
│   def pending?                │   isPending() {
│     @status == STATUS_PENDING │     return this._status ===
│   end                         │       WorkflowEntity.STATUS_PENDING;
│ end                           │   }
└─────────────────────┘        └──────────────────────┘

Perfect symmetry enables:
├── Shared understanding between frontend/backend
├── Easy TypeScript migration (add type annotations)
├── Consistent behavior across stack
└── Reduced cognitive load for developers
```

---

## Rules

### [FE-OOP][!MIRROR-BACKEND]

**Rule**: Frontend models MUST mirror backend structure exactly.

**Good Example:**

```typescript
// Backend (Ruby)
class WorkflowEntity
  STATUS_PENDING = "pending"
  
  def pending?
    @status == STATUS_PENDING
  end
end

// Frontend (TypeScript) - EXACT MIRROR
type WorkflowStatus = 'pending' | 'running' | 'complete';

export class WorkflowEntity {
  static readonly STATUS_PENDING: WorkflowStatus = "pending";
  
  private readonly _status: WorkflowStatus;
  
  constructor(status: WorkflowStatus) {
    this._status = status;
  }
  
  get status(): WorkflowStatus {
    return this._status;
  }
  
  isPending(): boolean {
    return this._status === WorkflowEntity.STATUS_PENDING;
  }
}
```

**Why**: Perfect symmetry reduces cognitive load and type safety prevents errors.

---

### [FE-OOP][!NO-POSITIONAL-PARAMS]

**Rule**: Never use positional parameters. Always use destructured object parameters for all methods.

**Bad Example:**

```typescript
// ❌ Positional parameters - confusing and error-prone
class Execution {
  private _id: string;
  private _status: string;
  private _priority: number;
  
  constructor(id: string, status: string, priority: number) {  // ❌ Positional
    this._id = id;
    this._status = status;
    this._priority = priority;
  }
  
  update(status: string, priority: number): void {  // ❌ Positional - what order?
    this._status = status;
    this._priority = priority;
  }
}

// ❌ Calls are confusing - easy to mix up parameters
const execution = new Execution("123", "pending", 1);
execution.update("active", 2);  // Which is which?
```

**Good Example:**

```typescript
// ✅ Destructured object parameters everywhere
interface ExecutionParams {
  id: string;
  status: string;
  priority: number;
}

interface UpdateParams {
  status: string;
  priority: number;
}

class Execution {
  private _id: string;
  private _status: string;
  private _priority: number;
  
  constructor({ id, status, priority }: ExecutionParams) {  // ✅ Destructured
    this._id = id;
    this._status = status;
    this._priority = priority;
  }
  
  update({ status, priority }: UpdateParams): void {  // ✅ Destructured - self-documenting
    this._status = status;
    this._priority = priority;
  }
}

// ✅ Self-documenting calls - parameter order doesn't matter
const execution = new Execution({
  id: "123",
  status: "pending",
  priority: 1
});
execution.update({ status: "active", priority: 2 });  // Crystal clear!
execution.update({ priority: 2, status: "active" });  // Same result!
```

**Why**: Object parameters make code self-documenting, prevent mistakes, enable safe refactoring, and provide better IDE autocomplete.

---

### [FE-OOP][!VALIDATE-IN-CONSTRUCTOR]

**Rule**: Validate all parameters in constructor. Fail fast.

**Good Example:**

```typescript
type WorkflowStatus = 'pending' | 'running' | 'complete';
type WorkflowType = 'step' | 'milestone';

interface WorkflowEntityData {
  readonly status: WorkflowStatus;
  readonly type: WorkflowType;
  readonly executionId: string;
}

export class WorkflowEntity {
  private readonly _id: string;
  private readonly _status: WorkflowStatus;
  private readonly _type: WorkflowType;
  private readonly _executionId: string;

  constructor(data: WorkflowEntityData) {
    this._id = crypto.randomUUID();
    this._status = data.status;
    this._type = data.type;
    this._executionId = data.executionId;
  }
  
  get id(): string {
    return this._id;
  }
  
  get status(): WorkflowStatus {
    return this._status;
  }
  
  get type(): WorkflowType {
    return this._type;
  }
}
```

**Why**: Invalid objects can never exist. Errors caught immediately at construction.

---

### [FE-OOP][!GETTERS-ONLY]

**Rule**: Use getters for read-only access. No setters.

**Good Example:**

```javascript
class WorkflowEntity {
  constructor(params) {
    this._id = crypto.randomUUID();
    this._status = params.status;
  }
  
  get id() { return this._id; }
  get status() { return this._status; }
  
  // No setters - read-only
}

const approval = new WorkflowEntity({id: "123", status: "pending"});
approval.id = "456";  // TypeError: Cannot set property
```

**Why**: Read-only ID prevents accidental ID changes while allowing state mutations.

---

## Patterns

### Pattern: Base Class

```javascript
export class BaseRequest {
  static STATUS_PENDING = "pending";
  static STATUS_COMPLETE = "complete";
  
  constructor({ status, createdAt }) {
    this._id = crypto.randomUUID();
    
    this.validateBaseParams(id, status, createdAt);
    
    this._id = id;
    this._status = status;
    this._createdAt = createdAt;
    
  }
  
  // Common methods
  isPending() {
    throw new Error(`${this.constructor.name} must implement isPending()`);
  }
  
  toJSON() {
    throw new Error(`${this.constructor.name} must implement toJSON()`);
  }
  
  validateBaseParams(status, createdAt) {
    if (typeof status !== 'string') {
      throw new Error(`Invalid status type: ${typeof status}`);
    }
  }
}

export class WorkflowEntity extends BaseRequest {
  constructor(params) {
    super(params);
    
    if (!params.executionId) {
      throw new Error('executionId required');
    }
    
    this._executionId = params.executionId;
  }
  
  // Implement methods
  isPending(): boolean {
    return this.status === WorkflowEntity.STATUS_PENDING;
  }
  
  toJSON() {
    return {
      id: this._id,
      status: this._status,
      executionId: this._executionId,
      createdAt: this._createdAt
    };
  }
}
```

---

### Pattern: Factory

```javascript
export class WorkflowEntityFactory {
  static buildStep({ executionId, stepNumber }) {
    return new WorkflowEntity({
      id: `approval-${Date.now()}`,
      type: 'step',
      status: WorkflowEntity.STATUS_PENDING,
      executionId,
      stepNumber,
      createdAt: new Date().toISOString()
    });
  }
  
  static buildMilestone({ executionId, milestoneNumber }) {
    return new WorkflowEntity({
      id: `approval-${Date.now()}`,
      type: 'milestone',
      status: WorkflowEntity.STATUS_PENDING,
      executionId,
      milestoneNumber,
      createdAt: new Date().toISOString()
    });
  }
}

// Usage
const approval = WorkflowEntityFactory.buildStep({
  executionId: "exec-123",
  stepNumber: 1
});
```

---

## TypeScript Migration

Current JavaScript:
```javascript
class WorkflowEntity {
  constructor({ status }) {
    this._id = crypto.randomUUID();
    this._status = status;
  }
  
  get id() { return this._id; }
}
```

Future TypeScript (minimal changes):
```typescript
interface WorkflowEntityParams {
  id: string;
  status: 'pending' | 'approved' | 'rejected';
}

class WorkflowEntity {
  private readonly _id: string;
  private readonly _status: string;
  
  constructor({ status }: WorkflowEntityParams) {
    this._id = crypto.randomUUID();
    this._status = status;
  }
  
  get id(): string { return this._id; }
}
```

All validation already exists. Just add type annotations!

---

## Summary

**Key Principles:**

1. Mirror backend exactly
2. Validate in constructor
3. Getters for controlled access
4. Methods to mutate state
5. Base classes provide common functionality

**Benefits:**

- Type safety
- Perfect backend/frontend symmetry
- Easy TypeScript migration
- No accidental mutations
- Explicit state changes

**When to Use:**

- Any domain entity
- API response models
- State representations
- Value objects

