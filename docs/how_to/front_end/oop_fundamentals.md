---
description: Core OOP patterns for TypeScript/React frontend development
globs: app/frontend/**/*.{ts,tsx}
alwaysApply: false
---

# Core OOP Patterns (Frontend)

**Tags**: [coding, design, front_end]  
**Applies To**: TypeScript/JavaScript applications  
**Date**: 2026-01-06

## Overview

Core OOP patterns for TypeScript/JavaScript prioritizing type safety, single responsibility, and fail-fast validation. Eliminate plain object state, enforce strict validation, and make code predictable and maintainable.

## OOP Fundamentals Pattern

```
Domain Model Architecture (TypeScript)
│
├── Value Objects (no identity)
│   ├── Properties: Validated in constructor
│   ├── Behavior: Query methods, calculations
│   └── Examples: Money, Address, DateRange, Coordinates
│
├── Entity Objects (identity, lifecycle)
│   ├── Properties: Unique identifier, mutable state
│   ├── Behavior: State transitions, query methods
│   └── Examples: User, Execution, Session, Task
│
├── Service Classes (single responsibility)
│   ├── Purpose: Coordinate operations, orchestrate workflows
│   ├── Pattern: Stateless, dependency injection
│   └── Examples: ApiClient, StateManager, EventBus
│
├── Composition Over Inheritance
│   └── Compose behavior from capabilities rather than inherit
│
└── Base Class Pattern (when needed)
    ├── Base class provides common functionality
    ├── Subclasses extend with domain-specific behavior
    └── Always call super() explicitly

Validation Strategy:
Constructor Validation (fail fast)
├── Type validation: TypeScript interfaces/types
├── Value validation: Runtime checks
└── Business validation: Domain rules

Pattern Comparison:
├── ❌ Plain Object State
│   ├── No type methods
│   ├── Typos not caught at runtime
│   └── No encapsulation
│
├── ❌ Positional Parameters
│   ├── Not self-documenting
│   ├── Order-dependent
│   └── Refactoring danger
│
└── ✅ Proper Class
    ├── Type safe
    ├── Methods available
    └── Encapsulated state
```

---

## Rules

### [FE-OOP][!CLASSES-WITH-NAMED-PARAMS]

**Rule**: Always use classes with named parameters (destructured). Never use plain objects or positional parameters.

**Bad Example:**

```typescript
// ❌ Plain object + positional parameters
const execution = {
  id: crypto.randomUUID(),
  status: 'pending',
  metadata: {}
};
execution.statu = 'complete';  // Typo not caught at runtime!

class ExecutionService {
  constructor(store: StateStore, broadcaster: Broadcaster) {  // ❌ Positional
    this.store = store;
  }
  
  create(goal: string, priority: number) {  // ❌ What's the order?
    this.store.save(goal, priority);
  }
}

service.create("Goal", 1);  // Is it (goal, priority) or (priority, goal)?
```

**Good Example:**

```typescript
// ✅ Proper class with named parameters
type ExecutionStatus = 'pending' | 'running' | 'complete' | 'failed';

interface ExecutionParams {
  status?: ExecutionStatus;
  metadata?: Record<string, string>;
}

class Execution {
  private _id: string;
  private _status: ExecutionStatus;
  private _metadata: Record<string, string>;
  
  static readonly STATUSES: readonly ExecutionStatus[] = 
    ['pending', 'running', 'complete', 'failed'] as const;
  
  constructor({ status = 'pending', metadata = {} }: ExecutionParams = {}) {
    this._id = crypto.randomUUID();  // First line always
    this._status = status;
    this._metadata = metadata;
  }
  
  get id(): string { return this._id; }
  get status(): ExecutionStatus { return this._status; }
  get metadata(): Record<string, string> { return { ...this._metadata }; }
  
  start(): Execution {
    return new Execution({ status: 'running', metadata: this._metadata });
  }
}

interface ExecutionServiceParams {
  store: StateStore;
  broadcaster: Broadcaster;
}

class ExecutionService {
  private _id: string;
  private store: StateStore;
  private broadcaster: Broadcaster;
  
  constructor({ store, broadcaster }: ExecutionServiceParams) {  // ✅ Named
    this._id = crypto.randomUUID();
    this.store = store;
    this.broadcaster = broadcaster;
  }
  
  create({ goal, priority }: { goal: string; priority: number }): Execution {  // ✅ Named
    const execution = new Execution();
    this.store.save({ execution });
    return execution;
  }
}

// ✅ Crystal clear - order doesn't matter
const service = new ExecutionService({ 
  store: new StateStore(), 
  broadcaster: new Broadcaster() 
});
service.create({ goal: "Add feature", priority: 1 });
service.create({ priority: 1, goal: "Add feature" });  // Same result!
```

