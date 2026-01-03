# Frontend Testing Guide

## Overview

This guide covers testing practices for the React frontend using Vitest and React Testing Library.

## Testing Stack

- **Test Runner**: Vitest
- **Component Testing**: React Testing Library
- **Mocking**: Vitest `vi.mock()`
- **Assertions**: `@testing-library/jest-dom`
- **State Management**: Zustand (mocked in tests)

## Running Tests

### Development Mode (Watch)
```bash
cd frontend
npm test
```

### CI Mode (Single Run)
```bash
cd frontend
npm run test -- --run
```

### With Coverage
```bash
cd frontend
npm run test -- --coverage
```

## Test File Structure

### Naming Convention
- Component: `ComponentName.jsx`
- Test File: `ComponentName.test.jsx`
- Location: `src/components/__tests__/ComponentName.test.jsx`

### Basic Structure
```javascript
import { render, screen, fireEvent } from "@testing-library/react";
import { describe, test, expect, vi, beforeEach } from "vitest";
import MyComponent from "../MyComponent";
import { useMyStore } from "../../store/myStore";

// Mock external dependencies
vi.mock("../../store/myStore");

describe("MyComponent", () => {
  const mockSetValue = vi.fn();
  
  beforeEach(() => {
    vi.clearAllMocks();
    
    // Setup mock store
    useMyStore.mockImplementation((selector) => {
      const state = {
        value: "",
        setValue: mockSetValue,
      };
      return selector(state);
    });
  });
  
  test("renders with default props", () => {
    render(<MyComponent />);
    expect(screen.getByRole("button")).toBeInTheDocument();
  });
  
  test("handles user interaction", () => {
    render(<MyComponent />);
    const button = screen.getByRole("button", { name: /submit/i });
    fireEvent.click(button);
    expect(mockSetValue).toHaveBeenCalledTimes(1);
  });
});
```

## Mocking Zustand Stores

### Pattern
```javascript
import { useMyStore } from "../../store/myStore";

vi.mock("../../store/myStore");

beforeEach(() => {
  useMyStore.mockImplementation((selector) => {
    const state = {
      // State
      data: [],
      loading: false,
      error: null,
      
      // Actions
      fetchData: vi.fn(),
      reset: vi.fn(),
    };
    return selector(state);
  });
});
```

### Testing Different States
```javascript
test("displays loading state", () => {
  useMyStore.mockImplementation((selector) => {
    const state = { loading: true, data: [], error: null };
    return selector(state);
  });
  
  render(<MyComponent />);
  expect(screen.getByText(/loading/i)).toBeInTheDocument();
});

test("displays error state", () => {
  useMyStore.mockImplementation((selector) => {
    const state = { loading: false, data: [], error: "Failed to load" };
    return selector(state);
  });
  
  render(<MyComponent />);
  expect(screen.getByText(/failed to load/i)).toBeInTheDocument();
});
```

## Testing Component Interactions

### Form Inputs
```javascript
test("updates input value on change", () => {
  const mockSetGoal = vi.fn();
  
  useMyStore.mockImplementation((selector) => {
    const state = { goal: "", setGoal: mockSetGoal };
    return selector(state);
  });
  
  render(<FormComponent />);
  
  const input = screen.getByLabelText(/goal/i);
  fireEvent.change(input, { target: { value: "Test goal" } });
  
  expect(mockSetGoal).toHaveBeenCalledWith("Test goal");
});
```

### Button Clicks
```javascript
test("calls action on button click", () => {
  const mockSubmit = vi.fn();
  
  useMyStore.mockImplementation((selector) => {
    const state = { submit: mockSubmit };
    return selector(state);
  });
  
  render(<FormComponent />);
  
  const button = screen.getByRole("button", { name: /submit/i });
  fireEvent.click(button);
  
  expect(mockSubmit).toHaveBeenCalledTimes(1);
});
```

### Form Submission
```javascript
test("submits form with correct data", () => {
  const mockCreatePlan = vi.fn();
  
  useMyStore.mockImplementation((selector) => {
    const state = {
      goal: "Test goal",
      path: "/test/path",
      createPlan: mockCreatePlan,
    };
    return selector(state);
  });
  
  render(<FormComponent />);
  
  const submitButton = screen.getByRole("button", { name: /generate/i });
  fireEvent.click(submitButton);
  
  expect(mockCreatePlan).toHaveBeenCalledTimes(1);
});
```

## Querying Elements

### Preferred Queries (in order of preference)
1. **`getByRole()`** - Most accessible
   ```javascript
   screen.getByRole("button", { name: /submit/i })
   screen.getByRole("textbox", { name: /email/i })
   screen.getByRole("heading", { name: /title/i })
   ```

2. **`getByLabelText()`** - Best for forms
   ```javascript
   screen.getByLabelText(/username/i)
   ```

