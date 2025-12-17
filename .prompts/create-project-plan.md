---
description: Create a structured project plan with milestones, steps, and file references
---

# Create Project Plan

Create a comprehensive project plan following these structured guidelines.

## Step 1: Research the Codebase

Follow @research-rules.mdc before beginning:

- Begin by locating `docs/references/base_references.md`
- Review relevant leaf node documentation for existing code
- Consult `docs/references/architecture_diagram.md` for system understanding
- Only open source files when documentation is insufficient

## Step 2: Create Project Directory

Create a new project folder in `docs/projects/` with the naming convention:

```
docs/projects/{MM-DD-YYYY}_{project_name}/
```

Example: `docs/projects/12-07-2025_user_authentication/`

## Step 3: Create file_references.md

Create `file_references.md` in the project directory containing ONLY file references and descriptions:

```markdown
# File References: {Project Name}

## Existing Files

| File Path | Description | Relevance |
|-----------|-------------|-----------|
| `path/to/file.rb` | Brief description | How it relates to project |

## Planned Files

| File Path | Description | Created In |
|-----------|-------------|------------|
| `path/to/new_file.rb` | What this file will do | Step reference |
```

Requirements:
- List ALL existing files that will be read, modified, or referenced
- List ALL new files that will be created
- Include test files in planned files
- Reference the step number where each planned file is created
- Keep descriptions concise (one line)
- Add Document Tree sections with **Before** and **Added** layouts:
  - **Before**: Shows the full relevant existing file structure (all files that exist and relate to this project)
  - **Added**: Shows ONLY the new files/directories being created (do not duplicate existing files)
- Example:
```
### Before

project/
├── lib/
│   └── existing_module.rb
├── app/
│   └── services/
│       └── existing_service.rb
└── test/
    └── lib/
        └── existing_module_test.rb

### Added

project/
├── lib/
│   └── new_module.rb
├── app/
│   └── services/
│       └── new_service.rb
└── test/
    └── lib/
        └── new_module_test.rb
```

## Step 4: Create project_plan.md

Create `project_plan.md` with discrete implementation steps broken into milestones:

```markdown
# Project Plan: {Project Name}

## Overview

Brief description of what this project accomplishes.

## Goals

- Goal 1
- Goal 2

---

## Milestone 1 - {Milestone Title}

Brief description of what this milestone achieves.

### 1.1 - {Step Title}

**Intent**: What this step accomplishes and why.

**Details**:
- Specific requirement 1
- Specific requirement 2
- Specific requirement 3

**Tests**:
- Test case 1
- Test case 2

---

### 1.2 - {Step Title}

**Intent**: What this step accomplishes and why.

**Details**:
- Specific requirement 1
- Specific requirement 2

**Tests**:
- Test case 1
- Test case 2

---

## Milestone 2 - {Milestone Title}

...continue pattern...
```

## Milestone Guidelines

- Each milestone represents a **logical grouping** of related functionality
- Milestones should be **independently demonstrable** when complete
- A milestone typically contains 3-7 steps
- Milestone titles should be action-oriented (e.g., "Build the Translation Service")

## Step Guidelines

- Each step should be **small and focused** (completable in one session)
- Steps must describe **intent**, not implementation code
- Every step MUST include test requirements
- Steps should build incrementally on previous steps
- Steps are numbered as `{milestone}.{step}` (e.g., 1.1, 1.2, 2.1)

### Intent Section

The intent section should answer:
- **What** is being created or modified
- **Why** this is needed
- **How** it fits into the larger milestone

### Details Section

The details section should specify:
- Attributes, properties, or parameters
- Behavioral requirements
- Constraints or validation rules
- Integration points with other components
- NO actual code - describe what, not how

### Tests Section

Every step MUST specify tests to validate the implementation:
- Unit tests for isolated functionality
- Integration tests for component interaction
- Edge cases and error conditions
- Tests are written and run BEFORE moving to next step

## Example

```markdown
## Milestone 1 - Build the Translation Service

Create the foundational translation infrastructure.

### 1.1 - Create TranslationContext Class

**Intent**: Create an isolated data object to represent a single translation request. This provides a clean interface between controllers and services.

**Details**:
- Create as a Plain Old Ruby Object (PORO)
- Support the following attributes:
  - `text` - the content to translate
  - `target_lang` - target language code
  - `source_lang` - source language code (default: "en")
  - `context` - contextual hint for translation
  - `model_type` - LLM model override
  - `formality` - formality level (formal, informal, default)
- Use keyword arguments with sensible defaults
- Keep the class focused and single-purpose

**Tests**:
- Test initialization with all parameters
- Test initialization with only required parameters
- Test default values are applied correctly
- Test attribute accessors work properly

---

### 1.2 - Add Validation to TranslationContext

**Intent**: Ensure translation contexts contain valid data before processing.

**Details**:
- Validate text is present and non-empty
- Validate target_lang is a valid ISO 639 code
- Validate formality is one of allowed values
- Raise ArgumentError with descriptive messages

**Tests**:
- Test validation passes with valid data
- Test validation fails with empty text
- Test validation fails with invalid language code
- Test error messages are descriptive
```

## Execution Rules

When implementing a project plan:

1. **Complete one step at a time** - Do not jump ahead
2. **Write tests first** - Follow TDD principles
3. **Run tests after each step** - Verify before proceeding
4. **Update file_references.md** - Mark files as created
5. **Commit after each milestone** - Keep atomic, reviewable changes

## Review Checklist

Before finalizing a project plan, verify:

- [ ] file_references.md lists all existing and planned files
- [ ] Every step has an Intent section
- [ ] Every step has a Details section with specific requirements
- [ ] Every step has a Tests section
- [ ] Steps are small enough to complete in one session
- [ ] Milestones represent logical, demonstrable progress
- [ ] No implementation code appears in the plan
- [ ] Test requirements cover happy path and edge cases


