# File References: vllm Client Implementation

## Existing Files

| File Path | Description | Relevance |
|-----------|-------------|-----------|
| `app/services/generic_llm_client.rb` | Current LLM client (singleton wrapper) | Will become thin delegate to VllmLlmClient |
| `app/prompts/base_prompt.rb` | Abstract base class for all LLM prompts | No changes needed - client handles everything |
| `app/services/dnd_chat_workflow.rb` | DnD chat workflow orchestrator | No changes needed - client handles everything |
| `app/models/memory_kinds.rb` | Registry of memory section types | Will add MODEL_INTERACTIONS constant |
| `app/models/memories/registry.rb` | Memory type registry | Will register ModelInteractionMemory |
| `app/models/memories/base_memory.rb` | Base class for memory types | Parent class for ModelInteractionMemory |
| `app/models/memory_store.rb` | Memory storage with sandbox validation | Has path validation issue to fix |
| `test/integration/llm_dnd_tools_integration_test.rb` | Tool integration tests | Currently failing with 400 errors |
| `test/prompts/base_prompt_test.rb` | Tests for BasePrompt | Currently failing due to think tags |
| `test/prompts/narrative_prompt_test.rb` | Tests for narrative generation | Currently failing due to think tags |
| `test/integration/dnd_workflow_integration_test.rb` | DnD workflow integration tests | Has sandbox path validation error |
| `lib/test_runner.rb` | Custom test runner | Used to run full test suite |
| `docs/references/app/base_references.md` | App documentation index | Will update with new files |
| `docs/references/architecture_diagram.md` | System architecture overview | Will add client architecture documentation |

## New Files Only

| File Path | Description | Created In |
|-----------|-------------|------------|
| `app/services/vllm_llm_client.rb` | vllm-specific LLM client with parameter translation | Step 1.1 |
| `app/services/openai_llm_client.rb` | Preserved OpenAI-compatible client (unused) | Step 1.2 |
| `app/services/guided_json_builder.rb` | Converts JSON Schema to vllm guided_json format | Step 2.1 |
| `app/services/thought_extractor.rb` | Extracts and filters <think> tags from responses | Step 3.3 |
| `app/models/memories/training_data/model_interaction_memory.rb` | Memory type for recording model interactions | Step 3.1 |
| `test/services/vllm_llm_client_test.rb` | Tests for VllmLlmClient | Step 1.1 |
| `test/services/openai_llm_client_test.rb` | Tests for OpenAiLlmClient | Step 1.2 |
| `test/services/guided_json_builder_test.rb` | Tests for GuidedJsonBuilder | Step 2.1 |
| `test/services/thought_extractor_test.rb` | Tests for ThoughtExtractor | Step 3.3 |
| `test/models/memories/training_data/model_interaction_memory_test.rb` | Tests for ModelInteractionMemory | Step 3.1 |
| `docs/references/app/services/vllm_llm_client.md` | Documentation for VllmLlmClient | Step 6.1 |
| `docs/references/app/services/openai_llm_client.md` | Documentation for OpenAiLlmClient | Step 6.1 |
| `docs/references/app/services/guided_json_builder.md` | Documentation for GuidedJsonBuilder | Step 6.1 |
| `docs/references/app/services/thought_extractor.md` | Documentation for ThoughtExtractor | Step 6.1 |
| `docs/references/app/models/memories/training_data/model_interaction_memory.md` | Documentation for ModelInteractionMemory | Step 6.1 |
| `docs/projects/12-14-2025_jinja_prompt_formatting/project_plan.md` | This project plan | Initial setup |
| `docs/projects/12-14-2025_jinja_prompt_formatting/file_references.md` | This file | Initial setup |

## Document Tree

