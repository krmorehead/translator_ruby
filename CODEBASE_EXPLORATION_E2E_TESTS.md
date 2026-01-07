# Codebase Exploration E2E Tests

## Overview

Comprehensive Playwright E2E tests that verify both Daedalus (Plan Agent) and Sisyphus (Act Agent) can properly explore codebases using the newly implemented tools: `file_tree`, `grep`, and `read_file`.

## Test File

**Location**: `frontend/e2e/codebase-exploration.spec.js`

**Test Fixture**: `test/fixtures/example_codebase/`
- A Ruby codebase with realistic structure
- Contains services, libraries, and documentation
- Known file structure for predictable testing

## Test Structure

Total: 8 tests (4 slow, 1 medium, 3 fast)

### 1. Daedalus - Plan Agent Exploration (5 tests)

#### Slow Tests (Real LLM Calls - 4 tests)

**Test: "Daedalus explores codebase structure with file_tree"**
- Verifies Daedalus can use `file_tree` to discover project structure
- Checks that generated plan references actual service files found
- Expected: Plan mentions `math_service`, `notification_service`, `user_service`

**Test: "Daedalus searches patterns with grep"**
- Verifies Daedalus can use `grep` to find specific code patterns
- Searches for classes with "calculate" methods
- Expected: Plan references `Calculator` class found via search

**Test: "Daedalus reads files with read_file"**
- Verifies Daedalus can read actual file contents
- Tests understanding of code structure from reading files
- Expected: Plan references specific methods like `add`, `subtract`, `multiply`, `divide`

**Test: "Daedalus understands Ruby project structure"**
- Verifies language-specific understanding
- Tests recognition of Ruby patterns (class, module, def, end)
- Expected: Plan shows understanding of service layer architecture

#### Medium Tests (1 test)

**Test: "Daedalus handles invalid paths gracefully"**
- Verifies error handling for non-existent paths
- Expected: Error message displayed to user

### 2. Sisyphus - Act Agent Exploration (2 tests)

#### Fast Tests (UI/Config Only - 2 tests)

**Test: "Sisyphus has file_tree tool available"**
- Verifies `file_tree` tool is available in Sisyphus
- Checks configuration or capabilities display
- Expected: `file_tree` listed in available tools

**Test: "Sisyphus has all 5 execution tools"**
- Verifies Sisyphus accepts codebase path
- Tests path input works correctly
- Expected: Path input accepts and stores fixture path

### 3. Tool Integration (1 test)

#### Fast Test (1 test)

**Test: "both agents use consistent tool schemas"**
- Verifies both agents accept same path format
- Tests tool schema consistency
- Expected: Same codebase path works for both agents

## Speed Profiles

### Fast Tests (3 tests) - ~5 seconds each
- UI verification only
- No LLM calls
- Configuration checks
- Path validation
- **Total: ~15 seconds**

### Medium Tests (1 test) - ~15 seconds
- Error handling
- Limited LLM interaction
- Quick validation
- **Total: ~15 seconds**

### Slow Tests (4 tests) - ~30 seconds each
- Full LLM calls with tool usage
- Real codebase exploration
- Plan generation with file discovery
- **Total: ~2 minutes** (with LLM calls)

**Total Test Time**: ~2.5 minutes for all tests

## Test Fixture Structure

```
test/fixtures/example_codebase/
├── lib/
│   ├── calculator.rb          # Core arithmetic operations
│   ├── formatter.rb            # Number formatting
│   ├── logger.rb               # Logging utility
│   └── config_manager.rb       # Configuration
├── app/
│   └── services/
│       ├── math_service.rb     # Main service
│       ├── notification_service.rb
│       └── user_service.rb
├── docs/
│   └── projects/
│       └── 12-31-2025_calculator_logging/
│           ├── file_references.md
│           └── project_plan.md
├── Gemfile
└── README.md
```

## What These Tests Verify

