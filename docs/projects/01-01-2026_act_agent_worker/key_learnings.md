# Sisyphus Project - Key Learnings

This document captures the important lessons learned during the Sisyphus Agent Worker project implementation.

## 1. Symbol Standardization at Boundaries

**What we learned**: Mixing string and symbol keys throughout the application creates confusion and bugs.

**Solution**: Symbolize once at the interface boundary (LLM client) and use symbols exclusively in application code.

**Implementation**:
- `GenericLlmClient` now converts all LLM responses to symbol keys
- `BasePrompt` uses symbols throughout
- No defensive `hash["key"] || hash[:key]` patterns needed

**Impact**: Eliminated an entire class of bugs and made code more predictable.

## 2. Context-Aware Tools

**What we learned**: Generic tools that work "everywhere" don't work well anywhere. Tools need context about where and how they're operating.

**Solution**: Create namespaced, context-aware tools that accept context parameters.

**Implementation**:
- Created `Sisyphus::WriteFileTool`, `Sisyphus::BashTool`, `Sisyphus::ReadFileTool`
- Tools accept `codebase_path` parameter
- Workflows inject context automatically
- Tools validate safety (no escaping codebase)

**Impact**: Tools actually work! Files get created in the right place, commands run in the right directory.

## 3. LLM Prompt Examples Drive Behavior

**What we learned**: Abstract descriptions don't work well with LLMs. "Return an object with params" leads to empty or malformed responses.

**Solution**: Provide concrete JSON examples showing exact format with real values.

**Before**:
```ruby
"Return a JSON object with tool_sequence array and expected_outcome string"
```

**After**:
```ruby
## Example Tool Calls

{
  "tool_sequence": [
    {
      "tool": "write_file",
      "params": {
        "path": "hello.rb",
        "content": "#!/usr/bin/env ruby\nputs 'Hello, World!'"
      },
      "rationale": "Create the hello.rb file"
    }
  ]
}
```

**Impact**: LLM went from returning 0 tools to correctly planning 2-3 tools per step.

## 4. Method Name Conflicts in Inheritance

**What we learned**: Subclass methods can accidentally override parent methods with different signatures, causing cryptic "wrong number of arguments" errors.

**Problem**: `StepPlanningPrompt#format_context` (no args) overrode `BasePrompt#format_context(context, question:)` (2 args).

**Solution**: Use descriptive, specific names. Changed to `format_assembled_context` to avoid conflict.

**Impact**: Prevented runtime errors that only show up during execution.

## 5. Prompts Should Build Their Own Messages

**What we learned**: Workflows building prompt messages manually leads to inconsistent formatting.

**Solution**: Prompts encapsulate message building via `build_user_message` methods.

**Impact**: Consistent formatting, easier updates, better separation of concerns.

## 6. Test Against Real LLMs

**What we learned**: Mocking LLM responses hides integration issues. The system "worked" in tests but failed in reality.

**Solution**: Run tests with real LLM calls (marked as `:slow`). Test execution times prove LLM integration (48s vs 0.007s).

**Impact**: Discovered planning was returning 0 tools, which we wouldn't have caught with mocks.

## 7. OOP Refactoring Pays Off

**What we learned**: Strict adherence to OOP patterns (no hashes, strict types, fail-fast) made debugging much easier.

**Example**: When `Planning::Step` failed, error messages were clear: "milestone_number must be Integer, got String".

**Impact**: Problems surfaced immediately at construction time, not deep in execution.

## 8. Incremental Integration Testing

**What we learned**: Don't wait until "everything is done" to test end-to-end.

**Approach**:
1. Unit tests first (fast)
2. Workflow tests with real LLM (medium)
3. End-to-end integration tests (slow)
4. Debug with small scripts showing exact behavior

**Impact**: Found issues early. Each layer validated the layer below.

## 9. Tool Parameter Transparency

**What we learned**: LLMs need to see exact parameter names tools expect.

**Solution**: Document tools with explicit parameter lists:
```ruby
**write_file**:
- Parameters: `path` (string), `content` (string)
- Example: {"path": "app.rb", "content": "puts 'hi'"}
```

**Impact**: LLM correctly formats parameters matching tool schemas.

## 10. Safety Validations in Tools

**What we learned**: Tools that can modify the filesystem need safety checks.

**Implementation**:
- Validate codebase_path exists
- Resolve symbolic links
- Check operations stay within bounds
- Return errors rather than raising exceptions

**Impact**: Tools fail gracefully with clear error messages.

## Summary Statistics

**Before fixes**:
- 0 tools planned by LLM
- 0 files created
- Evaluation: "Failed with 0.2 confidence"

**After fixes**:
- 2-3 tools planned correctly
- Files created with correct content
- Evaluation: "Passed with 1.0 confidence"

**Test Results**:
- 350+ tests passing
- End-to-end: 3/3 ✅
- Real LLM integration verified
- Actual file creation confirmed

## Files Updated

1. `docs/references/oop-patterns.md` - Added 5 new lessons
2. `rules/startup-rule.mdc` - Added 5 new rules
3. `app/tools/sisyphus/` - Created 3 context-aware tools
4. `app/workflows/step_execution_workflow.rb` - Integrated real tool execution
5. `app/prompts/execution/step_planning_prompt.rb` - Added concrete examples
6. `app/services/generic_llm_client.rb` - Added symbol standardization

## Key Takeaway

**Build it right from the start**: Following OOP patterns strictly, using symbols consistently, and testing with real integrations saved significant debugging time. The extra upfront work paid off when everything "just worked" once the pieces were properly connected.

---

*Document created: January 1, 2026*
*Project: Sisyphus Agent Worker*
*Status: 100% Complete ✅*