### Before
```
translator_ruby/
├── app/
│   ├── models/
│   │   ├── memory_kinds.rb
│   │   ├── memory_store.rb
│   │   └── memories/
│   │       ├── base_memory.rb
│   │       └── registry.rb
│   ├── prompts/
│   │   └── base_prompt.rb
│   └── services/
│       ├── generic_llm_client.rb
│       └── dnd_chat_workflow.rb
├── test/
│   ├── integration/
│   │   ├── llm_dnd_tools_integration_test.rb
│   │   └── dnd_workflow_integration_test.rb
│   └── prompts/
│       ├── base_prompt_test.rb
│       └── narrative_prompt_test.rb
└── docs/
    └── references/
        ├── architecture_diagram.md
        └── app/
            └── base_references.md
```

### Added
```
translator_ruby/
├── app/
│   ├── models/
│   │   └── memories/
│   │       └── training_data/
│   │           └── model_interaction_memory.rb
│   └── services/
│       ├── vllm_llm_client.rb
│       ├── openai_llm_client.rb
│       ├── guided_json_builder.rb
│       └── thought_extractor.rb
├── test/
│   ├── models/
│   │   └── memories/
│   │       └── training_data/
│   │           └── model_interaction_memory_test.rb
│   └── services/
│       ├── vllm_llm_client_test.rb
│       ├── openai_llm_client_test.rb
│       ├── guided_json_builder_test.rb
│       └── thought_extractor_test.rb
└── docs/
    ├── projects/
    │   └── 12-14-2025_jinja_prompt_formatting/
    │       ├── project_plan.md
    │       └── file_references.md
    └── references/
        └── app/
            ├── models/
            │   └── memories/
            │       └── training_data/
            │           └── model_interaction_memory.md
            └── services/
                ├── vllm_llm_client.md
                ├── openai_llm_client.md
                ├── guided_json_builder.md
                └── thought_extractor.md
```

## Test Failures to Address

### Current Failures (6 total)

**400 Bad Request Errors (3 errors)**
- `LlmDndToolsIntegrationTest#test_LLM_updates_memory_and_summarizes_quests`
- `LlmDndToolsIntegrationTest#test_LLM_can_add_and_list_inventory`
- `LlmDndToolsIntegrationTest#test_LLM_selects_dice_roll_for_advantage_request`
- **Root Cause**: vllm doesn't support `json_schema` response format
- **Fix**: VllmLlmClient translates response_format to guided_json (Milestone 2)

**Think Tag Issues (2 failures)**
- `BasePromptTest#test_execute_returns_freeform_text_when_no_schema`
- `NarrativePromptTest#test_execute_returns_narrative_string`
- **Root Cause**: vllm model returns `<think>...</think>` tags in responses
- **Fix**: VllmLlmClient filters responses with ThoughtExtractor (Milestone 3)

**Sandbox Path Error (1 error)**
- `DndWorkflowIntegrationTest#test_conversation_continuity_across_multiple_messages`
- **Root Cause**: Memory path validation expects absolute path but receives relative
- **Fix**: Fix path construction in MemoryStore (Milestone 4)

## Architecture Changes

### Client Responsibility
The client layer (VllmLlmClient) now handles:
1. **Parameter Translation**: Converts OpenAI `response_format` to vllm `guided_json`
2. **Response Filtering**: Extracts and removes `<think>` tags
3. **Memory Recording**: Records model interactions when memory context available

### No Changes Required
- Prompts (BasePrompt and subclasses) remain completely unchanged
- Workflows (DndChatWorkflow, etc.) remain completely unchanged  
- Controllers remain unchanged
- All existing code continues to use GenericLlmClient which delegates to VllmLlmClient

### Dual Client Architecture
- **VllmLlmClient**: Active client for vllm backend (refactored from GenericLlmClient)
- **OpenAiLlmClient**: Preserved OpenAI-compatible client for future use (currently unused)
- **GenericLlmClient**: Thin delegate to VllmLlmClient for backward compatibility

## Environment Variables

All existing environment variables remain unchanged:
- `LLM_URL` - LLM backend endpoint (e.g., http://localhost:52003)
- `LLM_MODEL` - Model identifier (e.g., qwen30b)
- `API_KEY` - Authorization token
- `LLM_RETRY_ATTEMPTS` - Number of retry attempts for failed requests
- `LLM_RETRY_DELAY` - Base delay for retries in milliseconds
