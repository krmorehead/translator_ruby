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

