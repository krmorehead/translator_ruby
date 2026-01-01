# Centralized Speed Profiling - OOP Pattern

## Problem Solved

Test files were duplicating the `speed_profile` function definition, violating DRY principle and OOP patterns. Each test file had:

```javascript
const speed_profile = (profile) => (name, fn) => {
  const timeouts = { fast: 1000, medium: 5000, slow: 30000 };
  return test(name, fn, timeouts[profile]);
};
```

This meant:
- 5+ copies of the same code
- Hard to change timeout limits
- No validation enforcement
- Inconsistent across files

## Solution: Centralized Module

### Created: `frontend/src/test/speedProfile.js`

Single source of truth for speed profiling:

```javascript
const SPEED_LEVELS = Object.freeze({
  FAST: 'fast',
  MEDIUM: 'medium',
  SLOW: 'slow'
});

const SPEED_LIMITS = Object.freeze({
  [SPEED_LEVELS.FAST]: 1000,
  [SPEED_LEVELS.MEDIUM]: 5000,
  [SPEED_LEVELS.SLOW]: 30000
});

export const speed_profile = (profile) => {
  // Strict validation
  if (typeof profile !== 'string') {
    throw new Error(`Speed profile must be a string, got ${typeof profile}`);
  }
  
  const validProfiles = Object.values(SPEED_LEVELS);
  if (!validProfiles.includes(profile)) {
    throw new Error(
      `Invalid speed profile: ${profile}. Valid profiles: ${validProfiles.join(', ')}`
    );
  }

  return (name, fn, options = {}) => {
    const timeout = SPEED_LIMITS[profile];
    return test(name, fn, { timeout, ...options });
  };
};
```

### Usage in Tests

```javascript
import { speed_profile } from "../../test/speedProfile";

describe("MyComponent", () => {
  speed_profile("fast")("renders correctly", () => {
    render(<MyComponent />);
    expect(screen.getByText(/hello/i)).toBeInTheDocument();
  });

  speed_profile("medium")("calls API", async () => {
    await api.fetchData();
    expect(result).toBeDefined();
  });
});
```

## Backend Mirror Pattern

Frontend implementation mirrors backend pattern exactly:

### Backend: `test/support/speed_profile.rb`

```ruby
module SpeedProfile
  SPEED_LEVELS = [
    FAST = :fast,
    MEDIUM = :medium,
    SLOW = :slow
  ].freeze

  SPEED_LIMITS = {
    FAST => 10,
    MEDIUM => 60,
    SLOW => 120
  }.freeze

  def self.included(base)
    base.class_eval do
      def speed_profile(level)
        unless SPEED_LEVELS.include?(level)
          raise ArgumentError, "Invalid speed profile: #{level}"
        end
        @next_speed_profile = level
      end
    end
  end

  private

  def validate_speed_profile!
    speed = self.class.speed_profile_for(name)
    raise ArgumentError, "Test must declare speed_profile" unless speed
  end
end
```

### Usage in Ruby Tests

```ruby
class MyTest < ActiveSupport::TestCase
  speed_profile :fast
  test "something" do
    assert true
  end

  speed_profile :medium
  test "with LLM" do
    result = llm_client.call
    assert result.present?
  end
end
```

## Files Updated

### Created:
- `frontend/src/test/speedProfile.js` - Centralized speed profiling module

### Updated:
- `frontend/src/components/__tests__/DaedalusPage.test.jsx` - Import centralized module
- `frontend/src/components/__tests__/ProjectPlanPage.test.jsx` - Import centralized module  
- `frontend/src/components/__tests__/AgentInspector.test.jsx` - Import centralized module
- `frontend/src/components/__tests__/MessageInput.test.jsx` - Import centralized module
- `frontend/src/components/__tests__/ChatPage.test.jsx` - Import centralized module
- `docs/references/oop-patterns.md` - Added Lesson 13: Centralized Test Infrastructure

## Benefits

1. **Single Source of Truth** ✅
   - Change timeouts in ONE place
   - All tests automatically updated

2. **Type Safety** ✅
   - Frozen constants prevent modification
   - Runtime validation catches errors

3. **Fail Fast** ✅
   - Invalid profiles throw immediately
   - Clear error messages

4. **Consistent** ✅
   - Same pattern across FE and BE
   - Easy to learn and use

5. **Maintainable** ✅
   - Add new speed levels in one place
   - Update limits in one place

## Test Results

```
✓ AgentInspector (1 test)
✓ MessageInput (2 tests)
✓ ChatPage (2 tests)
✓ ProjectPlanPage (7 tests)
✓ DaedalusPage (7 tests)

Total: 19 tests, ALL PASSING
Duration: 641ms
```

## Speed Profile Categories

### Frontend
- **fast**: < 1 second (rendering, state updates)
- **medium**: < 5 seconds (API calls, file I/O)
- **slow**: < 30 seconds (integration, LLM calls)

### Backend  
- **fast**: < 10 seconds (unit tests, validations)
- **medium**: < 60 seconds (tool execution, LLM calls)
- **slow**: < 120 seconds (workflows, integration)

## OOP Pattern Applied

**Principle**: Test infrastructure follows same OOP patterns as production code.

1. **Encapsulation** - Speed profiling logic hidden in module
2. **Single Responsibility** - Module only handles speed profiling
3. **Fail Fast** - Validation at entry point
4. **Type Safety** - Frozen constants, strict checks
5. **DRY** - One definition, many uses
6. **Composition** - Module composes with test framework

## Migration Path

For any future test infrastructure:

1. ✅ Create centralized module in `test/support/` (BE) or `src/test/` (FE)
2. ✅ Export from test helper/setup
3. ✅ Add validation and error handling
4. ✅ Update all test files to import
5. ✅ Remove duplicated code
6. ✅ Document in OOP patterns guide

## Key Takeaway

**Test infrastructure is code too**. It follows the same OOP principles:
- Single source of truth
- Fail fast with clear errors
- Type safe and validated
- Centralized and maintainable

No more copy-pasting helper functions across test files!

