# File References: DnD Chat Workflow Refactor

## Existing Files

| File Path | Description | Relevance |
|-----------|-------------|-----------|
| `app/controllers/dnd_chat_controller.rb` | Current controller with embedded logic | Primary refactor target |
| `app/services/dnd_chat_workflow.rb` | Builds LLM chat parameters | Will extend BaseWorkflow |
| `app/services/tool_call_service.rb` | Tool registry and execution | Used by workflows |
| `app/models/conversation.rb` | Chat conversation aggregate | Used for message storage |
| `app/models/message.rb` | Chat message value object | Used for message creation |
| `app/models/memory_store.rb` | File-backed memory store | Used for action memory |
| `app/models/memory_kinds.rb` | Memory section name constants | Will add ACTIONS section |
| `app/models/memories/registry.rb` | Memory type registry | Will register ActionsMemory |
| `app/models/memories/base_memory.rb` | Base class for memory types | Parent for ActionsMemory |
| `app/tools/base_tool.rb` | Base class for tools | Pattern reference |
| `config/initializers/openai.rb` | OpenAI client initialization | Pattern for prompt clients |
| `test/controllers/dnd_chat_controller_test.rb` | Controller tests | Will need updates |
| `test/services/dnd_chat_workflow_test.rb` | Workflow tests | Will need updates |

## Planned Files

| File Path | Description | Created In |
|-----------|-------------|------------|
| `app/prompts/base_prompt.rb` | Abstract base class for LLM prompts | Step 1.1 |
| `app/prompts/action_detection_prompt.rb` | Detects actions from user input | Step 1.2 |
| `app/prompts/narrative_prompt.rb` | Generates DM-voice narrative | Step 1.3 |
| `app/prompts/outcome_prompt.rb` | Determines action outcomes | Step 1.4 |
| `app/services/base_workflow.rb` | Abstract base class for workflows | Step 2.1 |
| `app/models/workflow_state.rb` | Immutable state object for workflows | Step 2.2 |
| `app/models/action_record.rb` | Value object for detected actions | Step 2.3 |
| `app/services/workflow_orchestrator.rb` | Generic workflow orchestrator | Step 2.4 |
| `app/models/memories/actions_memory.rb` | Memory type for tracking actions | Step 3.1 |
| `app/serializers/chat_response_serializer.rb` | Serializes workflow result to API response | Step 4.1 |
| `test/prompts/base_prompt_test.rb` | Tests for base prompt | Step 1.1 |
| `test/prompts/action_detection_prompt_test.rb` | Tests for action detection | Step 1.2 |
| `test/prompts/narrative_prompt_test.rb` | Tests for narrative prompt | Step 1.3 |
| `test/prompts/outcome_prompt_test.rb` | Tests for outcome prompt | Step 1.4 |
| `test/services/base_workflow_test.rb` | Tests for base workflow | Step 2.1 |
| `test/models/workflow_state_test.rb` | Tests for workflow state | Step 2.2 |
| `test/models/action_record_test.rb` | Tests for action record | Step 2.3 |
| `test/services/workflow_orchestrator_test.rb` | Tests for orchestrator | Step 2.4 |
| `test/models/actions_memory_test.rb` | Tests for actions memory | Step 3.1 |
| `test/serializers/chat_response_serializer_test.rb` | Tests for serializer | Step 4.1 |
| `test/integration/dnd_workflow_integration_test.rb` | End-to-end integration tests | Step 5.1 |

## Document Tree

### Before

```
app/
├── controllers/
│   └── dnd_chat_controller.rb
├── models/
│   ├── conversation.rb
│   ├── memory_kinds.rb
│   ├── memory_store.rb
│   ├── message.rb
│   └── memories/
│       ├── base_memory.rb
│       ├── registry.rb
│       └── ...existing memories...
├── services/
│   ├── dnd_chat_workflow.rb
│   └── tool_call_service.rb
└── tools/
    └── ...existing tools...

test/
├── controllers/
│   └── dnd_chat_controller_test.rb
└── services/
    ├── dnd_chat_workflow_test.rb
    └── tool_call_service_test.rb
```

### After

```
app/
├── controllers/
│   └── dnd_chat_controller.rb          # MODIFIED: Slim delegation only
├── models/
│   ├── action_record.rb                # NEW
│   ├── conversation.rb
│   ├── memory_kinds.rb                 # MODIFIED: Add ACTIONS
│   ├── memory_store.rb
│   ├── message.rb
│   ├── workflow_state.rb               # NEW
│   └── memories/
│       ├── actions_memory.rb           # NEW
│       ├── base_memory.rb
│       ├── registry.rb                 # MODIFIED
│       └── ...existing memories...
├── prompts/                            # NEW directory
│   ├── base_prompt.rb
│   ├── action_detection_prompt.rb
│   ├── outcome_prompt.rb
│   └── narrative_prompt.rb
├── serializers/                        # NEW directory
│   └── chat_response_serializer.rb
├── services/
│   ├── base_workflow.rb                # NEW
│   ├── dnd_chat_workflow.rb            # MODIFIED: Extends BaseWorkflow
│   ├── tool_call_service.rb
│   └── workflow_orchestrator.rb        # NEW
└── tools/
    └── ...existing tools...

test/
├── controllers/
│   └── dnd_chat_controller_test.rb     # MODIFIED
├── integration/                        # NEW directory
│   └── dnd_workflow_integration_test.rb
├── models/
│   ├── action_record_test.rb           # NEW
│   ├── actions_memory_test.rb          # NEW
│   └── workflow_state_test.rb          # NEW
├── prompts/                            # NEW directory
│   ├── action_detection_prompt_test.rb
│   ├── base_prompt_test.rb
│   ├── outcome_prompt_test.rb
│   └── narrative_prompt_test.rb
├── serializers/                        # NEW directory
│   └── chat_response_serializer_test.rb
└── services/
    ├── base_workflow_test.rb           # NEW
    ├── dnd_chat_workflow_test.rb       # MODIFIED
    ├── tool_call_service_test.rb
    └── workflow_orchestrator_test.rb   # NEW
```

## Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `LLM_MODEL` | Default model for prompts | Required |
| `LLM_URL` | LLM backend endpoint | Required |
| `API_KEY` | Authorization token | Required |
| `ACTION_DETECTION_MODEL` | Model for action detection prompt | Falls back to LLM_MODEL |
| `CONSEQUENCE_MODEL` | Model for consequence prompt | Falls back to LLM_MODEL |
| `NARRATIVE_MODEL` | Model for narrative generation | Falls back to LLM_MODEL |