3. **`getByText()`** - For static content
   ```javascript
   screen.getByText(/welcome message/i)
   ```

4. **`getByPlaceholderText()`** - Acceptable for inputs
   ```javascript
   screen.getByPlaceholderText(/enter email/i)
   ```

5. **`getByTestId()`** - Last resort
   ```javascript
   screen.getByTestId("complex-component")
   ```

### Query Variants
- `getBy*` - Throws if not found (use for elements that should exist)
- `queryBy*` - Returns null if not found (use for conditional rendering)
- `findBy*` - Async, waits for element (use for async rendering)

## Async Testing

### Waiting for Elements
```javascript
import { waitFor } from "@testing-library/react";

test("loads data asynchronously", async () => {
  render(<AsyncComponent />);
  
  await waitFor(() => {
    expect(screen.getByText(/data loaded/i)).toBeInTheDocument();
  });
});
```

### Testing Promises
```javascript
test("handles async API call", async () => {
  const mockFetch = vi.fn().mockResolvedValue({ data: "test" });
  
  useMyStore.mockImplementation((selector) => {
    const state = { fetchData: mockFetch };
    return selector(state);
  });
  
  render(<Component />);
  
  const button = screen.getByRole("button", { name: /load/i });
  fireEvent.click(button);
  
  await waitFor(() => {
    expect(mockFetch).toHaveBeenCalled();
  });
});
```

## Testing Patterns

### Testing Conditional Rendering
```javascript
describe("conditional rendering", () => {
  test("shows content when data exists", () => {
    useMyStore.mockImplementation((selector) => {
      const state = { result: { data: "test" } };
      return selector(state);
    });
    
    render(<Component />);
    expect(screen.getByText(/test/i)).toBeInTheDocument();
  });
  
  test("shows empty state when no data", () => {
    useMyStore.mockImplementation((selector) => {
      const state = { result: null };
      return selector(state);
    });
    
    render(<Component />);
    expect(screen.queryByText(/test/i)).not.toBeInTheDocument();
  });
});
```

### Testing Disabled States
```javascript
test("disables button when loading", () => {
  useMyStore.mockImplementation((selector) => {
    const state = { loading: true };
    return selector(state);
  });
  
  render(<Component />);
  
  const button = screen.getByRole("button");
  expect(button).toBeDisabled();
});
```

### Testing Error Boundaries
```javascript
test("displays error message", () => {
  useMyStore.mockImplementation((selector) => {
    const state = { error: "Something went wrong" };
    return selector(state);
  });
  
  render(<Component />);
  expect(screen.getByText(/something went wrong/i)).toBeInTheDocument();
});
```

## Best Practices

### Do's
✅ Test user-visible behavior, not implementation details
✅ Use accessible queries (getByRole, getByLabelText)
✅ Keep tests focused and isolated
✅ Clear mocks between tests
✅ Use descriptive test names
✅ Test edge cases and error states
✅ Make assertions meaningful

### Don'ts
❌ Don't test internal component state
❌ Don't query by class names or ids
❌ Don't mock what you're testing
❌ Don't rely on test execution order
❌ Don't use sleeps for async operations
❌ Don't test third-party library behavior

## Browser Automation Limitations

### Known Issue
Some browser automation tools (Playwright, Selenium) don't trigger React's synthetic events properly when using automated typing.

**Symptom**: `onChange` handlers don't fire during automated browser tests, but work fine in manual testing and unit tests.

**Solution**:
1. **Unit tests are source of truth** - Test with mocked stores
2. **Manual verification** - Use simple HTML test pages when needed
3. **Cleanup** - Remove test artifacts after verification

### Creating Manual Test Pages
```html
<!DOCTYPE html>
<html>
<head><title>Component Test</title></head>
<body>
    <div id="test-form">
        <input id="test-input" type="text">
        <button id="test-button">Test</button>
    </div>
    <script>
        document.getElementById('test-button').addEventListener('click', async () => {
            const value = document.getElementById('test-input').value;
            const response = await fetch('/api/endpoint', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ value })
            });
            console.log(await response.json());
        });
    </script>
</body>
</html>
```

**Remember**: Delete these files after testing!

## Test Coverage Goals

### Minimum Coverage
- **Unit Tests**: 80%+ for component logic
- **Integration**: Key user flows tested
- **Accessibility**: All interactive elements accessible

### What to Test
- Component rendering (default, loading, error states)
- User interactions (clicks, typing, form submission)
- Prop validation and edge cases
- State updates and side effects
- Conditional rendering logic
- Error handling

### What Not to Test
- Third-party library internals
- Browser APIs
- CSS styling (use visual regression for this)
- Implementation details that may change

## Debugging Tests

