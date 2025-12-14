# Project Plan: vllm Client Implementation

## Overview

After migrating from llama.cpp to vllm, our test suite shows 400 Bad Request errors because vllm uses `guided_json` for structured outputs instead of OpenAI's `json_schema` response format. Additionally, vllm models output `<think>` reasoning tags that should be captured as training data. This project refactors our current GenericLlmClient into VllmLlmClient that handles these vllm-specific requirements, while preserving the current OpenAI-compatible implementation as OpenAiLlmClient for future use.

## Goals

- Refactor GenericLlmClient to VllmLlmClient with vllm-specific parameter translation
- Create OpenAiLlmClient preserving current OpenAI API compatibility (unused)
- Implement automatic `response_format` to `guided_json` translation in VllmLlmClient
- Extract and record `<think>` tags as model thoughts in a new memories section
- Ensure all 267 tests pass with vllm backend
- Keep prompts, workflows, and other code completely unchanged

---

## Milestone 1 - Create Dual Client Architecture

Refactor the current GenericLlmClient into two separate clients: VllmLlmClient (active) and OpenAiLlmClient (preserved for future use).

### 1.1 - Create VllmLlmClient from GenericLlmClient

**Intent**: Refactor the current GenericLlmClient into VllmLlmClient that will handle vllm-specific parameter translation and response processing.

**Details**:
- Copy `app/services/generic_llm_client.rb` to `app/services/vllm_llm_client.rb`
- Rename module `GenericLlmClient` to `VllmLlmClient`
- Keep all existing functionality (singleton, retry wrapper, env building)
- Update class comments to reflect vllm-specific purpose
- This will be the actively used client
- Keep using same env vars: `API_KEY`, `LLM_URL`, `LLM_RETRY_ATTEMPTS`, `LLM_RETRY_DELAY`
- Will add parameter translation in subsequent steps

**Tests**:
- Test VllmLlmClient.instance returns a client
- Test VllmLlmClient.build_from_env creates client with correct config
- Test retry wrapper is applied when retry attempts > 0
- Test basic chat call works (without special parameters yet)
- Verify singleton pattern works correctly

---

### 1.2 - Create OpenAiLlmClient (Preserved for Future Use)

**Intent**: Preserve the current OpenAI-compatible client implementation for future use when we need OpenAI API compatibility.

**Details**:
- Copy `app/services/generic_llm_client.rb` to `app/services/openai_llm_client.rb`
- Rename module `GenericLlmClient` to `OpenAiLlmClient`
- Keep all existing functionality unchanged - this is the "preserved" version
- Update class comments to indicate this is for OpenAI API compatibility
- This client is NOT currently used but available for future needs
- Add comment explaining it uses OpenAI's native `response_format` with `json_schema`

**Tests**:
- Test OpenAiLlmClient.instance returns a client
- Test OpenAiLlmClient.build_from_env creates client
- Test it maintains OpenAI-compatible behavior in how it forms prompts
- Do not test against a live LLM
- Mark tests as demonstrating preservation of original logic

---

### 1.3 - Update GenericLlmClient to Delegate to VllmLlmClient

**Intent**: Make GenericLlmClient a thin wrapper that delegates to VllmLlmClient to maintain backward compatibility with existing code.

**Details**:
- Update `app/services/generic_llm_client.rb` to delegate all calls to VllmLlmClient
- Delegate all module methods (instance, build_from_env, etc.) to VllmLlmClient
- This allows all existing code (BasePrompt, workflows, etc.) to work unchanged
- Add comment explaining this delegates to VllmLlmClient
- Keep the file minimal - just delegation

**Tests**:
- Test GenericLlmClient.instance returns VllmLlmClient instance
- Test all existing code using GenericLlmClient still works
- Verify BasePrompt can use GenericLlmClient unchanged
- Verify DndChatWorkflow works unchanged

---

## Milestone 2 - Implement Parameter Translation in VllmLlmClient

Add automatic translation of OpenAI `response_format` parameters to vllm `guided_json` parameters.

### 2.1 - Create GuidedJsonBuilder Service

**Intent**: Build a service to convert OpenAI's JSON Schema format to vllm's guided_json JSON string format.

**Details**:
- Create new service class `app/services/guided_json_builder.rb`
- Implement class method `self.build_from_schema(schema_hash)` that:
  - Takes an OpenAI response_format schema hash
  - Extracts the actual JSON Schema from the nested structure (the `schema` key within `json_schema`)
  - Converts the Ruby hash to a JSON string using `JSON.generate` or `to_json`
  - Returns a JSON string suitable for vllm's `guided_json` parameter
