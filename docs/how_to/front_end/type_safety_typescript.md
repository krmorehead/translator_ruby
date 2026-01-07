---
description: TypeScript type safety patterns for frontend development
globs: "app/frontend/**/*.{ts,tsx}"
alwaysApply: false
---

# Type Safety with TypeScript

**Tags**: [coding, front_end]  
**Applies To**: React/JavaScript applications  
**Date**: 2026-01-06

## Overview

TypeScript provides static type checking for JavaScript, catching type errors at compile time. This document covers patterns for using TypeScript to ensure type safety across your frontend application with strict typing - no `any` or `unknown` types.

## TypeScript Type System

```
TypeScript Type Safety
│
├── Strict Mode Configuration
│   ├── "strict": true (all strict checks)
│   ├── "noImplicitAny": true
│   ├── "strictNullChecks": true
│   └── "strictFunctionTypes": true
│
├── Type Definitions
│   ├── Interfaces for object shapes
│   ├── Type aliases for unions/intersections
│   ├── Enums for constant sets
│   └── Generics for reusable types
│
├── Domain Model Types
│   ├── Entity interfaces
│   ├── Value object types
│   ├── Request/Response types
│   └── State types
│
├── Component Types
│   ├── Props interfaces
│   ├── State types
│   ├── Event handler types
│   └── Ref types
│
└── API Types
    ├── Request payloads
    ├── Response shapes
    ├── Error types
    └── SSE event types

Best Practices:
├── Never use 'any' - always explicit types
├── Never use 'unknown' - define the type
├── Use strict null checks (T | null)
├── Type all function parameters and returns
└── Use discriminated unions for variants
```

---

## Rules

### [TS][!NO-POSITIONAL-PARAMS]

**Rule**: Never use positional parameters. Always use destructured object parameters for clarity and safety.

**Bad Example:**

```typescript
// ❌ Positional parameters - unclear and error-prone
class ExecutionService {
  private _id: string;
  private _stateStore: StateStore;
  private _broadcaster: Broadcaster;
  
  constructor(stateStore: StateStore, broadcaster: Broadcaster) {  // ❌ Positional
    this._id = crypto.randomUUID();
    this._stateStore = stateStore;
    this._broadcaster = broadcaster;
  }
  
  create(goal: string, priority: number): Execution {  // ❌ Positional - what order?
    return new Execution(goal, priority);
  }
}

// ❌ Calls are confusing and easy to mix up
const service = new ExecutionService(stateStore, broadcaster);
service.create("Add feature", 1);  // Is it (goal, priority) or (priority, goal)?
```

**Good Example:**

```typescript
// ✅ Destructured object parameters everywhere
interface ExecutionServiceParams {
  stateStore: StateStore;
  broadcaster: Broadcaster;
}

interface CreateParams {
  goal: string;
  priority: number;
}

class ExecutionService {
  private _id: string;
  private _stateStore: StateStore;
  private _broadcaster: Broadcaster;
  
  constructor({ stateStore, broadcaster }: ExecutionServiceParams) {  // ✅ Destructured
    this._id = crypto.randomUUID();
    this._stateStore = stateStore;
    this._broadcaster = broadcaster;
  }
  
  create({ goal, priority }: CreateParams): Execution {  // ✅ Destructured - self-documenting
    return new Execution({ goal, priority });
  }
}

// ✅ Self-documenting calls - parameter order doesn't matter
const service = new ExecutionService({
  stateStore: new StateStore(),
  broadcaster: new ExecutionBroadcaster()
});
service.create({ goal: "Add feature", priority: 1 });  // Crystal clear!
service.create({ priority: 1, goal: "Add feature" });  // Same result!
```

**Why**: Object parameters make code self-documenting, prevent parameter order mistakes, enable safe refactoring, and provide better IDE autocomplete support.

---

### [TS][!STRICT-MODE]

**Rule**: Enable all strict TypeScript checks. Never use `any` or `unknown`.

**tsconfig.json:**

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "strictPropertyInitialization": true,
    "noImplicitThis": true,
    "alwaysStrict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true
  }
}
```

**Why**: Strict mode catches all type errors at compile time, preventing runtime bugs.

---

### [TS][!DOMAIN-INTERFACES]

**Rule**: Define explicit interfaces for all domain models. Mirror backend types exactly.

**Good Example:**

```typescript
// Types for domain model
interface ExecutionMetadata {
  readonly createdBy: string;
  readonly priority: number;
}

interface ExecutionData {
  readonly id: string;
  readonly status: ExecutionStatus;
  readonly startedAt: Date;
  readonly metadata: ExecutionMetadata;
}

