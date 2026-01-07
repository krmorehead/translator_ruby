---
description: Shell script patterns for test runners and development tools
globs: bin/**/*
alwaysApply: false
---

# Script & Bin Patterns

**Tags**: [coding, back_end, testing]  
**Applies To**: Bash/shell scripts  
**Date**: 2026-01-06

## Overview

Robust shell scripts with proper error handling, cleanup, and server lifecycle management. Used for test runners, server startup, and development tools.

## Script Execution Flow Tree

```
Shell Script Architecture
│
├── Script Header
│   ├── #!/usr/bin/env bash
│   ├── set -e  # Exit on error
│   └── Colors/constants definitions
│
├── Environment Setup
│   ├── export RAILS_ENV=test
│   ├── PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
│   └── cd "$PROJECT_ROOT"
│
├── Cleanup Function (always runs)
│   └── cleanup() {
│         kill $RAILS_PID 2>/dev/null || true
│         kill $FRONTEND_PID 2>/dev/null || true
│         wait $RAILS_PID 2>/dev/null || true
│       }
│       trap cleanup EXIT INT TERM
│
├── Kill Existing Processes
│   ├── lsof -i:4000 -t | xargs kill -9
│   └── sleep 1
│
├── Start Server (if needed)
│   ├── RAILS_ENV=test bundle exec rails server -p 4000 &
│   ├── RAILS_PID=$!
│   └── Wait for health check
│
├── Run Main Logic
│   ├── Parse speed filter argument
│   ├── Set TEST_SPEED_FILTER env var
│   └── Execute command with args
│
├── Capture Exit Code
│   └── EXIT_CODE=$?
│
└── Display Results (colored)
    ├── echo -e "${GREEN}✅ Success${NC}"
    └── exit $EXIT_CODE
```

---

## Rules

### [SCRIPT][!TRAP-CLEANUP-AND-ENV]

**Rule**: Set `set -e`, use trap for cleanup, set up environment explicitly.

**Good Example:**

```bash
#!/usr/bin/env bash
set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Environment
export RAILS_ENV=test
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Cleanup trap
cleanup() {
  echo "Cleaning up..."
  [ -n "$SERVER_PID" ] && kill $SERVER_PID 2>/dev/null || true
  [ -n "$SERVER_PID" ] && wait $SERVER_PID 2>/dev/null || true
}

trap cleanup EXIT INT TERM
```

**Why**: `set -e` fails fast on errors. Trap ensures cleanup on exit, Ctrl+C, or kill. Explicit environment prevents surprises.

---

### [SCRIPT][!KILL-PORTS-AND-WAIT]

**Rule**: Kill existing processes on ports, then wait for server ready with health check.

**Good Example:**

```bash
# Kill existing processes
if lsof -i:4000 -t >/dev/null 2>&1; then
  echo "Killing existing process on port 4000"
  lsof -i:4000 -t | xargs kill -9 2>/dev/null || true
  sleep 1
fi

# Start server
RAILS_ENV=test bundle exec rails server -p 4000 > tmp/server.log 2>&1 &
SERVER_PID=$!

# Wait for ready with health check
echo "Waiting for server..."
for i in {1..30}; do
  if curl -s http://localhost:4000/api/health > /dev/null 2>&1; then
    echo "✅ Server ready"
    break
  fi
  [ $i -eq 30 ] && echo "❌ Server failed to start" && exit 1
  sleep 1
done
```

**Why**: Clean port state prevents "address already in use" errors. Health check ensures server is actually ready, not just started.

---

### [SCRIPT][!SPEED-FILTER-AND-COLOR]

**Rule**: Support speed filter arguments. Use colored output for results.

**Good Example:**

```bash
# Parse speed filter
SPEED_FILTER=""
if [ "$1" == "fast" ] || [ "$1" == "medium" ] || [ "$1" == "slow" ]; then
  SPEED_FILTER="$1"
  shift
fi

# Run with speed filter
if [ -n "$SPEED_FILTER" ]; then
  echo "Running $SPEED_FILTER tests..."
  TEST_SPEED_FILTER="$SPEED_FILTER" bundle exec rspec "$@"
else
  echo "Running all tests..."
  bundle exec rspec "$@"
fi

EXIT_CODE=$?

# Colored output
if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}✅ Tests passed${NC}"
else
  echo -e "${RED}❌ Tests failed${NC}"
fi

exit $EXIT_CODE
```

**Why**: Speed filter allows running subsets of tests. Colored output makes success/failure immediately visible.

---

## Pattern: Complete Test Runner Script

```bash
#!/usr/bin/env bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Parse speed filter
SPEED_FILTER=""
if [ "$1" == "fast" ] || [ "$1" == "medium" ] || [ "$1" == "slow" ]; then
  SPEED_FILTER="$1"
  shift
fi

# Environment
export RAILS_ENV=test
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# Cleanup trap
cleanup() {
  echo "Cleaning up..."
  [ -n "$SERVER_PID" ] && kill $SERVER_PID 2>/dev/null || true
}

trap cleanup EXIT INT TERM

# Kill existing processes
if lsof -i:4000 -t >/dev/null 2>&1; then
  lsof -i:4000 -t | xargs kill -9 2>/dev/null || true
  sleep 1
fi

# Start server (if needed for tests)
# RAILS_ENV=test bundle exec rails server -p 4000 &
# SERVER_PID=$!
# Wait for health check...

# Run tests
if [ -n "$SPEED_FILTER" ]; then
  TEST_SPEED_FILTER="$SPEED_FILTER" bundle exec rspec "$@"
else
  bundle exec rspec "$@"
fi

EXIT_CODE=$?

# Display results
if [ $EXIT_CODE -eq 0 ]; then
  echo -e "${GREEN}✅ Tests passed${NC}"
else
  echo -e "${RED}❌ Tests failed${NC}"
fi

exit $EXIT_CODE
```

---

## Summary

**Key Principles:**

1. **set -e** - Fail fast on errors
2. **Trap cleanup** - Always runs on exit/interrupt
3. **Kill existing** - Clean port state
4. **Health check** - Wait for server ready
5. **Speed filter** - Support test subsets
6. **Color output** - Clear visual feedback

**Benefits:**

- Robust error handling
- Clean shutdown on Ctrl+C
- Clear feedback with colors
- Consistent test execution
- Works in CI/CD

**Testing Integration:**

All test execution uses standardized scripts:
- `bin/test` - Backend tests
- `bin/e2e` - Frontend E2E with backend
- `bin/test-fe` - Frontend unit tests

These ensure same environment, proper lifecycle, clean ports, speed profiles, and graceful interruption.

