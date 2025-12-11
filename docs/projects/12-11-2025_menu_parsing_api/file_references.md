# File References: HTML Menu Parsing API

## Existing Files

| File Path | Description | Relevance |
|-----------|-------------|-----------|
| `app/controllers/application_controller.rb` | Base API controller | Parent class for new controller |
| `app/controllers/api/v1/translation_controller.rb` | Translation API controller | Reference pattern for v1 controllers |
| `app/services/translation_service.rb` | Core translation service | Pattern for service architecture |
| `app/models/translation_context.rb` | Translation context PORO | Pattern for context objects |
| `app/prompts/base_prompt.rb` | Abstract prompt base class | Parent class for new prompt |
| `app/prompts/translation_prompt.rb` | Translation prompt implementation | Reference pattern for prompts |
| `config/routes.rb` | API routing configuration | Add new menu parsing routes |
| `test/controllers/api/v1/translation_controller_test.rb` | Translation controller tests | Pattern for controller testing |
| `docs/references/base_references.md` | Documentation index | Add new documentation references |
| `docs/references/architecture_diagram.md` | System architecture overview | Update with new menu parsing flow |
| `docs/projects/12-11-2025_menu_parsing_api/weekly_school_menu.html` | Realistic weekly menu HTML | Source fixture for parsing tests |
| `docs/projects/12-11-2025_menu_parsing_api/weekly_school_menu_html_focused.html` | Structured/semantic weekly menu HTML | Source fixture for parsing tests |
| `docs/projects/12-11-2025_menu_parsing_api/ducling-html+bedrock-claude.json` | Structured menu JSON example | Expected-shape reference for output |

## Planned Files

| File Path | Description | Created In |
|-----------|-------------|------------|
| `app/controllers/api/v1/menu_parser_controller.rb` | Menu parsing API controller | Step 1.1 |
| `app/models/menu_preprocessing_config.rb` | Configuration for HTML preprocessing options | Step 1.3 |
| `app/services/menu_parsing_service.rb` | Core menu parsing orchestration service | Step 3.1 |
| `app/services/html_preprocessing_service.rb` | HTML cleaning and structuring service | Step 3.2 |
| `app/prompts/menu_extraction_prompt.rb` | LLM prompt for menu extraction | Step 2.1 |
| `app/serializers/menu_response_serializer.rb` | (Removed; returning LLM output directly) | n/a |
| `test/controllers/api/v1/menu_parser_controller_test.rb` | Controller tests | Step 1.1 |
| `test/models/menu_preprocessing_config_test.rb` | Preprocessing config tests | Step 1.3 |
| `test/services/menu_parsing_service_test.rb` | Service tests | Step 3.1 |
| `test/services/html_preprocessing_service_test.rb` | Preprocessing service tests | Step 3.2 |
| `test/prompts/menu_extraction_prompt_test.rb` | Prompt tests | Step 2.1 |
| `test/serializers/menu_response_serializer_test.rb` | (Removed) | n/a |
| `test/integration/menu_parsing_flow_test.rb` | End-to-end integration tests | Step 4.1 |
| `docs/references/app/controllers/api/v1/menu_parser_controller.md` | Controller documentation | Step 4.2 |
| `docs/references/app/models/menu_parsing_context.md` | Context documentation | Step 4.2 |
| `docs/references/app/models/menu_preprocessing_config.md` | Config documentation | Step 4.2 |
| `docs/references/app/services/menu_parsing_service.md` | Service documentation | Step 4.2 |
| `docs/references/app/services/html_preprocessing_service.md` | Preprocessing documentation | Step 4.2 |
| `docs/references/app/prompts/menu_extraction_prompt.md` | Prompt documentation | Step 4.2 |
| `docs/references/app/serializers/menu_response_serializer.md` | Serializer documentation | Step 4.2 |
| `test/fixtures/sample_menus/weekly_school_menu.html` | Fixture copy of real menu HTML | Step 1.5 |
| `test/fixtures/sample_menus/weekly_school_menu_html_focused.html` | Fixture copy of structured menu HTML | Step 1.5 |
| `test/fixtures/sample_menus/ducling-html+bedrock-claude.json` | Fixture expected output reference | Step 1.5 |

## Document Tree

### Before

