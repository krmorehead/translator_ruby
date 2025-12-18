# TestHelper

## Purpose

Central test configuration file for the Rails test suite. Configures parallelization, fixtures, factory methods, and shared test utilities.

## Location

`test/test_helper.rb`

## Key Configuration

### Parallelization

```ruby
parallelize(workers: :number_of_processors, threshold: 50)
```

- **workers**: Uses all available CPU cores for parallel test execution
- **threshold**: Tests run in single process when count < 50

**Rationale:** The threshold enables class-level memoization for LLM-heavy tests. When tests run in a single process, shared results can be cached across test methods, significantly reducing LLM calls.

### Fixtures

```ruby
fixtures :all
```

Loads all fixtures from `test/fixtures/*.yml`.

### Factory Bot

```ruby
include FactoryBot::Syntax::Methods
```

Enables factory methods like `build(:research_context)` in all tests.

### Minitest::Spec DSL

```ruby
extend Minitest::Spec::DSL
```

Enables `let` and other Minitest::Spec methods.

## Test Optimization Patterns

### Shared LLM Results

For LLM-heavy tests, use class-level memoization to share results:

```ruby
class << self
  attr_accessor :shared_result, :computed
end

def shared_execution
  return self.class.shared_result if self.class.computed
  
  # Run expensive LLM call once
  self.class.shared_result = expensive_llm_call
  self.class.computed = true
  self.class.shared_result
end

test "uses shared result" do
  result = shared_execution
  assert result[:success]
end
```

This pattern works because tests with < 50 count run in single process.

## Support Files

Loads all support files from `test/support/**/*.rb`:

- `research_test_factory.rb` - Factory methods for research tests

## Environment

- Loads from `.env.test` via Dotenv
- Sets `RAILS_ENV=test`

## Related

- [ResearchTestFactory](test/support/research_test_factory.md) - Factory methods for research components

