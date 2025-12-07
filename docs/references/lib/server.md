# Server Startup Script

**File**: `lib/server.rb`

## Purpose

Custom server startup script that loads environment variables from `.env` and starts the Rails server with configurable host and port.

## Usage

```bash
# Basic usage
ruby lib/server.rb

# With custom port
PORT=3001 ruby lib/server.rb

# With custom host and port
PORT=52020 HOST=0.0.0.0 ruby lib/server.rb
```

## Implementation

```ruby
#!/usr/bin/env ruby

require_relative "../config/environment"
require "dotenv/load" if File.exist?(".env")

port = ENV["PORT"] || 3000
host = ENV["HOST"] || "localhost"

puts "Starting Rails server on #{host}:#{port}"
puts "Hello World endpoint: http://#{host}:#{port}/api/v1/hello/index"

exec "bundle", "exec", "rails", "server", "-p", port.to_s, "-b", host
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3000` | Server port |
| `HOST` | `localhost` | Bind address |

## Features

- Loads Rails environment
- Automatically loads `.env` file if present
- Prints startup information
- Executes Rails server with configured options

## Output Example

```
Starting Rails server on 0.0.0.0:52020
Hello World endpoint: http://0.0.0.0:52020/api/v1/hello/index
```

## Related Files

- [TestRunner](test_runner.md) - Similar pattern for tests
- `.env` - Environment configuration (gitignored)