```
app/
├── controllers/
│   ├── api/
│   │   └── v1/
│   │       ├── hello_controller.rb
│   │       └── translation_controller.rb
│   ├── application_controller.rb
│   └── dnd_chat_controller.rb
├── models/
│   ├── translation_context.rb
│   ├── conversation.rb
│   └── message.rb
├── prompts/
│   ├── base_prompt.rb
│   ├── translation_prompt.rb
│   ├── action_detection_prompt.rb
│   └── narrative_prompt.rb
├── services/
│   ├── translation_service.rb
│   ├── translation_tree_service.rb
│   ├── dnd_chat_workflow.rb
│   └── tool_call_service.rb
└── serializers/
    └── chat_response_serializer.rb

config/
└── routes.rb

test/
├── controllers/
│   └── api/
│       └── v1/
│           ├── hello_controller_test.rb
│           └── translation_controller_test.rb
├── models/
│   └── translation_context_test.rb
├── services/
│   ├── translation_service_test.rb
│   └── translation_tree_service_test.rb
├── prompts/
│   └── translation_prompt_test.rb
└── integration/
    └── translation_flow_test.rb

docs/references/
├── base_references.md
├── architecture_diagram.md
└── app/
    ├── controllers/
    │   └── api/v1/
    │       ├── hello_controller.md
    │       └── translation_controller.md
    ├── models/
    │   └── translation_context.md
    ├── services/
    │   ├── translation_service.md
    │   └── translation_tree_service.md
    └── prompts/
        └── translation_prompt.md

docs/projects/12-11-2025_menu_parsing_api/
├── README.md
├── project_plan.md
├── file_references.md
├── weekly_school_menu.html
├── weekly_school_menu_html_focused.html
└── ducling-html+bedrock-claude.json
```

### Added

```
app/
├── controllers/
│   ├── api/
│   │   └── v1/
│   │       ├── hello_controller.rb
│   │       ├── translation_controller.rb
│   │       └── menu_parser_controller.rb          # NEW
│   ├── application_controller.rb
│   └── dnd_chat_controller.rb
├── models/
│   ├── translation_context.rb
│   ├── conversation.rb
│   ├── message.rb
│   └── menu_preprocessing_config.rb               # NEW
├── prompts/
│   ├── base_prompt.rb
│   ├── translation_prompt.rb
│   ├── action_detection_prompt.rb
│   ├── narrative_prompt.rb
│   └── menu_extraction_prompt.rb                  # NEW
├── services/
│   ├── translation_service.rb
│   ├── translation_tree_service.rb
│   ├── dnd_chat_workflow.rb
│   ├── tool_call_service.rb
│   ├── menu_parsing_service.rb                    # NEW
│   └── html_preprocessing_service.rb              # NEW
└── serializers/
    └── chat_response_serializer.rb

config/
└── routes.rb                                      # MODIFIED

test/
├── controllers/
│   └── api/
│       └── v1/
│           ├── hello_controller_test.rb
│           ├── translation_controller_test.rb
│           └── menu_parser_controller_test.rb     # NEW
├── models/
│   ├── translation_context_test.rb
│   └── menu_preprocessing_config_test.rb          # NEW
├── services/
│   ├── translation_service_test.rb
│   ├── translation_tree_service_test.rb
│   ├── menu_parsing_service_test.rb               # NEW
│   └── html_preprocessing_service_test.rb         # NEW
├── prompts/
│   ├── translation_prompt_test.rb
│   └── menu_extraction_prompt_test.rb             # NEW
└── integration/
    ├── translation_flow_test.rb
    └── menu_parsing_flow_test.rb                  # NEW

test/fixtures/sample_menus/                        # NEW
├── weekly_school_menu.html                        # NEW (copied from docs/projects)
├── weekly_school_menu_html_focused.html           # NEW (copied from docs/projects)
└── ducling-html+bedrock-claude.json               # NEW (expected output reference)

docs/references/
├── base_references.md                             # MODIFIED
├── architecture_diagram.md                        # MODIFIED
└── app/
    ├── controllers/
    │   └── api/v1/
    │       ├── hello_controller.md
    │       ├── translation_controller.md
    │       └── menu_parser_controller.md          # NEW
    ├── models/
    │   ├── translation_context.md
    │   └── menu_preprocessing_config.md           # NEW
    ├── services/
    │   ├── translation_service.md
    │   ├── translation_tree_service.md
    │   ├── menu_parsing_service.md                # NEW
    │   └── html_preprocessing_service.md          # NEW
    ├── prompts/
    │   ├── translation_prompt.md
    │   └── menu_extraction_prompt.md              # NEW

docs/projects/12-11-2025_menu_parsing_api/
├── README.md
├── project_plan.md
├── file_references.md
├── weekly_school_menu.html
├── weekly_school_menu_html_focused.html
└── ducling-html+bedrock-claude.json
```

