# Project Plan: DnD Chat Tools

## Overview
Create DnD-oriented tools for an interactive chat experience: dice rolling, skill checks, inventory management, and narrative memory with summarization. Tools follow the existing `BaseTool`/`ToolCallService` architecture and use file-based storage for inventory and memory.

## Goals
- Provide LLM-callable tools for dice rolls and skill checks
- Manage inventory via JSON-backed store with structured models
- Persist and summarize narrative memory across sessions
- Keep tools sandbox-safe and covered by tests in every step

---

## Milestone 1 - Foundation & References
Establish project scaffolding and ensure tool registration patterns are clear.

### 1.1 - Document file references
**Intent**: Capture all relevant existing files and planned additions for DnD tools.

**Details**:
- Create project folder `docs/projects/12-09-2025_dnd_chat_tools/`
- Add `file_references.md` listing existing files (tool framework) and all planned files (tools, models, tests, data paths)

**Tests**:
- Documentation review only (no automated tests)

### 1.2 - Baseline tool registry usage
**Intent**: Confirm we leverage existing `BaseTool` and `ToolCallService` without modifying them.

**Details**:
- Reference `app/tools/base_tool.rb` and `app/services/tool_call_service.rb`
- Define how new tools will register themselves

**Tests**:
- Documentation review only (no automated tests)

---

## Milestone 2 - Dice & Skill Tools
Provide core mechanics for dice and skill checks.

### 2.1 - DiceRollTool
**Intent**: Roll standard dice (d4/d6/d8/d10/d12/d20) with modifiers and advantage/disadvantage.

**Details**:
- Schema: `dice` (string like `d20`, `2d6`), `modifier` (integer, default 0), `mode` (normal|advantage|disadvantage)
- Validate dice format and sides > 1; cap roll count to a safe limit
- Return individual rolls, total, applied modifier, and mode

**Tests**:
- Roll single die, multiple dice, and with modifier
- Advantage/disadvantage returns highest/lowest of two d20 rolls
- Reject invalid dice strings and excessive counts

### 2.2 - SkillCheckTool
**Intent**: Perform a d20 skill check using DiceRollTool and supplied modifiers.

**Details**:
- Schema: `skill` (string), `ability_modifier` (int), `proficiency_bonus` (int, optional), `mode` (normal/adv/disadv), `dc` (int, optional)
- Compute total = d20 roll + modifiers; include success boolean when dc provided
- Reuse DiceRollTool logic internally (no duplicated roll code)

**Tests**:
- Skill check with/without proficiency, with dc pass/fail
- Advantage/disadvantage path works
- Delegation to dice tool is invoked; handles invalid inputs

---

## Milestone 3 - Inventory
Persist inventory as JSON with structured models.

### 3.1 - Inventory models & storage
**Intent**: Create `InventoryItem` and `InventoryStore` for structured, file-backed inventory.

**Details**:
- `InventoryItem` fields: name, weight, description, property_type, quantity
- `InventoryStore`: load/save JSON to sandbox file; serialize/deserialize items; validate non-negative quantity
- Provide helpers to find/update/add/remove items

**Tests**:
- Serialize/deserialize round-trip preserves fields
- Add/update/remove items adjusts quantities correctly
- Reject negative quantities; handles missing file by initializing empty store

### 3.2 - InventoryTool
**Intent**: LLM-callable tool to read/write inventory via InventoryStore.

**Details**:
- Schema operations: add_item, remove_item, update_quantity, list_inventory, get_item
- Uses sandbox path for inventory JSON file
- Returns structured results (updated item or list)

**Tests**:
- Add item creates file and persists
- Remove and update quantity adjust counts
- List returns all items; get returns specific item
- Path escaping is rejected (sandbox safety)

---

## Milestone 4 - Memory
Manage narrative memory with sections and summarization support.

### 4.1 - Memory models & storage
**Intent**: Define `MemoryStore` with named sections and file-backed persistence.

**Details**:
- Sections: recent_conversation, quests, main_quest, current_goal, current_scene, people, misc
- JSON format with timestamps for entries where relevant
- Load/save with schema validation; merge updates by section

**Tests**:
- Serialize/deserialize preserves sections
- Update specific section without losing others
- Handles empty/missing file by initializing defaults

### 4.2 - MemoryTool
**Intent**: LLM-callable tool to read/update memory sections.

**Details**:
- Schema operations: get_section, update_section (append/replace), list_sections
- Sandbox path for memory JSON file
- Returns structured results with section content

**Tests**:
- Update and fetch sections correctly
- Append vs replace behaviors
- Sandbox path validation

### 4.3 - MemorySummarizeTool
**Intent**: Summarize memory and extract key info (quests/goals/people) for context compression.

**Details**:
- Inputs: section names to summarize, optional max_tokens
- Produces summary plus key bullets for quests/goals/people
- Designed to be LLM-facing; may stub summarization with deterministic logic for tests

**Tests**:
- Summarize selected sections returns combined summary
- Extracts quests/goals/people keys from provided content
- Handles empty sections gracefully

---

## Milestone 5 - Integration & LLM Tooling
Ensure tools are registered and callable end-to-end.

### 5.1 - Tool registration
**Intent**: Register all new tools with ToolCallService and expose schemas for LLM.

**Details**:
- Register DiceRollTool, SkillCheckTool, InventoryTool, MemoryTool, MemorySummarizeTool
- Provide helper to return available tool list for chat usage

**Tests**:
- available_tools includes all new tools
- execute dispatches correctly by name

### 5.2 - LLM integration tests
**Intent**: Verify the LLM selects and uses tools correctly for representative prompts.

**Details**:
- Scenarios: roll with advantage; skill check vs DC; add/list inventory; update/list memory; summarize quests
- Use sandbox files for inventory/memory

**Tests**:
- For each scenario, assert LLM returns the correct tool_call and arguments
- Execute tool_call via ToolCallService and verify outputs
- Ensure no sandbox escape in arguments
