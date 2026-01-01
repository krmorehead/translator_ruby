# Test Speed Profiling - Quick Reference

## Running Tests

```bash
# Fast tests only (recommended for development)
ruby lib/test_runner.rb --speed fast

# Fast + medium tests (recommended for feature work)
ruby lib/test_runner.rb --speed medium

# All tests (required before final milestone)
ruby lib/test_runner.rb --speed all

# Specific file or directory
ruby lib/test_runner.rb --speed fast test/models/inventory_item_test.rb
ruby lib/test_runner.rb --speed medium test/services
```

## Writing New Tests

**Every individual test MUST declare a speed profile before the test definition:**

```ruby
class MyNewTest < ActiveSupport::TestCase
  speed_profile :fast
  test "my fast test" do
    # test code
  end
  
  speed_profile :medium
  test "my medium test" do
    # test code
  end
  
  speed_profile :fast
  test "another fast test" do
    # test code
  end
end
```

## Speed Profile Guidelines

Choose the appropriate speed profile based on test characteristics:

### :fast (<10 seconds)
- Unit tests
- Model tests  
- Validation tests
- Serialization tests
- Pure logic without external calls

### :medium (<60 seconds)
- Tool tests with real execution
- Service tests with single LLM calls
- Tests with file I/O
- Tests with simple external processes

### :slow (<120 seconds)
- Worker tests with full execution
- Workflow tests
- Integration tests
- Tests with multiple LLM calls
- Tests with complex external dependencies

## Per-Test Speed Profiling

Speed profiles are applied **per test**, not per file. This allows you to have tests with different speed profiles in the same test file:

```ruby
class MixedSpeedTest < ActiveSupport::TestCase
  speed_profile :fast
  test "quick validation" do
    assert_equal 1 + 1, 2
  end
  
  speed_profile :medium
  test "test with LLM call" do
    result = some_llm_service.call
    assert result.present?
  end
  
  speed_profile :fast
  test "another quick test" do
    assert true
  end
end
```

When running with `--speed fast`, only the two fast tests will run. The medium test will be skipped.

## What Happens If...

### Test exceeds its SLA
The test will be forcefully terminated and fail with a message:
```
Test 'test_name' exceeded fast speed profile SLA (10s)
```

### Test doesn't have speed_profile
The test will fail immediately with:
```
Test 'test_name' must declare speed_profile. Add 'speed_profile :fast', 
'speed_profile :medium', or 'speed_profile :slow' before the test definition.
```

### Wrong --speed flag
You'll see helpful usage information:
```
Error: --speed flag is required

Usage: ruby lib/test_runner.rb --speed LEVEL [test_options]
...
```

## Profiling Tests

To analyze test execution times:

```bash
bundle exec rake test:profile
```

This generates a detailed report at `tmp/test_speed_profile_report.txt` with:
- Actual execution times for all tests
- Suggested speed profile for each test file
- Summary statistics

## Development Workflow

1. **During iteration**: `ruby lib/test_runner.rb --speed fast`
2. **Testing new feature**: Run fast + tests for modified files  
3. **Before PR**: `ruby lib/test_runner.rb --speed all`

This allows for rapid iteration with fast tests while ensuring complete coverage before merge.

## Benefits of Per-Test Speed Profiling

- **Granular control**: Different tests in the same file can have different speed profiles
- **Better filtering**: Run only the tests you need based on actual test speed, not file speed
- **Flexible organization**: Organize tests by functionality, not by speed
- **Accurate SLAs**: Each test enforces its own timeout based on its declared profile
