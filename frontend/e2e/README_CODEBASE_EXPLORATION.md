# Codebase Exploration E2E Tests - Quick Start

## Overview

Tests that verify both Daedalus and Sisyphus can properly explore codebases using `file_tree`, `grep`, and `read_file` tools.

## Quick Run

```bash
# From project root

# Run all codebase exploration tests (~2.5 minutes)
bin/test-e2e --grep "codebase\|Daedalus.*explore\|Sisyphus.*tool\|both agents"

# Run only fast tests (UI checks, ~15 seconds total)
bin/test-e2e fast

# Run only slow tests (with LLM, ~2 minutes total)
bin/test-e2e slow
```

## Test Categories

### Fast Tests (3 tests) ⚡
- Sisyphus tool availability checks
- UI verification
- Tool schema consistency
- **Runtime**: ~15 seconds total

### Medium Tests (1 test) ⏱️
- Error handling for invalid paths
- **Runtime**: ~15 seconds

### Slow Tests (4 tests) 🐌
- Full Daedalus codebase exploration
- Real LLM calls with tool usage
- Plan generation with file discovery
- **Runtime**: ~2 minutes total

## What's Being Tested

### Daedalus (Plan Agent)
- ✅ Can use `file_tree` to explore directory structure
- ✅ Can use `grep` to search for code patterns
- ✅ Can use `read_file` to read file contents
- ✅ Understands Ruby project structure
- ✅ Handles invalid paths gracefully

### Sisyphus (Act Agent)
- ✅ Has access to `file_tree` tool
- ✅ Has all 5 execution tools available
- ✅ Can accept codebase path for exploration

### Integration
- ✅ Both agents use consistent tool schemas
- ✅ Daedalus plans can be used by Sisyphus

## Test Fixture

**Location**: `../../test/fixtures/example_codebase/`

A realistic Ruby codebase with:
- Service layer (`app/services/`)
- Library code (`lib/`)
- Documentation (`docs/`)
- Known structure for predictable testing

## Prerequisites

### For Fast Tests
- Frontend dev server running (or production build)
- No LLM required

### For Slow Tests
- Frontend dev server running
- Backend Rails server running
- LLM server accessible (configured in `.env`)

## Running Specific Tests

```bash
# Run a specific test by name
bin/test-e2e --grep "explores codebase structure"

# Run with headed browser (see what's happening)
bin/test-e2e --headed

# Run with debug mode (from frontend/e2e directory)
cd frontend/e2e
SKIP_WEBSERVER=1 npx playwright test codebase-exploration.spec.js --debug
```

## Expected Results

### All Tests Passing ✅
- Daedalus can explore codebases before planning
- Daedalus plans reference actual discovered files
- Sisyphus has all required tools
- Both agents work with same codebase path format

### Common Failures

**"text=Plan generated" not visible**
- Backend server not running
- LLM server not accessible
- Check `.env` configuration

**"text=math_service" not found in plan**
- Daedalus not using tools properly
- LLM not exploring codebase
- Check tool implementation

**"text=file_tree" not visible**
- Tool not registered with Sisyphus
- UI not displaying tools
- Check `AgentToolBuilder.execution_tools`

## Debugging

### View Test Results
```bash
# After test run, view HTML report (from frontend/e2e)
cd frontend/e2e
npx playwright show-report
```

### Check Test Artifacts
- Videos: `frontend/e2e/test-results/*/video.webm`
- Screenshots: `frontend/e2e/test-results/*/screenshot.png`
- Traces: `frontend/e2e/test-results/*/trace.zip`

### Enable Verbose Logging
```bash
DEBUG=pw:api bin/test-e2e
```

## CI/CD Recommendations

### On Pull Request
```bash
# Run fast tests only (~15 seconds)
bin/test-e2e fast
```

### On Merge to Main
```bash
# Run all tests (~2.5 minutes)
bin/test-e2e
```

### Nightly Build
```bash
# Run slow tests with full LLM integration (~2 minutes)
bin/test-e2e slow
```

## Maintenance

### Update Test Fixture
If you modify `test/fixtures/example_codebase/`, update test expectations:
- File names referenced in tests
- Expected content in plans
- Directory structure assertions

### Update UI Selectors
If UI components change, update selectors:
- Use `data-testid` attributes for stability
- Prefer semantic selectors over class names
- Keep selectors flexible with regex where appropriate

## Support

For detailed information, see: `CODEBASE_EXPLORATION_E2E_TESTS.md` in project root.

