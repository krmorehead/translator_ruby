# Project Plan: vllm Think Tag Filtering

## Overview

After migrating to vllm, our LLM responses contain `<think>...</think>` reasoning tags that need to be filtered from final outputs. This project adds automatic think tag extraction and filtering to GenericLlmClient, returning thoughts as a separate field on the response payload. Thoughts are threaded through the entire chain (Client -> Prompt -> Workflow) for use in narratives and memory recording.

## Goals

- Extract and filter `<think>` tags from LLM responses
- Return thoughts as separate field on response payload
- Thread thoughts through BasePrompt to workflows
- Record thoughts in ModelInteractionMemory for training data
- Ensure all tests pass with clean, think-tag-free responses
- Keep existing client architecture (no split needed)

---

## Milestone 1 - Think Tag Extraction and Filtering

Extract think tags from responses and return them as a separate field.

### 1.1 - Create ThoughtExtractor Service

**Intent**: Build a service to extract and remove `<think>` tags from LLM responses.

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

**Tests**:
- Test extracting single think block
- Test extracting multiple think blocks
- Test filtering removes think tags completely
- Test handling of multi-line think content
- Test with real examples from vllm responses
- Test handling of nested/malformed tags
- Test nil/empty input handling
- Test thoughts is nil when no think tags present
- Test filtered content preserves non-think content exactly
- Test JSON content remains parseable after filtering

---

### 1.2 - Update GenericLlmClient to Process Responses

**Intent**: Modify GenericLlmClient to extract think tags and include thoughts in response payload.

**Details**:
- Update `app/services/generic_llm_client.rb`
- Ensure ClientRetryWrapper always wraps the client (default retry attempts to 1)
- Modify `chat(parameters:)` in ClientRetryWrapper to:
  1. Call underlying client
  2. Extract content from response
  3. Use ThoughtExtractor.extract_and_filter(content)
  4. Deep copy response (use JSON round-trip)
  5. Replace content with filtered version
  6. Add `thoughts` field to response payload at top level
  7. Return modified response
- Response structure becomes:
  ```ruby
  {
    "choices" => [...],  # with filtered content
    "thoughts" => "extracted thoughts or nil"
  }
  ```
- Keep response processing transparent to most callers
- Document behavior in comments

**Tests**:
- Test response content is filtered
- Test thoughts field is added to response
- Test thoughts is nil when no think tags present
- Test response structure is preserved
- Test JSON responses are still parseable after filtering
- Test freeform text responses are clean
- Test multiple calls maintain separation of thoughts

---

## Milestone 2 - Thread Thoughts Through Prompt Layer

Make thoughts available to prompts and return them from execute.

### 2.1 - Update BasePrompt to Return Thoughts

**Intent**: Modify BasePrompt.execute to return both content and thoughts.

**Details**:
- Update `app/prompts/base_prompt.rb`
- Modify `execute(prompt:, context:)` to:
  1. Call client as usual
  2. Extract thoughts from response payload
  3. Parse content as before
  4. Return hash instead of just content: `{ content: parsed_content, thoughts: thoughts }`
- For prompts with response_schema (structured JSON):
  - Return `{ content: parsed_json_hash, thoughts: thoughts }`
- For prompts without response_schema (freeform text):
  - Return `{ content: text_string, thoughts: thoughts }`
- Thoughts default to nil if not present in response
- Update parse_response to handle new return format
- Maintain backward compatibility by having execute return hash with :content key

**Tests**:
- Test execute returns hash with :content and :thoughts keys
- Test structured JSON prompts return parsed JSON in :content
- Test freeform prompts return string in :content
- Test thoughts field contains extracted thoughts
- Test thoughts is nil when no think tags present
- Test all existing prompt tests still pass (they access [:content])

---

### 2.2 - Update Subclass Prompts to Handle New Format

**Intent**: Update prompt subclasses to work with new hash return format.

**Details**:
- Update prompts that override execute to handle hash return:
  - `ActionDetectionPrompt` - extract :content for array handling
  - `NarrativePrompt` - extract :content for to_s conversion
- Most prompts don't override execute, so they automatically get new behavior
- Ensure each override properly accesses result[:content]
- Pass through thoughts unchanged

**Tests**:
- Test ActionDetectionPrompt returns hash with :content array
- Test NarrativePrompt returns hash with :content string
- Test thoughts field passes through in all prompt types
- Test all prompt tests still pass

---

## Milestone 3 - Thread Thoughts Through Workflow Layer

Pass thoughts from prompts through to workflows.

