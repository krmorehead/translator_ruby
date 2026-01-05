# Testing Guide

This project uses a consistent testing approach across both backend and frontend with speed profile filtering.

## Test Speed Profiles

Tests are categorized by speed to enable efficient test runs:

- **Fast** (`<10s`): Unit tests, model tests, quick integrations
- **Medium** (`<60s`): Controller tests, workflows without LLM calls
- **Slow** (`<120s`): Full integrations with LLM calls, E2E tests

## Backend Testing (Rails)

### Commands

```bash
# Run all tests
bin/test

# Run fast tests only
bin/test fast

# Run medium tests only
bin/test medium

# Run slow tests only
bin/test slow

# Run full suite (fast → medium → slow)
bin/test all
```

### Implementation

- Test speed profiles are defined in `test/support/speed_profile.rb`
- Tests are tagged with `:fast`, `:medium`, or `:slow`
- Timeouts are automatically enforced
- Research worker tests are excluded by default

### Example Test

```ruby
class MyTest < ActiveSupport::TestCase
  speed_profile :fast
  
  test "something quick" do
    # Test that completes in < 10s
  end
end
```

## Frontend Testing (React/Vitest)

### Commands

```bash
# Run all tests (exits after completion)
npm test

# Run tests in watch mode (for development)
npm run test:watch

# Run fast tests only
npm run test:fast

# Run medium tests only
npm run test:medium

# Run slow tests only
npm run test:slow

# Run full suite (fast → medium → slow)
npm run test:all
```

### E2E Tests (Playwright)

```bash
# Run all E2E tests
npm run e2e

# Run fast E2E tests only
npm run e2e:fast

# Run medium E2E tests only
npm run e2e:medium

# Run slow E2E tests only
npm run e2e:slow
```

### Implementation

- Speed profiles are defined in `frontend/e2e/helpers/speedProfile.js`
- Tests use `test.describe` with speed profile tags
- Timeouts are automatically enforced based on profile

### Example Test

```javascript
import { test, expect } from '@playwright/test';
import { speedProfile } from '../helpers/speedProfile';

test.describe('My Component', () => {
  speedProfile('fast'); // Mark entire suite as fast
  
  test('renders correctly', async ({ page }) => {
    // Test that completes in < 10s
  });
});
```

## CI/CD Integration

### Running Tests in CI

```bash
# Backend - run all speed levels
bin/test all

# Frontend - run all speed levels
cd frontend && npm run test:all

# E2E tests
cd frontend && npm run e2e
```

### Timeouts

- Fast tests timeout after 10s (fail if exceeded)
- Medium tests timeout after 60s (fail if exceeded)
- Slow tests timeout after 120s (fail if exceeded)

## Excluding Tests

### Backend

Research-related tests are automatically excluded:
- `test/workers/codebase_researcher_test.rb`
- `test/workflows/research_workflow_test.rb`

### Frontend

Use `test.skip` or test filtering:

```javascript
test.skip('not ready yet', () => {
  // Skipped test
});
```

## Debugging

### Backend

```bash
# Run specific test file
bundle exec rails test test/path/to/test.rb

# Run specific test by line number
bundle exec rails test test/path/to/test.rb:42

# Run with verbose output
bundle exec rails test test/path/to/test.rb -v
```

### Frontend

```bash
# Run specific test file
npm test -- src/path/to/test.js

# Run in watch mode for debugging
npm run test:watch

# Run with UI (Vitest UI)
npx vitest --ui
```

## Best Practices

1. **Always categorize new tests** with the appropriate speed profile
2. **Tests timing out are NOT passing** - they are failures
3. **Follow OOP patterns** from `docs/references/oop-patterns.md`
4. **Use real instances** over mocks when possible
5. **Test real integrations** not isolated units in slow tests
6. **Keep fast tests fast** - mock expensive operations
7. **Use factories** for easy test data setup
8. **Fail-fast validation** in constructors to catch errors early

## Continuous Improvement

If you find a test is consistently timing out:

1. **Review the speed profile** - is it categorized correctly?
2. **Optimize the test** - can expensive operations be mocked for faster profiles?
3. **Move to slower profile** - if the test genuinely needs time (LLM calls, etc.)
4. **Check for bugs** - timeouts can indicate real issues in the code

## Summary

- Use `bin/test fast` or `npm run test:fast` for quick feedback during development
- Use `bin/test all` or `npm run test:all` for comprehensive testing before commits
- All tests should complete within their timeout limits
- Consistent test structure across backend and frontend for predictability

