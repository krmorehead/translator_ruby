# Base References

This file provides a leaf-node tree of all documented files in the codebase.

## File Tree

```
docs/references/
├── base_references.md                          # This file - documentation index
├── architecture_diagram.md                     # System architecture overview
│
├── app/
│   ├── controllers/
│   │   ├── application_controller.md           # Base API controller
│   │   └── api/v1/
│   │       ├── hello_controller.md             # Hello world endpoint
│   │       └── translation_controller.md       # Translation endpoints
│   │
│   ├── models/
│   │   └── translation_context.md              # Translation context model
│   │
│   └── services/
│       ├── translation_service.md              # Core translation service
│       └── translation_tree_service.md         # Tree traversal for translation
│
├── config/
│   ├── routes.md                               # API routing configuration
│   └── initializers/
│       └── openai.md                           # OpenAI client initialization
│
└── lib/
    ├── server.md                               # Custom server startup script
    └── test_runner.md                          # Custom test runner script
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

### Library
- [Server](lib/server.md) - Custom server startup script
- [TestRunner](lib/test_runner.md) - Custom test runner script