### 3.1 - Update DndChatWorkflow to Receive Thoughts

**Intent**: Modify DndChatWorkflow to receive and use thoughts from prompts.

**Details**:
- Update `app/services/dnd_chat_workflow.rb`
- Modify methods that call prompts to handle hash return:
  - `detect_actions` - extract :content for actions array, capture :thoughts
  - `generate_narrative` - extract :content for narrative string, capture :thoughts
  - Other prompt calls as needed
- For simplest implementation: use most recent thoughts (from narrative generation)
- Add thoughts to workflow result hash:
  ```ruby
  {
    narrative: narrative_text,
    actions: [...],
    conversation: conv,
    thoughts: latest_thoughts  # from narrative prompt
  }
  ```
- Thoughts can be nil if not present
- Document which thoughts are included (narrative thoughts for now)

**Tests**:
- Test workflow result includes thoughts field
- Test thoughts contain content from narrative generation
- Test thoughts is nil when not present
- Test workflow still functions correctly with new format
- Test all workflow tests still pass

---

## Milestone 4 - Create Model Interaction Memory System

Add memory system to record model interactions including thoughts.

### 4.1 - Create ModelInteractionMemory

**Intent**: Create memory type to record model interactions including extracted thoughts.

**Details**:
- Create `app/models/memories/training_data/` subdirectory
- Create `app/models/memories/training_data/model_interaction_memory.rb`
- Inherit from `BaseMemory`
- Structure records with:
  - timestamp
  - request (model, messages, parameters)
  - response (content, finish_reason)
  - thoughts (extracted think content or nil)
- Override `append(store:, interaction:)` to append new interactions
- Override `to_h(store:)` to return array of interactions
- Override `summarize` to return count of interactions
- Set `weight` to 0.0 (training data is metadata, not narrative content)
- TODO: Add method to export interactions as training dataset
- TODO: Add filtering by date range
- TODO: Add format conversion (JSONL, Parquet, etc.)

**Tests**:
- Test creating ModelInteractionMemory
- Test appending interactions
- Test serialization to_h returns proper structure
- Test timestamp is recorded correctly
- Test thoughts field handles nil gracefully
- Test weight is 0.0
- Test summarize returns interaction count

---

### 4.2 - Add MODEL_INTERACTIONS to MemoryKinds

**Intent**: Register the new memory type.

**Details**:
- Add constant MODEL_INTERACTIONS = "model_interactions" to `app/models/memory_kinds.rb`
- Add to ALL array
- Register in `app/models/memories/registry.rb` to map to TrainingData::ModelInteractionMemory
- This allows MemoryStore to use the new memory type

**Tests**:
- Test MemoryKinds::MODEL_INTERACTIONS is defined
- Test Registry.for(MODEL_INTERACTIONS) returns ModelInteractionMemory
- Test MemoryStore can create model_interactions section
- Test ModelInteractionMemory appears in Registry::ALL

---

### 4.3 - Record Interactions in GenericLlmClient

**Intent**: Record all LLM interactions to memory when memory store is available.

**Details**:
- Update ClientRetryWrapper in `app/services/generic_llm_client.rb`
- After processing response with thoughts:
  1. Check if memory store is available (thread-local or passed context)
  2. If available, record interaction:
     - Request: model, messages, key parameters
     - Response: filtered content, finish_reason
     - Thoughts: extracted thoughts
  3. Use ModelInteractionMemory.append(store: memory_store, interaction: {...})
  4. Fail gracefully if memory not available (optional recording)
- For simplest implementation: skip memory recording for now (TODO for future)
- Add TODO comment for memory context passing mechanism
- Document that recording is optional and doesn't affect responses

**Tests**:
- Test client works without memory context (graceful degradation)
- Test thoughts are in response regardless of memory availability
- Integration test with memory store when implemented

---

## Milestone 5 - Testing and Validation

Verify all tests pass with new architecture.

### 5.1 - Verify Prompt Tests Pass

**Intent**: Confirm think tag filtering resolves prompt test failures.

**Details**:
- Run prompt tests (BasePromptTest, NarrativePromptTest, etc.)
- Update tests to access result[:content] instead of raw result
- Tests should now pass with clean responses
- No think tags should appear in content

**Tests**:
- Run BasePromptTest suite - all tests pass
- Run NarrativePromptTest suite - all tests pass
- Run ActionDetectionPrompt tests - all pass
- Verify think tags are absent from all content
- Verify thoughts field is present when expected

---

