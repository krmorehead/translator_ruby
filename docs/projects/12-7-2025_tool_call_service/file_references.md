# File References: Tool Calling Service

## Document Trees

**Before**
```
app/
└── services/
    └── translation_service.rb
test/
└── test_helper.rb
docs/
└── projects/
    └── 12-7-2025_tool_call_service/
        ├── file_references.md
        └── project_plan.md
```

**After**
```
app/
├── services/
│   ├── tool_call_service.rb
│   └── translation_service.rb
└── tools/
    ├── base_tool.rb
    ├── bash_tool.rb
    ├── read_file_tool.rb
    └── write_file_tool.rb
test/
├── test_helper.rb
├── tool_test/
│   └── ...
├── services/
│   └── tool_call_service_test.rb
└── tools/
    ├── base_tool_test.rb
    ├── bash_tool_test.rb
    ├── read_file_tool_test.rb
    └── write_file_tool_test.rb
docs/
└── projects/
    └── 12-7-2025_tool_call_service/
        ├── file_references.md
        └── project_plan.md
```

## Existing Files

| File Path | Description | Relevance |
|-----------|-------------|-----------|
| `app/services/translation_service.rb` | Core LLM service using OpenAI client | Pattern for LLM client usage and structured output |
| `test/test_helper.rb` | Test configuration with parallel execution | Test setup patterns and sandbox cleanup approach |

## Planned Files

| File Path | Description | Created In |
|-----------|-------------|------------|
| `app/tools/base_tool.rb` | Abstract base class with common tool patterns | Step 1.1 |
| `test/tools/base_tool_test.rb` | Tests for base tool schema and interface | Step 1.1 |
| `app/services/tool_call_service.rb` | Orchestrates tool registry and execution | Step 1.2 |
| `test/services/tool_call_service_test.rb` | Tests for tool dispatch and execution | Step 1.2 |
| `app/tools/read_file_tool.rb` | Read file tool with sandbox validation | Step 2.1 |
| `test/tools/read_file_tool_test.rb` | Tests for file reading with sandbox | Step 2.1 |
| `app/tools/write_file_tool.rb` | Write file tool with directory creation | Step 3.1 |
| `test/tools/write_file_tool_test.rb` | Tests for file writing with sandbox | Step 3.1 |
| `app/tools/bash_tool.rb` | Bash command execution tool | Step 4.1 |
| `test/tools/bash_tool_test.rb` | Tests for bash execution and LLM integration | Step 4.1 |
| `test/tool_test/` | Sandboxed directory for file operation tests | Step 2.1 |

