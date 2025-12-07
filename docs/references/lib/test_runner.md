# Test Runner Script

**File**: `lib/test_runner.rb`

## Purpose

Custom test runner script that loads environment variables from `.env` and runs Rails tests with the test environment properly configured.

## Usage

```bash
# Run all tests
ruby lib/test_runner.rb

# Run specific test file
ruby lib/test_runner.rb test/controllers/api/v1/hello_controller_test.rb

# Run specific test method
ruby lib/test_runner.rb test/services/translation_service_test.rb -n test_translate_text
```

## Implementation

```ruby
#!/usr/bin/env ruby
require "dotenv/load" if File.exist?(".env")

# Set test environment
ENV["RAILS_ENV"] = "test"

# Run the tests
exec "bundle", "exec", "rails", "test", *ARGV
```

## Features

- Loads `.env` file automatically
- Forces `RAILS_ENV=test`
- Passes all arguments to `rails test`
- Uses `exec` for clean process replacement

## Environment Handling

The script ensures:
1. `.env` is loaded for database credentials and other config
2. `RAILS_ENV` is set to `test` regardless of current environment
3. All command-line arguments are forwarded to Rails test runner

## Comparison with Direct Rails Test

| Method | Loads .env | Ensures Test Env |
|--------|------------|------------------|
| `ruby lib/test_runner.rb` | ✅ | ✅ |
| `rails test` | ❌ | ✅ |
| `RAILS_ENV=test rails test` | ❌ | ✅ |

## Related Files

- [Server](server.md) - Similar pattern for server startup
- `test/test_helper.rb` - Test configuration
- `.env.test` - Test environment overrides