**Why**: Classes provide type safety and catch typos. Named parameters prevent order mistakes, enable safe refactoring, and make code self-documenting.

---

### [FE-OOP][!VALIDATE-AND-FAIL-FAST]

**Rule**: Validate all parameters in constructors. Throw errors for missing required fields. Let errors happen loudly.

**Bad Example:**

```typescript
// ❌ No validation + silent undefined
class Goal {
  constructor(text: string, priority: number) {
    this.text = text;  // Accepts null
    this.priority = priority;  // Accepts anything
  }
}

const config = json.config;  // undefined if missing
const capabilities = config?.capabilities;  // undefined on undefined

// ❌ Conditional safety masks bugs
if (BrowserTool.browser) {
  BrowserTool.browser.quit();
}
```

**Good Example:**

```typescript
// ✅ Strict validation + fail fast
type Priority = 1 | 2 | 3;

interface GoalParams {
  text: string;
  priority: Priority;
}

class Goal {
  private _id: string;
  private _text: string;
  private _priority: Priority;
  
  static readonly PRIORITIES: readonly Priority[] = [1, 2, 3] as const;
  
  constructor({ text, priority }: GoalParams) {
    this._id = crypto.randomUUID();
    
    if (typeof text !== 'string') {
      throw new TypeError(`text must be string, got ${typeof text}`);
    }
    if (!Goal.PRIORITIES.includes(priority)) {
      throw new TypeError(`priority must be 1-3, got ${priority}`);
    }
    
    this._text = text;
    this._priority = priority;
  }
  
  get text(): string { return this._text; }
  get priority(): Priority { return this._priority; }
}

// ✅ Explicit checks fail loud
if (!json.config) {
  throw new Error('Missing required field: config');
}
const config = json.config;

if (!config.capabilities) {
  throw new Error('Missing required field: capabilities');
}
const capabilities = config.capabilities;

// ✅ Let methods fail loud
BrowserTool.browser.quit();  // Fails if not in expected state
```

**Why**: Early validation catches bugs at source. Explicit error throwing makes missing data obvious immediately. Silent undefined and conditional safety hide problems.

---

### [FE-OOP][!SINGLE-RESPONSIBILITY]

**Rule**: Each class has ONE clear purpose. Split classes that do multiple things.

**Bad Example:**

```typescript
// ❌ God class doing everything
class UserManager {
  createUser(data: any): void {
    // Validation, API call, state update, notifications, analytics, cache...
  }
}
```

**Good Example:**

```typescript
// ✅ Single responsibilities
interface UserParams {
  name: string;
  email: string;
}

class User {
  private _id: string;
  private _name: string;
  private _email: string;
  
  constructor({ name, email }: UserParams) {
    this._id = crypto.randomUUID();
    this._name = name;
    this._email = email;
  }
  
  get id(): string { return this._id; }
  get name(): string { return this._name; }
  get email(): string { return this._email; }
}

class UserRepository {
  async save({ user }: { user: User }): Promise<void> {
    // API call only
  }
}

class UserNotificationService {
  notifyWelcome({ user }: { user: User }): void {
    // Notification only
  }
}
```

**Why**: Small, focused classes are easier to test, understand, and modify.

---

### [FE-OOP][!COMPOSITION-OVER-INHERITANCE]

**Rule**: Compose behavior from capabilities. Use inheritance only for true "is-a" relationships.

**Bad Example:**

```typescript
// ❌ Deep inheritance breaks contracts
class Bird extends Animal {
  fly(): string {
    return "flying";
  }
}

class Penguin extends Bird {
  fly(): string {
    throw new Error("Penguins can't fly");  // Breaking parent!
  }
}
```

**Good Example:**