### 5.2 - Verify Workflow Tests Pass

**Intent**: Confirm workflows work with new hash return format.

**Details**:
- Run workflow tests (DndChatWorkflow tests)
- Update tests to expect thoughts field in results
- Workflows should function correctly with new format
- No code changes needed in workflows

**Tests**:
- Run DndChatWorkflow tests - all pass
- Verify workflow results include thoughts field
- Verify narratives are clean (no think tags)
- Verify actions are detected correctly

---

### 5.3 - Run Full Test Suite

**Intent**: Verify no regressions across entire codebase.

**Details**:
- Run `ruby lib/test_runner.rb`
- All tests should pass or match pre-project baseline
- Document any failures and investigate
- Verify test execution is stable

**Tests**:
- All tests pass or match baseline
- No intermittent failures
- No regressions in existing functionality

---

## Milestone 6 - Documentation

Document the think tag filtering and thoughts flow.

### 6.1 - Create Service Documentation

**Intent**: Document ThoughtExtractor and updated GenericLlmClient.

**Details**:
- Create `docs/references/app/services/thought_extractor.md`
- Update `docs/references/app/services/generic_llm_client.md`
  - Document think tag filtering
  - Document thoughts field in responses
  - Document always-on wrapper for response processing
- Create `docs/references/app/models/memories/training_data/model_interaction_memory.md`
- Update `docs/references/app/base_references.md`
- Follow leaf-node documentation pattern
- Include usage examples

**Tests**:
- Review documentation for accuracy
- Verify examples are correct
- Ensure cross-references are valid

---

### 6.2 - Update Architecture Documentation

**Intent**: Document think tag filtering architecture.

**Details**:
- Update `docs/references/architecture_diagram.md`:
  - Add section on think tag filtering
  - Document thoughts flow through layers
  - Document response payload structure
  - Document ModelInteractionMemory system
  - Note prompts and workflows updated to handle hash returns
- Add troubleshooting guidance
- Document TODOs for future enhancements
- Include examples of thoughts in workflow results

**Tests**:
- Verify documentation matches implementation
- Ensure diagrams are updated
- Configuration is clear

---

### 6.3 - Update BasePrompt Documentation

**Intent**: Document new return format from prompts.

**Details**:
- Update `docs/references/app/prompts/base_prompt.md`
- Document that execute now returns `{ content: ..., thoughts: ... }`
- Provide examples of accessing both content and thoughts
- Note backward compatibility considerations
- Show how subclasses should handle the format

**Tests**:
- Examples are correct
- Format is clear
- Migration path documented

---

### 7.1 - Final Code Review

**Intent**: Ensure code quality and consistency.

**Details**:
- Run rubocop and fix style violations
- Remove any debug logging
- Add inline comments for complex logic
- Ensure error messages are clear
- Review error handling
- Verify consistent naming
- Add TODO comments for future enhancements:
  - Memory recording in client (thread-local context)
  - Training data export functionality
  - Expose thoughts in API responses

**Tests**:
- Rubocop passes
- No debug output
- Error paths are tested

---

## Architecture Summary

### Response Payload Structure

```ruby
# LLM client response
{
  "choices" => [
    {
      "message" => {
        "content" => "filtered content (no think tags)"
      }
    }
  ],
  "thoughts" => "extracted think tag content or nil"
}
```

### Thoughts Flow

```
LLM Response (with <think> tags)
  ↓
GenericLlmClient (filters tags, adds thoughts field)
  ↓
BasePrompt (returns { content: parsed, thoughts: thoughts })
  ↓
Workflow (receives hash, uses content and thoughts)
  ↓
Workflow Result (includes thoughts field)
```

### Key Design Decisions

1. **No client split**: Keep single GenericLlmClient, add filtering inline
2. **Thoughts as payload field**: Not hidden, explicitly part of response
3. **Hash return from prompts**: Consistent interface with :content and :thoughts
4. **Simplest thoughts selection**: Use most recent (narrative) thoughts in workflow
5. **Optional memory recording**: Thoughts available in payload regardless

---

## Review Checklist

- [x] Every step has Intent, Details, and Tests sections
- [x] Steps are focused and completable
- [x] Milestones represent logical progress
- [x] No implementation code in plan
- [x] Test requirements cover happy path and edge cases
- [x] Documentation requirements included
- [x] No client split (single GenericLlmClient)
- [x] Thoughts threaded through entire chain
- [x] Simplest implementation approach
- [x] Memory system for training data
- [x] Clean architecture with clear responsibility boundaries
