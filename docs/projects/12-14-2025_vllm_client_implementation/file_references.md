# File References: vllm Think Tag Filtering

## Existing Files

| File Path | Description | Changes Needed |
|-----------|-------------|----------------|
| `app/services/generic_llm_client.rb` | Current LLM client (singleton wrapper) | Add think tag filtering and thoughts field to response |
| `app/prompts/base_prompt.rb` | Abstract base class for all LLM prompts | Update execute to return hash with :content and :thoughts |
| `app/prompts/action_detection_prompt.rb` | Action detection prompt | Update to handle hash return from execute |
| `app/prompts/narrative_prompt.rb` | Narrative generation prompt | Update to handle hash return from execute |
| `app/services/dnd_chat_workflow.rb` | DnD chat workflow orchestrator | Update to handle thoughts from prompts, include in result |
| `app/models/memory_kinds.rb` | Registry of memory section types | Add MODEL_INTERACTIONS constant |
| `app/models/memories/registry.rb` | Memory type registry | Register ModelInteractionMemory |
| `app/models/memories/base_memory.rb` | Base class for memory types | Parent class for ModelInteractionMemory |
| `test/prompts/base_prompt_test.rb` | Tests for BasePrompt | Update to access result[:content] |
| `test/prompts/narrative_prompt_test.rb` | Tests for narrative generation | Update to access result[:content] |
| `test/services/dnd_chat_workflow_test.rb` | Tests for workflow | Update to expect thoughts in results |
| `lib/test_runner.rb` | Custom test runner | Used to run full test suite |
| `docs/references/app/base_references.md` | App documentation index | Update with new files |
| `docs/references/app/services/generic_llm_client.md` | GenericLlmClient docs | Update with filtering behavior |
| `docs/references/app/prompts/base_prompt.md` | BasePrompt docs | Update with new return format |

## New Files

| File Path | Description | Created In |
|-----------|-------------|------------|
| `app/services/thought_extractor.rb` | Extracts and filters <think> tags from responses | Step 1.1 |
| `app/models/memories/training_data/model_interaction_memory.rb` | Memory type for recording model interactions | Step 4.1 |
| `test/services/thought_extractor_test.rb` | Tests for ThoughtExtractor | Step 1.1 |
| `test/models/memories/training_data/model_interaction_memory_test.rb` | Tests for ModelInteractionMemory | Step 4.1 |
| `docs/references/app/services/thought_extractor.md` | Documentation for ThoughtExtractor | Step 6.1 |
| `docs/references/app/models/memories/training_data/model_interaction_memory.md` | Documentation for ModelInteractionMemory | Step 6.1 |

## Document Tree

### Before
```
translator_ruby/
├── app/
│   ├── models/
│   │   ├── memory_kinds.rb
│   │   └── memories/
│   │       ├── base_memory.rb
│   │       └── registry.rb
│   ├── prompts/
│   │   ├── base_prompt.rb
│   │   ├── action_detection_prompt.rb
│   │   └── narrative_prompt.rb
│   └── services/
│       ├── generic_llm_client.rb
│       └── dnd_chat_workflow.rb
└── test/
    ├── prompts/
    │   ├── base_prompt_test.rb
    │   └── narrative_prompt_test.rb
    └── services/
        └── dnd_chat_workflow_test.rb
```

### After
```
translator_ruby/
├── app/
│   ├── models/
│   │   └── memories/
│   │       └── training_data/
│   │           └── model_interaction_memory.rb
│   └── services/
│       └── thought_extractor.rb
├── test/
│   ├── models/
│   │   └── memories/
│   │       └── training_data/
│   │           └── model_interaction_memory_test.rb
│   └── services/
│       └── thought_extractor_test.rb
└── docs/
    ├── projects/
    │   └── 12-14-2025_vllm_client_implementation/
    │       ├── project_plan.md
    │       └── file_references.md
    └── references/
        └── app/
            ├── models/
            │   └── memories/
            │       └── training_data/
            │           └── model_interaction_memory.md
            └── services/
                └── thought_extractor.md
```

## Test Failures Addressed

### Think Tag Issues (2 failures) - TO BE RESOLVED

- `BasePromptTest#test_execute_returns_freeform_text_when_no_schema`
- `NarrativePromptTest#test_execute_returns_narrative_string`
- **Root Cause**: vllm model returns `<think>...</think>` tags in responses
- **Fix**: GenericLlmClient filters responses with ThoughtExtractor automatically
- **Status**: Tests need update to access result[:content]

## Response Payload Structure

```ruby
# Client returns
{
  "choices" => [
    {
      "message" => {
        "content" => "filtered content"  # No think tags
      }
    }
  ],
  "thoughts" => "extracted thoughts or nil"  # NEW field
}

# Prompts return
{
  content: parsed_content,    # JSON hash or string
  thoughts: "extracted or nil"  # Pass-through from client
}

# Workflow returns
{
  narrative: "story text",
  actions: [...],
  conversation: conv,
  thoughts: "latest thoughts"  # From narrative prompt
}
```

## Thoughts Flow

```
┌─────────────────────┐
│   LLM Response      │
│ <think>...</think>  │
│ Actual content      │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│ GenericLlmClient    │
│ - Extract thoughts  │
│ - Filter tags       │
│ - Add to payload    │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│   BasePrompt        │
│ - Parse content     │
│ - Pass thoughts     │
│ - Return hash       │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│ DndChatWorkflow     │
│ - Use content       │
│ - Capture thoughts  │
│ - Include in result │
└─────────────────────┘
```

## Architecture Changes

### Client Layer
- `GenericLlmClient` filters think tags automatically
- Always wraps client (retry attempts defaults to 1)
- Adds `thoughts` field to response payload
- No split clients needed (no VllmLlmClient/OpenAiLlmClient)

### Prompt Layer
- `BasePrompt.execute` returns hash: `{ content: ..., thoughts: ... }`
- Subclasses extract `:content` for their specific handling
- Thoughts pass through transparently

### Workflow Layer
- Workflows receive hash from prompts
- Extract content for processing
- Capture thoughts (simplest: use narrative thoughts)
- Include thoughts in workflow results

### Memory Layer
- `ModelInteractionMemory` records interactions with thoughts
- Optional recording (future enhancement)
- Thoughts available in payload regardless

## Environment Variables

All existing environment variables remain unchanged:
- `LLM_URL` - LLM backend endpoint (e.g., http://localhost:52003)
- `LLM_MODEL` - Model identifier (e.g., ./vllm/models/qwen3_30b_a3b_4bit)
- `API_KEY` - Authorization token
- `LLM_RETRY_ATTEMPTS` - Number of retry attempts (defaults to 1)
- `LLM_RETRY_DELAY` - Base delay for retries in milliseconds

## Key Design Decisions

1. **No client split**: Single `GenericLlmClient` handles everything
2. **Thoughts as payload field**: Explicitly part of response, not hidden
3. **Hash returns**: Consistent `{ content:, thoughts: }` interface
4. **Simplest selection**: Use most recent (narrative) thoughts in workflow
5. **Optional memory**: Recording doesn't affect core functionality
6. **Backward compatible**: Existing code updated minimally