- Input format (what OpenAI uses):
  ```ruby
  {
    type: "json_schema",
    json_schema: {
      name: "schema_name",
      strict: true,
      schema: { type: "object", properties: {...}, required: [...] }
    }
  }
  ```
- Output format (what vllm needs):
  - JSON string of the schema: `'{"type":"object","properties":{...},"required":[...]}'`
- Support all schema features used in our prompts:
  - Object type with properties
  - String, boolean, number types  
  - Array types with items
  - Enum constraints
  - Required fields
  - additionalProperties: false
- Handle edge cases like nil input (return nil) or malformed schema
- Keep the conversion lossless - preserve all constraints
- Use Ruby's native JSON library - no external templating gems needed

**Tests**:
- Test converting simple object schema (OutcomePrompt style with one string property)
- Test converting nested object schema with multiple levels
- Test converting array schema with enum (ActionDetectionPrompt style)
- Test extracting schema from OpenAI response_format nested structure
- Test handling of required fields array
- Test handling of additionalProperties: false
- Test with actual response_schema from OutcomePrompt
- Test with actual response_schema from ActionDetectionPrompt  
- Test with actual response_schema from TranslationPrompt
- Test error handling for nil input (returns nil)
- Test error handling for malformed/incomplete schema
- Test output is valid JSON string that can be parsed back
- Test that parsing the output JSON gives equivalent hash structure
- Test that all data types are preserved correctly (string, integer, boolean, array, object)
- Test that enum arrays are preserved exactly
- Test that nested required fields are maintained

---

### 2.2 - Add Parameter Translation to VllmLlmClient

**Intent**: Implement automatic translation in VllmLlmClient.chat method to convert OpenAI-style parameters to vllm-compatible parameters.

**Details**:
- Modify the `chat(parameters:)` method in ClientRetryWrapper class
- Before calling `@client.chat`, transform parameters:
  1. Check if `parameters[:response_format]` exists
  2. If it's a hash with `type: "json_schema"`, convert it:
     - Use GuidedJsonBuilder to convert schema
     - Remove `response_format` from parameters
     - Add `guided_json` parameter with the JSON string
  3. If response_format is anything else or nil, leave parameters unchanged
- Transformation should be transparent to callers
- Keep all other parameters unchanged (model, messages, tools, etc.)
- Add error handling if transformation fails (log and pass through original)
- Document the translation behavior in comments

**Tests**:
- Test chat with response_format containing json_schema gets translated
- Test chat without response_format passes through unchanged
- Test chat with other response_format types passes through
- Test guided_json parameter is correctly formatted JSON string
- Test messages, model, and tools parameters are unchanged
- Test actual vllm call succeeds with translated parameters
- Test error handling if GuidedJsonBuilder fails
- Verify BasePrompt calls work without modification

---

## Milestone 3 - Implement Response Processing in VllmLlmClient

Add automatic extraction of think tags and response filtering in VllmLlmClient.

### 3.1 - Create ModelInteractionMemory in Training Data Subdirectory

**Intent**: Create a new memory type in a training_data subdirectory to record model requests, responses, and extracted thinking for future training data use.

**Details**:
- Create `app/models/memories/training_data/` subdirectory
- Create `app/models/memories/training_data/model_interaction_memory.rb`
- Inherit from `BaseMemory`
- Structure records with: timestamp, request (model, messages, parameters), response (content, finish_reason), thoughts (extracted think content or nil)
- Override `append(interaction)` to append new interactions
- Override `to_h` to return array of interactions
- Keep memory focused on training data collection
- TODO: Add method to export interactions as training dataset
- TODO: Add filtering by date range for data collection
- TODO: Add format conversion for different training frameworks (JSONL, Parquet, etc.)

**Tests**:
- Test creating ModelInteractionMemory
- Test appending interactions
- Test serialization to_h returns proper structure
- Test timestamp is recorded correctly
- Test thoughts field handles nil gracefully

---

### 3.2 - Add MODEL_INTERACTIONS to MemoryKinds

**Intent**: Register the new memory type in the MemoryKinds registry.

**Details**:
- Add constant MODEL_INTERACTIONS with value "model_interactions" to `app/models/memory_kinds.rb`
- Register in the Registry to map MODEL_INTERACTIONS to the TrainingData::ModelInteractionMemory class
- This allows MemoryStore to automatically use the new memory type when model_interactions section is accessed

**Tests**:
- Test MemoryKinds::MODEL_INTERACTIONS is defined
- Test Registry.for(MODEL_INTERACTIONS) returns ModelInteractionMemory
- Test MemoryStore can create model_interactions section