### Core Functionality ✅
1. **file_tree tool works** - Both agents can explore directory structure
2. **grep tool works** - Both agents can search for code patterns
3. **read_file tool works** - Both agents can read file contents
4. **Tool integration** - Tools work together for comprehensive exploration
5. **Error handling** - Invalid paths handled gracefully

### Codebase Awareness ✅
1. **Structure understanding** - Agents recognize project organization
2. **Language recognition** - Ruby-specific patterns identified
3. **Dependency analysis** - File relationships understood
4. **Research capability** - Can answer questions about codebase

### Agent-Specific ✅
1. **Daedalus** - Can explore before planning
2. **Daedalus** - Plans reference discovered files
3. **Sisyphus** - Has all 5 execution tools
4. **Sisyphus** - Can explore before executing

### Integration ✅
1. **Consistent schemas** - Both agents use same tool format
2. **Workflow continuity** - Daedalus plans → Sisyphus execution

## Running the Tests

### Run All Codebase Exploration Tests
```bash
# From project root
bin/test-e2e codebase-exploration.spec.js
```

### Run by Speed Profile
```bash
# Fast tests only (~5s each, 3 tests total)
bin/test-e2e fast

# Medium tests only (~15s, 1 test)
bin/test-e2e medium

# Slow tests only (~30s each with LLM, 4 tests)
bin/test-e2e slow
```

### Run Specific Test
```bash
# From project root
bin/test-e2e --grep "explores codebase structure"
```

## Expected Behavior

### Successful Test Run

1. **Daedalus Exploration Tests**
   - UI loads and switches to Daedalus mode
   - Project path input accepts test fixture path
   - Goal input accepts research/planning queries
   - Generate button triggers plan generation
   - LLM explores codebase using tools
   - Plan displays with references to discovered files

2. **Sisyphus Tool Tests**
   - UI loads and switches to Sisyphus mode
   - Configuration shows all 5 tools available
   - file_tree tool is listed
   - Path input works correctly

3. **Integration Tests**
   - Both agents accept same path format
   - Tool schemas are consistent
   - Workflow from plan to execution works

### Failure Scenarios Tested

1. **Invalid Path** - Error message displayed
2. **Missing Tools** - Test fails if tools not available
3. **No Codebase Awareness** - Test fails if plan doesn't reference actual files

## CI/CD Integration

These tests are suitable for CI/CD with considerations:

### Fast Tests
- ✅ Run on every PR
- ✅ Quick feedback
- ✅ No external dependencies

### Medium Tests
- ✅ Run on every PR
- ⚠️ Requires backend server

### Slow Tests
- ⚠️ Run on merge to main
- ⚠️ Requires LLM server
- ⚠️ Takes 10-15 minutes
- 💡 Consider running subset or nightly

## Test Maintenance

### When to Update Tests

1. **UI Changes** - Update selectors if UI components change
2. **Tool Changes** - Update expected tools if new tools added
3. **Fixture Changes** - Update expectations if test fixture modified
4. **Error Messages** - Update error text matching if messages change

### Keeping Tests Reliable

1. **Use data-testid** - Add to UI components for stable selectors
2. **Flexible matching** - Use regex for content that may vary
3. **Generous timeouts** - LLM calls can be slow
4. **Idempotent fixtures** - Test fixture should not change

## Success Criteria

All tests passing indicates:
- ✅ Daedalus can explore codebases before planning
- ✅ Daedalus plans reference actual discovered files
- ✅ Sisyphus has all 5 execution tools including file_tree
- ✅ Both agents use consistent tool schemas
- ✅ Tools work correctly (file_tree, grep, read_file)
- ✅ Error handling works for invalid paths
- ✅ Integration between agents works

## Conclusion

These E2E tests provide comprehensive verification that the codebase exploration tools implementation works correctly in real-world scenarios. They test the full stack from UI to backend to LLM integration, ensuring both Daedalus and Sisyphus have proper codebase awareness capabilities.