// Status as discriminated union
type ExecutionStatus = 'pending' | 'running' | 'complete' | 'failed';

// Domain class with typed properties
export class Execution {
  private readonly _id: string;
  private readonly _status: ExecutionStatus;
  private readonly _startedAt: Date;
  private readonly _metadata: ExecutionMetadata;

  constructor(data: ExecutionData) {
    this._id = data.id;
    this._status = data.status;
    this._startedAt = data.startedAt;
    this._metadata = data.metadata;
  }

  get id(): string {
    return this._id;
  }

  get status(): ExecutionStatus {
    return this._status;
  }

  get startedAt(): Date {
    return this._startedAt;
  }

  get metadata(): ExecutionMetadata {
    return this._metadata;
  }

  isPending(): boolean {
    return this._status === 'pending';
  }

  isRunning(): boolean {
    return this._status === 'running';
  }

  toJSON(): ExecutionData {
    return {
      id: this._id,
      status: this._status,
      startedAt: this._startedAt,
      metadata: this._metadata
    };
  }

  static fromJSON(json: ExecutionData): Execution {
    return new Execution({
      id: json.id,
      status: json.status,
      startedAt: new Date(json.startedAt),
      metadata: json.metadata
    });
  }
}
```

**Why**: Explicit interfaces ensure type safety and make domain models self-documenting.

---

### [TS][!COMPONENT-PROPS]

**Rule**: Define props interfaces for all components. Never use inline types.

**Good Example:**

```typescript
// Separate interface for props
interface ExecutionCardProps {
  readonly execution: Execution;
  readonly onApprove: (executionId: string) => void;
  readonly onReject: (executionId: string, reason: string) => void;
  readonly className?: string;
}

// Component with typed props
export const ExecutionCard: React.FC<ExecutionCardProps> = ({
  execution,
  onApprove,
  onReject,
  className
}) => {
  const handleApprove = (): void => {
    onApprove(execution.id);
  };

  const handleReject = (): void => {
    const reason = prompt('Rejection reason:');
    if (reason !== null) {
      onReject(execution.id, reason);
    }
  };

  return (
    <div className={className}>
      <h3>{execution.id}</h3>
      <p>Status: {execution.status}</p>
      <button onClick={handleApprove}>Approve</button>
      <button onClick={handleReject}>Reject</button>
    </div>
  );
};
```

**Why**: Separate prop interfaces make components reusable and type-safe.

---

### [TS][!API-TYPES]

**Rule**: Define types for all API requests and responses. Never trust external data without validation.

**Good Example:**

```typescript
// API Response types
interface ExecutionResponse {
  readonly id: string;
  readonly status: string;
  readonly started_at: string;
  readonly metadata: Record<string, string>;
}

interface ApiSuccessResponse<T> {
  readonly success: true;
  readonly data: T;
}

interface ApiErrorResponse {
  readonly success: false;
  readonly error: {
    readonly message: string;
    readonly code: string;
  };
}

type ApiResponse<T> = ApiSuccessResponse<T> | ApiErrorResponse;

// API Client with typed methods
export class ExecutionAPI {
  private readonly baseUrl: string;

  constructor(baseUrl: string) {
    this._id = crypto.randomUUID();
    this.baseUrl = baseUrl;
  }

  async fetchExecution(id: string): Promise<Execution> {
    const response = await fetch(`${this.baseUrl}/executions/${id}`);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const json: ExecutionResponse = await response.json();
    
    return Execution.fromJSON({
      id: json.id,
      status: this.validateStatus(json.status),
      startedAt: new Date(json.started_at),
      metadata: this.validateMetadata(json.metadata)
    });
  }