---

### 3.3 - Create ThoughtExtractor Service

**Intent**: Build a service to extract and remove `<think>` tags from LLM responses, used by VllmLlmClient.

**Details**:
- Create `app/services/thought_extractor.rb`
- Implement class method `self.extract_and_filter(content)` that:
  - Takes response content string
  - Extracts all `<think>...</think>` content
  - Removes think tags from content
  - Returns hash: `{ content: "filtered", thoughts: "extracted or nil" }`
- Use regex pattern: `/<think>(.*?)<\/think>/m` for extraction
- Handle multiple think blocks (concatenate with newlines)
- Handle nested or malformed tags gracefully
- Trim whitespace from filtered content
- Return nil for thoughts if no think tags found
- If extraction fails, return original content with nil thoughts
- Make the service stateless

**Details**:
- Test extracting single think block
- Test extracting multiple think blocks
- Test filtering removes think tags completely
- Test handling of multi-line think content
- Test with real examples from test failures
- Test handling of nested/malformed tags
- Test nil/empty input handling
- Test thoughts is nil when no think tags present
- Test filtered content preserves non-think content exactly

---

### 3.4 - Integrate Response Processing into VllmLlmClient

**Intent**: Automatically extract thoughts and filter responses in VllmLlmClient, recording interactions to memory when available.

**Details**:
- Modify the `chat(parameters:)` method in ClientRetryWrapper
- After receiving response from underlying client:
  1. Extract content from response
  2. Use ThoughtExtractor.extract_and_filter(content)
  3. Replace content in response with filtered version
  4. Attempt to record to memory (if available):
     - Try to get MemoryStore from current workflow context (may not exist)
     - If MemoryStore available, record interaction with thoughts to MODEL_INTERACTIONS section
     - If not available, skip recording (graceful degradation)
  5. Return modified response with filtered content
- Recording should:
  - Check if DndChatController.current_memory_store is available
  - Update MODEL_INTERACTIONS section with request, response, and thoughts
  - Use append mode to build up interaction history
  - Fail gracefully if memory context unavailable
- Keep response processing transparent to callers
- Document behavior in comments
- TODO: Improve memory context passing mechanism (consider thread-local storage or dependency injection)

**Tests**:
- Test response content is filtered
- Test thoughts are extracted correctly
- Test response structure is preserved
- Test works without memory context available
- Test memory recording when context available (integration test)
- Test JSON responses are still parseable after filtering
- Test freeform text responses are clean
- Test BasePrompt receives filtered responses
- Verify think tags don't appear in any prompt tests

---

## Milestone 4 - Fix Specific Test Failures

Address the failing tests now that client handles everything.

### 4.1 - Verify Integration Tests Pass

**Intent**: Confirm that the 400 errors in LlmDndToolsIntegrationTest are resolved by the client's parameter translation.

**Details**:
- Run `LlmDndToolsIntegrationTest` tests
- Tests that were failing:
  - test_LLM_updates_memory_and_summarizes_quests
  - test_LLM_can_add_and_list_inventory
  - test_LLM_selects_dice_roll_for_advantage_request
- These should now pass because VllmLlmClient translates response_format to guided_json
- Verify tool selection works correctly
- Verify tool execution and parsing works
- No changes to test code should be needed

**Tests**:
- Run all LlmDndToolsIntegrationTest tests
- Verify all three previously failing tests pass
- Verify tool responses are correctly parsed
- Check that structured output is properly formatted

---

### 4.2 - Verify Prompt Tests Pass

**Intent**: Confirm that think tag issues are resolved by the client's response filtering.

**Details**:
- Run prompt tests
- Tests that were failing:
  - BasePromptTest#test_execute_returns_freeform_text_when_no_schema
  - NarrativePromptTest#test_execute_returns_narrative_string
- These should now pass because VllmLlmClient filters think tags before returning
- Responses should be clean without any think content
- No changes to prompt code or tests needed

**Tests**:
- Run BasePromptTest suite
- Run NarrativePromptTest suite
- Verify think tags are completely absent from responses
- Verify narrative content is clean
- Verify all other prompt tests still pass

---

### 4.3 - Fix Sandbox Path Issue

**Intent**: Resolve the SecurityError in DndWorkflowIntegrationTest related to path validation.

**Details**:
- Error: `Path 'sandbox/memory.json' is outside the sandbox`
- Issue is in MemoryStore validation expecting absolute path
- Root cause: relative path being passed somewhere in the chain
- Fix options:
  1. Update MemoryStore to resolve relative paths to absolute
  2. Fix CurrentContextTool to always pass absolute paths
  3. Update memory initialization to use absolute paths