```typescript
// ✅ Composition with capabilities
class Capability {
  private _id: string;
  
  constructor() {
    this._id = crypto.randomUUID();
  }
  
  perform(): string {
    return "default";
  }
}

class Flight extends Capability {
  perform(): string {
    return "flying";
  }
}

class Swimming extends Capability {
  perform(): string {
    return "swimming";
  }
}

interface AnimalParams {
  capabilities?: Capability[];
}

class Animal {
  private _id: string;
  private _capabilities: Capability[];
  
  constructor({ capabilities = [] }: AnimalParams = {}) {
    this._id = crypto.randomUUID();
    this._capabilities = capabilities;
  }
  
  get capabilities(): Capability[] {
    return [...this._capabilities];
  }
}

const bird = new Animal({ capabilities: [new Flight()] });
const penguin = new Animal({ capabilities: [new Swimming()] });
```

**Why**: Composition is flexible and avoids inheritance problems.

---

### [FE-OOP][!ENCAPSULATION]

**Rule**: Use private fields (`_prefix`) and public getters for read-only access. Provide methods for state changes.

**Good Example:**

```typescript
interface ConfigurationParams {
  apiKey: string;
  endpoint: string;
  timeout?: number;
}

class Configuration {
  private _id: string;
  private _apiKey: string;
  private _endpoint: string;
  private _timeout: number;
  
  constructor({ apiKey, endpoint, timeout = 30 }: ConfigurationParams) {
    this._id = crypto.randomUUID();
    this._apiKey = apiKey;
    this._endpoint = endpoint;
    this._timeout = timeout;
  }
  
  get id(): string { return this._id; }
  get apiKey(): string { return this._apiKey; }
  get endpoint(): string { return this._endpoint; }
  get timeout(): number { return this._timeout; }
  
  updateTimeout({ timeout }: { timeout: number }): void {
    this._timeout = timeout;
  }
}

const config = new Configuration({ apiKey: "key", endpoint: "url" });
config.updateTimeout({ timeout: 5 });
```

**Why**: Encapsulation provides controlled access without exposing internal structure.

---

## Pattern: Value Object

```typescript
interface MoneyParams {
  amount: number;
  currency: string;
}

class Money {
  private _id: string;
  private _amount: number;
  private _currency: string;
  
  static readonly CURRENCIES = ['USD', 'EUR', 'GBP'] as const;
  
  constructor({ amount, currency }: MoneyParams) {
    this._id = crypto.randomUUID();
    
    if (typeof amount !== 'number' || amount < 0) {
      throw new TypeError(`amount must be positive number, got ${amount}`);
    }
    
    const upperCurrency = currency.toUpperCase();
    if (!Money.CURRENCIES.includes(upperCurrency as any)) {
      throw new TypeError(`currency must be USD/EUR/GBP, got ${currency}`);
    }
    
    this._amount = amount;
    this._currency = upperCurrency;
  }
  
  get amount(): number { return this._amount; }
  get currency(): string { return this._currency; }
  
  add({ other }: { other: Money }): Money {
    if (this._currency !== other.currency) {
      throw new Error('Cannot add different currencies');
    }
    return new Money({ 
      amount: this._amount + other.amount, 
      currency: this._currency 
    });
  }
  
  toString(): string {
    return `${this._amount} ${this._currency}`;
  }
}

const price = new Money({ amount: 19.99, currency: 'USD' });
const tax = new Money({ amount: 2.00, currency: 'USD' });
const total = price.add({ other: tax });
```

---

## Checklist

- [ ] Classes not plain objects for domain entities
- [ ] Named parameters (destructured) everywhere
- [ ] `crypto.randomUUID()` as first line in constructor
- [ ] Type validation in constructors
- [ ] Explicit errors for missing required fields
- [ ] Single responsibility per class
- [ ] Composition over inheritance
- [ ] Private fields (`_prefix`) with getters

---

## Summary

**Key Principles:**

1. **Classes with named params** - Never plain objects or positional parameters
2. **UUID first** - Every constructor starts with `crypto.randomUUID()`
3. **Validate strict** - Runtime type checks in constructors, fail fast
4. **Fail loud** - Explicit error throwing, no silent undefined or optional chaining
5. **Single responsibility** - One purpose per class
6. **Composition** - Avoid deep inheritance
7. **Encapsulation** - Private fields with getters

**Benefits:**

- Type safety prevents runtime errors
- Early validation catches bugs at source
- Small classes easier to test and maintain
- Clear responsibilities improve understanding
- Named parameters prevent order mistakes
- Encapsulation protects internal state

