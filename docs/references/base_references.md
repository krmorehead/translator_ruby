# Base References

This file provides a leaf-node tree of all documented files in the codebase.

## File Tree

```
docs/references/
├── base_references.md                          # This file - documentation index
├── architecture_diagram.md                     # System architecture overview
│
├── app/
│   ├── base_references.md
│   ├── controllers/
│   │   ├── base_references.md
│   │   ├── application_controller.md           # Base API controller
│   │   ├── dnd_chat_controller.md              # DnD chat API
│   │   └── api/v1/
│   │       ├── hello_controller.md             # Hello world endpoint
│   │       └── translation_controller.md       # Translation endpoints
│   │
│   ├── models/
│   │   ├── base_references.md
│   │   ├── conversation.md                     # Chat conversation aggregate
│   │   ├── message.md                          # Chat message value object
│   │   ├── translation_context.md              # Translation context model
│   │   ├── inventory_item.md
│   │   ├── inventory_store.md
│   │   ├── memory_kinds.md
│   │   └── memory_store.md
│   │
│   ├── services/
│   │   ├── base_references.md
│   │   ├── dnd_chat_workflow.md                # Chat LLM parameters and prompt
│   │   ├── tool_call_service.md                # Tool registry/dispatch
│   │   ├── translation_service.md              # Core translation service
│   │   └── translation_tree_service.md         # Tree traversal for translation
│   │
│   └── tools/
│       ├── base_references.md
│       ├── base_tool.md
│       ├── bash_tool.md
│       ├── dice_roll_tool.md
│       ├── inventory_tool.md
│       ├── memory_tool.md
│       ├── memory_summarize_tool.md
│       ├── read_file_tool.md
│       ├── skill_check_tool.md
│       └── write_file_tool.md
│
├── config/
│   ├── routes.md                               # API routing configuration
│   └── initializers/
│       └── openai.md                           # OpenAI client initialization
│
├── frontend/
│   ├── base_references.md
│   ├── README.md
│   ├── vite.config.md
│   └── src/
│       ├── base_references.md
│       ├── App.md
│       ├── api/
│       │   ├── base_references.md
│       │   └── dndChatApi.md
│       ├── components/
│       │   ├── base_references.md
│       │   ├── AgentInspector.md
│       │   ├── ChatLog.md
│       │   ├── ChatPage.md
│       │   ├── LoadingIndicator.md
│       │   ├── Message.md
│       │   └── MessageInput.md
│       ├── pages/
│       │   ├── base_references.md
│       │   └── InspectorPage.md
│       └── store/
│           ├── base_references.md
│           └── chatStore.md
│
├── lib/
│   ├── server.md                               # Custom server startup script
│   └── test_runner.md                          # Custom test runner script
│
└── test/
    ├── base_references.md                      # Test documentation index
    └── test_helper.md                          # Test configuration
```

## Quick Navigation

### Controllers
- [ApplicationController](app/controllers/application_controller.md) - Base controller for API-only mode
- [HelloController](app/controllers/api/v1/hello_controller.md) - Health check and hello world endpoint
- [TranslationController](app/controllers/api/v1/translation_controller.md) - Translation API endpoints

### Models
- [TranslationContext](app/models/translation_context.md) - Data object for translation parameters

### Services
- [TranslationService](app/services/translation_service.md) - Core LLM-powered translation logic
- [TranslationTreeService](app/services/translation_tree_service.md) - Tree traversal for document translation

### Configuration
- [Routes](config/routes.md) - API route definitions
- [OpenAI Initializer](config/initializers/openai.md) - OpenAI gem initialization

### Frontend
- [App](frontend/src/App.md) - Root wiring for chat/inspector views
- [API client](frontend/src/api/dndChatApi.md) - Fetch helpers for chat backend
- [ChatPage](frontend/src/components/ChatPage.md) - Chat layout shell
- [ChatLog](frontend/src/components/ChatLog.md) - Conversation list
- [Message](frontend/src/components/Message.md) - Chat bubble
- [MessageInput](frontend/src/components/MessageInput.md) - Input + send
- [LoadingIndicator](frontend/src/components/LoadingIndicator.md) - Loading badge
- [AgentInspector](frontend/src/components/AgentInspector.md) - Inspector view
- [InspectorPage](frontend/src/pages/InspectorPage.md) - Standalone inspector page
- [Store](frontend/src/store/chatStore.md) - Zustand chat state/actions
- [Vite config](frontend/vite.config.md) - Vite build/proxy settings
- [Frontend README](frontend/README.md) - Frontend usage notes

### Library
- [Server](lib/server.md) - Custom server startup script
- [TestRunner](lib/test_runner.md) - Custom test runner script

### Test Configuration
- [TestHelper](test/test_helper.md) - Test parallelization and shared result patterns