- Choose the fix that's most robust and clear
- Ensure sandbox security is maintained
- Test with various path formats

**Tests**:
- Run DndWorkflowIntegrationTest#test_conversation_continuity_across_multiple_messages
- Verify SecurityError is resolved
- Test memory operations work correctly
- Verify sandbox validation still prevents access outside sandbox
- Test with absolute and relative paths

---

## Milestone 5 - Comprehensive Testing and Validation

Run full test suite and ensure all tests pass.

### 5.1 - Run Full Test Suite

**Intent**: Execute complete test suite to verify all 267 tests pass with the new client architecture.

**Details**:
- Run `ruby lib/test_runner.rb`
- All tests should pass without any prompt or workflow changes
- Document any remaining failures
- Fix any issues found:
  - Client translation bugs
  - Response filtering edge cases
  - Memory recording issues
- Ensure no regressions introduced
- Verify test execution is stable

**Tests**:
- All 267 tests pass
- No intermittent failures
- Test execution completes in reasonable time
- All prompt types work correctly
- All integration tests pass
- All controller tests pass
- No errors in logs

---

### 5.2 - Performance Validation

**Intent**: Ensure the client translation and response processing don't significantly impact performance.

**Details**:
- Measure overhead of:
  - Parameter translation (GuidedJsonBuilder)
  - Response filtering (ThoughtExtractor)
  - Memory recording attempts
- Compare response times before and after changes
- Ensure overhead is minimal (< 10ms per request)
- Profile if any bottlenecks found
- Optimize if needed

**Tests**:
- Response times remain acceptable
- No significant latency added by client processing
- Memory recording doesn't slow down requests
- Integration tests complete in reasonable time

---

## Milestone 6 - Documentation

Document the new client architecture and memory system.

### 6.1 - Create Service Documentation

**Intent**: Document the new services for future maintainers.

**Details**:
- Create `docs/references/app/services/vllm_llm_client.md`
- Create `docs/references/app/services/openai_llm_client.md`
- Create `docs/references/app/services/guided_json_builder.md`
- Create `docs/references/app/services/thought_extractor.md`
- Update `docs/references/app/services/generic_llm_client.md` (now delegates)
- Create `docs/references/app/models/memories/training_data/model_interaction_memory.md`
- Update `docs/references/app/base_references.md` with new files
- Follow leaf-node documentation pattern
- Include:
  - Purpose and responsibilities
  - Public API methods
  - Integration points
  - Configuration options
  - Usage examples

**Tests**:
- Review all documentation for accuracy
- Verify examples are correct
- Ensure cross-references are valid
- Check file tree is up to date

---

### 6.2 - Update Architecture Documentation

**Intent**: Document the dual client architecture and vllm compatibility approach.

**Details**:
- Update `docs/references/architecture_diagram.md`:
  - Add section on dual client architecture
  - Document VllmLlmClient as active client
  - Document OpenAiLlmClient as preserved for future use
  - Explain automatic parameter translation
  - Explain automatic response filtering
  - Document model interaction memory system
  - Note that prompts and workflows remain unchanged
- Add troubleshooting guidance
- Include migration notes
- Document TODOs for training data export

**Tests**:
- Verify documentation matches implementation
- Check diagrams are updated
- Ensure configuration is clear

---

### 6.3 - Code Cleanup

**Intent**: Ensure code quality and remove any temporary code.

**Details**:
- Run rubocop and fix style violations
- Remove any debug logging
- Add inline comments for complex client logic
- Ensure error messages are clear
- Review error handling in clients
- Check for unused code
- Verify consistent naming
- Add TODO comments for future enhancements:
  - Training data export functionality
  - Better memory context passing
  - Performance optimizations

**Tests**:
- Rubocop passes
- No debug output
- Code review finds no issues
- Error paths are tested

---

## Review Checklist

- [x] Every step has an Intent section
- [x] Every step has a Details section with specific requirements  
- [x] Every step has a Tests section
- [x] Steps are focused and completable in one session
- [x] Milestones represent logical, demonstrable progress
- [x] No implementation code appears in the plan
- [x] Test requirements cover happy path and edge cases
- [x] Plan focuses on execution, not research
- [x] Plan addresses actual observed test failures
- [x] Documentation requirements are included
- [x] Client-driven architecture (no prompt/workflow changes)
- [x] Two separate clients (VllmLlmClient and OpenAiLlmClient)
- [x] No VLLM_MODE environment variable
- [x] Memory system for model interactions