  async createExecution(
    goal: string,
    priority: number
  ): Promise<ApiResponse<Execution>> {
    const response = await fetch(`${this.baseUrl}/executions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ goal, priority })
    });

    const json: ApiResponse<ExecutionResponse> = await response.json();

    if (!json.success) {
      return json;
    }

    return {
      success: true,
      data: Execution.fromJSON({
        id: json.data.id,
        status: this.validateStatus(json.data.status),
        startedAt: new Date(json.data.started_at),
        metadata: this.validateMetadata(json.data.metadata)
      })
    };
  }

  private validateStatus(status: string): ExecutionStatus {
    const validStatuses: ExecutionStatus[] = ['pending', 'running', 'complete', 'failed'];
    if (!validStatuses.includes(status as ExecutionStatus)) {
      throw new Error(`Invalid status: ${status}`);
    }
    return status as ExecutionStatus;
  }

  private validateMetadata(data: Record<string, string>): ExecutionMetadata {
    if (!data.createdBy || typeof data.createdBy !== 'string') {
      throw new Error('Invalid metadata: missing createdBy');
    }
    const priority = parseInt(data.priority, 10);
    if (isNaN(priority)) {
      throw new Error('Invalid metadata: invalid priority');
    }
    return { createdBy: data.createdBy, priority };
  }
}
```

**Why**: Typed API boundaries prevent runtime errors from malformed responses.

---

### [TS][!STATE-TYPES]

**Rule**: Define explicit types for all state. Use discriminated unions for complex state.

**Good Example:**

```typescript
// State types for Zustand store
interface ExecutionState {
  readonly executions: Map<string, Execution>;
  readonly loading: boolean;
  readonly error: string | null;
}

interface ExecutionActions {
  readonly addExecution: (execution: Execution) => void;
  readonly removeExecution: (id: string) => void;
  readonly setLoading: (loading: boolean) => void;
  readonly setError: (error: string | null) => void;
  readonly clearError: () => void;
}

type ExecutionStore = ExecutionState & ExecutionActions;

// Zustand store with types
export const useExecutionStore = create<ExecutionStore>((set) => ({
  executions: new Map(),
  loading: false,
  error: null,

  addExecution: (execution: Execution): void => {
    set((state) => ({
      executions: new Map(state.executions).set(execution.id, execution)
    }));
  },

  removeExecution: (id: string): void => {
    set((state) => {
      const newExecutions = new Map(state.executions);
      newExecutions.delete(id);
      return { executions: newExecutions };
    });
  },

  setLoading: (loading: boolean): void => {
    set({ loading });
  },

  setError: (error: string | null): void => {
    set({ error });
  },

  clearError: (): void => {
    set({ error: null });
  }
}));
```

**Why**: Typed state prevents mutation errors and makes state updates predictable.

---

### [TS][!EVENT-HANDLERS]

**Rule**: Type all event handlers explicitly. Never use implicit event types.

**Good Example:**

```typescript
interface FormData {
  readonly goal: string;
  readonly priority: number;
}

export const ExecutionForm: React.FC = () => {
  const [formData, setFormData] = React.useState<FormData>({
    goal: '',
    priority: 1
  });

  const handleGoalChange = (event: React.ChangeEvent<HTMLInputElement>): void => {
    setFormData((prev) => ({
      ...prev,
      goal: event.target.value
    }));
  };

  const handlePriorityChange = (event: React.ChangeEvent<HTMLSelectElement>): void => {
    setFormData((prev) => ({
      ...prev,
      priority: parseInt(event.target.value, 10)
    }));
  };

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>): void => {
    event.preventDefault();
    console.log('Submitting:', formData);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        type="text"
        value={formData.goal}
        onChange={handleGoalChange}
        placeholder="Goal"
      />
      <select value={formData.priority} onChange={handlePriorityChange}>
        <option value={1}>Low</option>
        <option value={2}>Medium</option>
        <option value={3}>High</option>
      </select>
      <button type="submit">Create</button>
    </form>
  );
};
```

**Why**: Typed event handlers catch type errors and provide autocomplete.

---

### [TS][!GENERICS]

**Rule**: Use generics for reusable components and functions. Never use `any` for flexibility.

**Good Example:**

```typescript
// Generic result type
type Result<T, E = Error> = 
  | { readonly success: true; readonly data: T }
  | { readonly success: false; readonly error: E };

// Generic async function
async function fetchData<T>(
  url: string,
  parser: (json: Record<string, unknown>) => T
): Promise<Result<T>> {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      return {
        success: false,
        error: new Error(`HTTP ${response.status}`)
      };
    }
    const json: Record<string, unknown> = await response.json();
    const data = parser(json);
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error : new Error('Unknown error')
    };
  }
}

// Generic list component
interface ListProps<T> {
  readonly items: T[];
  readonly renderItem: (item: T) => React.ReactNode;
  readonly keyExtractor: (item: T) => string;
}

export function List<T>({ items, renderItem, keyExtractor }: ListProps<T>): React.ReactElement {
  return (
    <ul>
      {items.map((item) => (
        <li key={keyExtractor(item)}>{renderItem(item)}</li>
      ))}
    </ul>
  );
}

// Usage
const executions: Execution[] = [/* ... */];

<List
  items={executions}
  renderItem={(execution) => <ExecutionCard execution={execution} />}
  keyExtractor={(execution) => execution.id}
/>
```

**Why**: Generics provide type safety without sacrificing reusability.

---

### [TS][!DISCRIMINATED-UNIONS]

**Rule**: Use discriminated unions for variant types. Never use optional properties for variants.

**Good Example:**

```typescript
// Discriminated union for loading states
type LoadingState<T> =
  | { readonly status: 'idle' }
  | { readonly status: 'loading' }
  | { readonly status: 'success'; readonly data: T }
  | { readonly status: 'error'; readonly error: string };

// Type-safe handler
function handleLoadingState<T>(
  state: LoadingState<T>,
  handlers: {
    readonly onIdle: () => React.ReactNode;
    readonly onLoading: () => React.ReactNode;
    readonly onSuccess: (data: T) => React.ReactNode;
    readonly onError: (error: string) => React.ReactNode;
  }
): React.ReactNode {
  switch (state.status) {
    case 'idle':
      return handlers.onIdle();
    case 'loading':
      return handlers.onLoading();
    case 'success':
      return handlers.onSuccess(state.data);
    case 'error':
      return handlers.onError(state.error);
  }
}

// Usage in component
export const ExecutionLoader: React.FC<{ id: string }> = ({ id }) => {
  const [state, setState] = React.useState<LoadingState<Execution>>({ status: 'idle' });

  React.useEffect(() => {
    setState({ status: 'loading' });
    
    fetchExecution(id)
      .then((execution) => {
        setState({ status: 'success', data: execution });
      })
      .catch((error: Error) => {
        setState({ status: 'error', error: error.message });
      });
  }, [id]);

  return (
    <>
      {handleLoadingState(state, {
        onIdle: () => <div>Click to load</div>,
        onLoading: () => <div>Loading...</div>,
        onSuccess: (execution) => <ExecutionCard execution={execution} />,
        onError: (error) => <div>Error: {error}</div>
      })}
    </>
  );
};
```

**Why**: Discriminated unions make impossible states impossible at compile time.

---

## Patterns

### Pattern: Base Class with TypeScript

```typescript
// Base class for all requests (fully usable)
class BaseRequest {
  protected readonly _id: string;
  protected readonly _status: RequestStatus;
  protected readonly _createdAt: Date;

  constructor(id: string, status: RequestStatus, createdAt: Date) {
    this._id = id;
    this._status = status;
    this._createdAt = createdAt;
  }

  get id(): string {
    return this._id;
  }

  get status(): RequestStatus {
    return this._status;
  }

  get createdAt(): Date {
    return this._createdAt;
  }

  getType(): string {
    return 'base';
  }

  toJSON(): Record<string, unknown> {
    return {
      id: this._id,
      status: this._status,
      createdAt: this._createdAt.toISOString()
    };
  }
}

// Subclass extends and overrides
export class ExecutionRequest extends BaseRequest {
  private readonly _goal: string;
  private readonly _priority: number;

  constructor(
    id: string,
    status: RequestStatus,
    createdAt: Date,
    goal: string,
    priority: number
  ) {
    super(id, status, createdAt);
    this._goal = goal;
    this._priority = priority;
  }

  get goal(): string {
    return this._goal;
  }

  get priority(): number {
    return this._priority;
  }

  getType(): string {
    return 'execution';
  }

  toJSON(): ExecutionRequestData {
    return {
      id: this._id,
      status: this._status,
      createdAt: this._createdAt.toISOString(),
      goal: this._goal,
      priority: this._priority
    };
  }

  static fromJSON(json: ExecutionRequestData): ExecutionRequest {
    return new ExecutionRequest(
      json.id,
      json.status,
      new Date(json.createdAt),
      json.goal,
      json.priority
    );
  }
}
```

---

## Checklist

- [ ] `"strict": true` in tsconfig.json
- [ ] No `any` types anywhere
- [ ] No `unknown` types anywhere
- [ ] All interfaces exported and named
- [ ] All component props have interfaces
- [ ] All API responses have types
- [ ] All state has explicit types
- [ ] Event handlers have explicit types
- [ ] Generic types for reusable code
- [ ] Discriminated unions for variants
- [ ] Type guards for runtime checks
- [ ] Readonly properties where appropriate

---

## Summary

**Key Principles:**

1. **Strict mode always** - Enable all strict checks
2. **Never any** - Always use explicit types
3. **Never unknown** - Define the actual type
4. **Interface everything** - Props, state, API, events
5. **Discriminated unions** - For variant types
6. **Generics for reuse** - Type-safe flexibility

**Benefits:**

- Catch all type errors at compile time
- IDE autocomplete and refactoring support
- Self-documenting code with types
- Impossible states become impossible
- Refactoring confidence

**When to Use:**

- All React components
- All domain models
- All API clients
- All state management
- All custom hooks
- All utility functions

