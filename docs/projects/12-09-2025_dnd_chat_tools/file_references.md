# File References: DnD Chat Tools

## Document Trees

**Before**
```
app/
├── services/
│   └── tool_call_service.rb
└── tools/
    └── base_tool.rb
test/
├── test_helper.rb
└── tool_test/
    └── ...
docs/
└── projects/
    └── 12-09-2025_dnd_chat_tools/
        ├── file_references.md
        └── project_plan.md
```

**After**
```
app/
├── models/
│   ├── inventory_item.rb
│   ├── inventory_store.rb
│   └── memory_store.rb
├── services/
│   └── tool_call_service.rb
└── tools/
    ├── base_tool.rb
    ├── dice_roll_tool.rb
    ├── inventory_tool.rb
    ├── memory_summarize_tool.rb
    ├── memory_tool.rb
    └── skill_check_tool.rb
test/
├── test_helper.rb
├── tool_test/
│   └── ...
├── models/
│   ├── inventory_store_test.rb
│   └── memory_store_test.rb
└── tools/
    ├── dice_roll_tool_test.rb
    ├── inventory_tool_test.rb
    ├── memory_summarize_tool_test.rb
    ├── memory_tool_test.rb
    └── skill_check_tool_test.rb
docs/
└── projects/
    └── 12-09-2025_dnd_chat_tools/
        ├── file_references.md
        └── project_plan.md
```

## Existing Files

| File Path | Description | Relevance |
|-----------|-------------|-----------|
| `app/tools/base_tool.rb` | Abstract base for tool schemas/exec | Reuse for new DnD tools |
| `app/services/tool_call_service.rb` | Tool registry/dispatcher | Register new tools |
| `test/test_helper.rb` | Test setup & parallelization | Testing patterns |
| `test/tool_test/` | Sandbox directory | Safe file I/O for tools |

## Planned Files

| File Path | Description | Created In |
|-----------|-------------|------------|
| `app/tools/dice_roll_tool.rb` | Dice rolling with adv/disadv & modifiers | Step 2.1 |
| `test/tools/dice_roll_tool_test.rb` | Tests for dice rolling tool | Step 2.1 |
| `app/tools/skill_check_tool.rb` | Skill checks using d20 + modifiers | Step 2.2 |
| `test/tools/skill_check_tool_test.rb` | Tests for skill check tool | Step 2.2 |
| `app/models/inventory_item.rb` | Inventory item model (name, weight, etc.) | Step 3.1 |
| `app/models/inventory_store.rb` | File-backed inventory storage | Step 3.1 |
| `test/models/inventory_store_test.rb` | Tests for inventory store/model | Step 3.1 |
| `app/tools/inventory_tool.rb` | LLM tool for inventory operations | Step 3.2 |
| `test/tools/inventory_tool_test.rb` | Tests for inventory tool | Step 3.2 |
| `app/models/memory_store.rb` | File-backed memory sections | Step 4.1 |
| `test/models/memory_store_test.rb` | Tests for memory store | Step 4.1 |
| `app/tools/memory_tool.rb` | LLM tool for memory read/update | Step 4.2 |
| `test/tools/memory_tool_test.rb` | Tests for memory tool | Step 4.2 |
| `app/tools/memory_summarize_tool.rb` | Summarize/extract quests/goals/people | Step 4.3 |
| `test/tools/memory_summarize_tool_test.rb` | Tests for summarization tool | Step 4.3 |
| `docs/projects/12-09-2025_dnd_chat_tools/project_plan.md` | Project plan document | Step 1.1 |