### View Component Output
```javascript
import { screen } from "@testing-library/react";

test("debug test", () => {
  render(<Component />);
  screen.debug(); // Prints DOM tree
});
```

### Check Element Presence
```javascript
const element = screen.queryByText(/text/i);
console.log('Element:', element); // null if not found
```

### Run Single Test
```bash
npm test -- ComponentName.test.jsx
```

### Run with Verbose Output
```bash
npm test -- --verbose
```

## Common Pitfalls

### 1. Testing Implementation Details
**Bad**:
```javascript
expect(component.state.value).toBe("test");
```

**Good**:
```javascript
expect(screen.getByText(/test/i)).toBeInTheDocument();
```

### 2. Not Cleaning Up Mocks
**Bad**:
```javascript
test("test 1", () => {
  mockFn.mockReturnValue("test1");
  // ...
});

test("test 2", () => {
  // mockFn still returns "test1"!
});
```

**Good**:
```javascript
beforeEach(() => {
  vi.clearAllMocks();
});
```

### 3. Querying by Implementation Details
**Bad**:
```javascript
screen.getByClassName("submit-button");
```

**Good**:
```javascript
screen.getByRole("button", { name: /submit/i });
```

## Example: Complete Test File

```javascript
import { render, screen, fireEvent } from "@testing-library/react";
import { describe, test, expect, vi, beforeEach } from "vitest";
import DaedalusPage from "../DaedalusPage";
import { useDaedalusStore } from "../../store/daedalusStore";

vi.mock("../../store/daedalusStore");

describe("DaedalusPage", () => {
  const mockSetGoal = vi.fn();
  const mockSetPath = vi.fn();
  const mockCreatePlan = vi.fn();
  const mockReset = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    
    useDaedalusStore.mockImplementation((selector) => {
      const state = {
        goal: "",
        path: "",
        loading: false,
        error: null,
        result: null,
        setGoal: mockSetGoal,
        setPath: mockSetPath,
        createPlan: mockCreatePlan,
        reset: mockReset,
      };
      return selector(state);
    });
  });

  test("renders form with inputs", () => {
    render(<DaedalusPage />);
    
    expect(screen.getByLabelText(/goal/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/codebase path/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /generate/i })).toBeInTheDocument();
  });

  test("calls store setters on input change", () => {
    render(<DaedalusPage />);
    
    const goalInput = screen.getByLabelText(/goal/i);
    fireEvent.change(goalInput, { target: { value: "Test goal" } });
    
    expect(mockSetGoal).toHaveBeenCalledWith("Test goal");
  });

  test("disables button when loading", () => {
    useDaedalusStore.mockImplementation((selector) => {
      const state = { loading: true, goal: "test", path: "/test" };
      return selector(state);
    });
    
    render(<DaedalusPage />);
    
    const button = screen.getByRole("button", { name: /generating/i });
    expect(button).toBeDisabled();
  });

  test("displays error message", () => {
    useDaedalusStore.mockImplementation((selector) => {
      const state = { error: "Test error message" };
      return selector(state);
    });
    
    render(<DaedalusPage />);
    expect(screen.getByText(/test error message/i)).toBeInTheDocument();
  });

  test("displays result when available", () => {
    const mockResult = {
      execution_plan: {
        milestones: [
          { id: "1", title: "Test Milestone", steps: [] }
        ]
      }
    };
    
    useDaedalusStore.mockImplementation((selector) => {
      const state = { result: mockResult };
      return selector(state);
    });
    
    render(<DaedalusPage />);
    expect(screen.getByText(/test milestone/i)).toBeInTheDocument();
  });
});
```

## References

