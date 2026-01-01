# Frontend Testing Refactor: NO MOCKING

## Problem
The frontend tests were using `vi.mock()` extensively, violating our core testing principle: **Never mock. Use real implementations.**

## Solution
Completely rewrote frontend tests to match backend philosophy:

1. ✅ **No Mocks** - Removed ALL `vi.mock()` calls
2. ✅ **Real Stores** - Use actual Zustand stores with real state
3. ✅ **Factories** - Created data factories for test fixtures
4. ✅ **Speed Profiling** - Added per-test speed categories (fast/medium/slow)
5. ✅ **Fail Fast** - Tests use real state, fail loudly on errors

## Changes Made

### 1. Removed All Mocks
**Before** (WRONG):
```javascript
vi.mock("../../store/daedalusStore");

beforeEach(() => {
  useDaedalusStore.mockImplementation((selector) => {
    const state = { goal: "", ... };
    return selector(state);
  });
});
```

**After** (CORRECT):
```javascript
beforeEach(() => {
  useDaedalusStore.getState().reset();
});

// Use real store
const state = useDaedalusStore.getState();
expect(state.goal).toBe("Test goal");
```

### 2. Created Test Factories
**File**: `frontend/src/test/factories.js`

Factories generate real test data structures:
```javascript
export const buildExecutionPlanResult = (overrides = {}) => {
  const defaults = {
    success: true,
    result: {
      execution_plan: { /* real structure */ },
      output_paths: { /* real paths */ },
      analysis_summary: { /* real analysis */ }
    },
    metadata: { milestone_count: 1, step_count: 1 }
  };
  return mergeDeep(defaults, overrides);
};
```

Usage:
```javascript
const result = buildExecutionPlanResult({ 
  metadata: { milestone_count: 5 } 
});
useDaedalusStore.setState({ result });
```

### 3. Added Speed Profiling
Every test now declares its speed profile:
```javascript
const speed_profile = (profile) => (name, fn) => {
  const timeouts = { fast: 1000, medium: 5000, slow: 30000 };
  return test(name, fn, timeouts[profile]);
};

speed_profile("fast")("renders form", () => {
  // < 1 second test
});

speed_profile("medium")("calls API", async () => {
  // < 5 second test with real API
});

speed_profile("slow")("full integration", async () => {
  // < 30 second test with LLM
});
```

### 4. Real State Management
Tests now manipulate real Zustand store state:

```javascript
// Set initial state
useDaedalusStore.setState({ 
  loading: true, 
  goal: "Test", 
  path: "/path" 
});

// Render with real state
render(<DaedalusPage />);

// Verify real store updated
const state = useDaedalusStore.getState();
expect(state.goal).toBe("Updated goal");
```

## Test Pattern

### Standard Test Structure
```javascript
import { describe, test, expect, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import MyComponent from "../MyComponent";
import { useMyStore } from "../../store/myStore";

const speed_profile = (profile) => (name, fn) => {
  const timeouts = { fast: 1000, medium: 5000, slow: 30000 };
  return test(name, fn, timeouts[profile]);
};

describe("MyComponent", () => {
  beforeEach(() => {
    useMyStore.getState().reset();
  });

  afterEach(() => {
    useMyStore.getState().reset();
  });

  speed_profile("fast")("renders correctly", () => {
    render(<MyComponent />);
    expect(screen.getByRole("button")).toBeInTheDocument();
  });

  speed_profile("fast")("updates store on interaction", () => {
    render(<MyComponent />);
    
    const input = screen.getByLabelText(/name/i);
    fireEvent.change(input, { target: { value: "Test" } });
    
    const state = useMyStore.getState();
    expect(state.name).toBe("Test");
  });
});
```

## Files Updated

| File | Changes |
|------|---------|
| `DaedalusPage.test.jsx` | Removed mocks, added real store, speed profiling |
| `ProjectPlanPage.test.jsx` | Removed mocks, added real store, speed profiling |
| `frontend-testing-rule.mdc` | Updated to forbid mocking, require speed profiles |
| `test/factories.js` | Created factory functions for test data |

## Test Results

```
✓ AgentInspector (1 test) 
✓ MessageInput (2 tests)
✓ ChatPage (2 tests)
✓ ProjectPlanPage (7 tests)
✓ DaedalusPage (7 tests)

Total: 19 tests, all passing
```

## Speed Profile Categories

### Fast (< 1 second)
- Pure rendering tests
- State updates
- Form validation
- UI interactions

### Medium (< 5 seconds)
- Real API calls (mocked backend)
- File I/O operations
- Complex state transitions

### Slow (< 30 seconds)
- Integration tests
- Real LLM calls
- End-to-end workflows

## Benefits

1. **No Mock Fragility**: Tests don't break when implementation changes
2. **Real Behavior**: Tests verify actual user-visible behavior
3. **Fail Fast**: Errors surface immediately, not hidden by mocks
4. **Simple**: Less code, easier to understand
5. **Consistent**: Matches backend testing philosophy exactly

## Philosophy Alignment

### Backend Pattern
```ruby
speed_profile :fast
test "validates input" do
  step = Planning::PlanStep.new(...)
  assert step.complete?
end
```

### Frontend Pattern (Now Matches!)
```javascript
speed_profile("fast")("validates input", () => {
  useDaedalusStore.setState({ goal: "Test" });
  render(<DaedalusPage />);
  expect(screen.getByDisplayValue("Test")).toBeInTheDocument();
});
```

## What NOT to Do

❌ **Don't mock stores**:
```javascript
vi.mock("../../store/myStore"); // NEVER
```

❌ **Don't mock APIs** (use real or skip):
```javascript
vi.mock("../../api/myApi"); // NEVER
```

❌ **Don't create fake functions**:
```javascript
const mockFn = vi.fn(); // NEVER
```

## What TO Do

✅ **Use real stores**:
```javascript
useMyStore.setState({ value: "test" });
```

✅ **Use factories**:
```javascript
const data = buildExecutionPlanResult();
```

✅ **Speed profile everything**:
```javascript
speed_profile("fast")("test name", () => { ... });
```

✅ **Test real behavior**:
```javascript
const state = useMyStore.getState();
expect(state.loading).toBe(false);
```

## Migration Checklist

When updating old tests:
- [ ] Remove all `vi.mock()` calls
- [ ] Remove all `mockFn = vi.fn()` declarations
- [ ] Use real stores with `.getState()` and `.setState()`
- [ ] Add `speed_profile()` to every test
- [ ] Create factories for complex test data
- [ ] Add `beforeEach` to reset store state
- [ ] Verify tests pass with real implementations

## Key Takeaway

**Frontend tests now follow the same philosophy as backend tests**: Use real implementations, fail fast, no mocking. This makes tests more reliable, simpler, and aligned with our core principles.

