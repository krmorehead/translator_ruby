# Test References

## Purpose

Documentation index for test configuration and support files.

## File Tree

```
test/
├── test_helper.rb              # Central test configuration
├── support/
│   └── research_test_factory.rb  # Factory methods for research tests
├── fixtures/
│   ├── cursor_baseline/        # Baseline comparison fixtures
│   └── example_codebase/       # Example codebase for integration tests
├── controllers/                # Controller tests
├── integration/                # Integration tests
├── models/                     # Model tests
├── prompts/                    # Prompt tests
├── services/                   # Service tests
├── tools/                      # Tool tests
├── workers/                    # Worker tests
└── workflows/                  # Workflow tests
```

## Quick Navigation

### Configuration
- [TestHelper](test_helper.md) - Central test configuration with parallelization settings

### Support Files
- [ResearchTestFactory](support/research_test_factory.md) - Factory methods for research tests

## Test Optimization

### Parallelization Threshold

Tests run in parallel using all CPU cores, but with a threshold of 50 tests. Smaller test runs execute in a single process, enabling class-level memoization for expensive LLM calls.

### Shared Result Pattern

LLM-heavy tests use class-level caching to share results across test methods within the same test class. See [TestHelper](test_helper.md) for implementation details.