- [React Testing Library Docs](https://testing-library.com/react)
- [Vitest Docs](https://vitest.dev/)
- [Testing Library Best Practices](https://kentcdodds.com/blog/common-mistakes-with-react-testing-library)
- Backend Testing: `docs/test_speed_profiling_quick_reference.md`
- Frontend NO MOCKING: `docs/frontend_testing_no_mocking.md`
- Frontend Speed Profiling: `docs/frontend_test_speed_profiling.md`
- OOP Patterns: `docs/references/oop-patterns.md`

---

## UPDATE (January 2026): NO MOCKING POLICY

**IMPORTANT:** This guide's mocking sections are **DEPRECATED**. We now follow a strict NO MOCKING policy across all tests.

### What Changed

❌ **OLD APPROACH (Deprecated)**:
```javascript
vi.mock("../../store/myStore");

useMyStore.mockImplementation((selector) => {
  const state = { value: "mocked" };
  return selector(state);
});
```

✅ **NEW APPROACH (Current)**:
```javascript
// NO mocking - use real store
import { useMyStore } from "../../store/myStore";

beforeEach(() => {
  useMyStore.getState().reset();
});

// Use real store
const state = useMyStore.getState();
expect(state.value).toBe("real value");
```

### Why We Changed

**Problems with Mocking:**
1. Mocks hide integration issues
2. Mocks drift from real implementations
3. Tests pass with mocks but fail with real code
4. More code to maintain (mock setup)
5. False confidence in test coverage

**Benefits of Real Implementations:**
1. Tests verify actual behavior
2. Refactoring safety (real tests fail when contracts break)
3. Simpler tests (less code)
4. True integration testing
5. Fail fast with real errors

### Migration Guide

If you're updating old tests that use mocks:

**Step 1:** Remove all `vi.mock()` calls
```javascript
// DELETE THIS
vi.mock("../../store/daedalusStore");
```

**Step 2:** Remove mock function declarations
```javascript
// DELETE THIS
const mockSetGoal = vi.fn();
const mockCreatePlan = vi.fn();
```

**Step 3:** Use real store with `getState()` and `setState()`
```javascript
// ADD THIS
beforeEach(() => {
  useDaedalusStore.getState().reset();
});

// IN TESTS: Use real store
const state = useDaedalusStore.getState();
expect(state.goal).toBe("Test goal");
```

**Step 4:** Add speed profiling
```javascript
import { speedProfile } from '../utils/testProfile';

describe('MyComponent', () => {
  speedProfile('fast'); // or 'medium' or 'slow'
  
  // tests...
});
```

### Updated Test Pattern

```javascript
import { describe, test, expect, beforeEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { speedProfile } from "../../utils/testProfile";
import DaedalusPage from "../DaedalusPage";
import { useDaedalusStore } from "../../store/daedalusStore";

describe("DaedalusPage", () => {
  speedProfile('fast'); // Declare speed profile
  
  beforeEach(() => {
    // Reset real store before each test
    useDaedalusStore.getState().reset();
  });

  test("renders form with inputs", () => {
    render(<DaedalusPage />);
    
    expect(screen.getByLabelText(/goal/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /generate/i })).toBeInTheDocument();
  });

  test("updates store on input change", () => {
    render(<DaedalusPage />);
    
    const goalInput = screen.getByLabelText(/goal/i);
    fireEvent.change(goalInput, { target: { value: "Test goal" } });
    
    // Verify REAL store updated
    const state = useDaedalusStore.getState();
    expect(state.goal).toBe("Test goal");
  });

  test("displays error from store", () => {
    // Set real store state
    useDaedalusStore.setState({ error: "Test error message" });
    
    render(<DaedalusPage />);
    expect(screen.getByText(/test error message/i)).toBeInTheDocument();
  });
});
```

### E2E Tests with Real LLM

For comprehensive E2E tests, use real endpoints and real LLM:

```javascript
import { test, expect } from "@playwright/test";

const E2E_TEST_TIMEOUT = 120000; // 120 seconds max
test.setTimeout(E2E_TEST_TIMEOUT);

test.describe("Approval Flow - Real LLM", () => {
  let testProjectPath;
  
  test.beforeEach(async () => {
    // Create unique test directory
    testProjectPath = `/tmp/e2e-test-${Date.now()}`;
    // Setup minimal test plan
  });
  
  test.afterEach(async () => {
    // Clean up test files
    // Cancel any running executions
  });
  
  test("approves step with real LLM", async ({ page }) => {
    // Uses REAL execution service
    // Uses REAL LLM to parse plan
    // Uses REAL approval flow
    
    await page.goto("http://localhost:5173/sisyphus");
    
    // Fill form with real test data
    await page.getByPlaceholder("/path/to/project").fill(testProjectPath);
    // ...
    
    // Wait for REAL LLM to process
    const modal = page.getByRole("heading", { name: /Approval Required/i });
    await modal.waitFor({ state: 'visible', timeout: 60000 });
    
    // Approve and verify execution continues
    await page.getByRole("button", { name: /Approve/i }).click();
    // ...
  });
});
```

### Key Principles (Updated)

**DO:**
- ✅ Use real Zustand stores (no mocks)
- ✅ Use real API clients (or skip if too slow)
- ✅ Test user-visible behavior
- ✅ Add speed profiling to all tests
- ✅ Use factories for test data
- ✅ Reset stores between tests
- ✅ Use real LLM in E2E tests (slow profile)

**DON'T:**
- ❌ Mock stores with `vi.mock()`
- ❌ Create fake functions with `vi.fn()`
- ❌ Mock what you're testing
- ❌ Test implementation details
- ❌ Skip speed profiling
- ❌ Create test-only endpoints

### Further Reading

See `docs/frontend_testing_no_mocking.md` for complete details on our NO MOCKING policy and migration guide.

See `docs/frontend_test_speed_profiling.md` for speed profiling requirements and real-world examples.

See `docs/references/oop-patterns.md` for OOP principles that apply to all test code.

---