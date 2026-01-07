---
description: Structured project planning with milestones and incremental steps
globs: docs/projects/**/*.md
alwaysApply: false
---

# Project Planning Structure

**Tags**: [planning, design]  
**Applies To**: All new feature development

## Overview

Structured project plans with milestones, discrete steps, file references, and test requirements. Plans guide incremental implementation with clear success criteria.

## Project Structure Tree

```
Project Planning Structure
│
├── Project Directory
│   └── docs/projects/{YYYY-MM-DD}_{project_name}/
│       ├── file_references.md (all files: existing + planned)
│       ├── project_plan.md (milestones + steps)
│       └── implementation_notes.md (optional)


├── file_references.md Structure
│   ├── Existing Files Table (path | description | relevance)
│   ├── Planned Files Table (path | description | created_in_step)
│   └── Document Tree (Before + Added sections)
│
└── project_plan.md Structure
    ├── Overview (what + why)
    ├── Goals (measurable outcomes)
    ├── Milestones (3-7 steps each)
    │   └── Steps (numbered: milestone.step)
    │       ├── Intent (what + why + how it fits)
    │       ├── Details (requirements, no code)
    │       └── Tests (unit + integration + edge cases)
    │
    └── Execution Order (one step at a time)

Milestone Flow:
User Request → Research → Create Directory → file_references.md → project_plan.md → Execute Step-by-Step
```

---

## Rules

### [PLAN][!RESEARCH-FIRST]

**Rule**: Research codebase before planning. Use documentation first, source code only when docs insufficient.

**Good Example:**

```markdown
# Research Checklist:
1. ✅ Read docs/references/base_references.md
2. ✅ Review relevant leaf node docs
3. ✅ Check docs/references/architecture_diagram.md
4. ✅ Scan existing similar features
5. Only then: open source files if needed
```

**Why**: Documentation provides high-level understanding faster than reading source code.

---

### [PLAN][!PROJECT-DIRECTORY-NAMING]

**Rule**: Create project directory with date and descriptive name: `docs/projects/{YYYY-MM-DD}_{project_name}/`

**Good Example:**

```
docs/projects/2026-01-07_user_authentication/
docs/projects/2026-01-07_feature_implementation/
docs/projects/2026-01-08_api_refactor/
```

**Why**: Date prefix ensures chronological sorting. Descriptive name makes purpose clear.

---

### [PLAN][!FILE-REFERENCES-COMPLETE]

**Rule**: `file_references.md` lists ALL existing and planned files with Before/Added tree sections.

**Good Example:**

```markdown
# File References: Feature Name

## Existing Files

| File Path | Description | Relevance |
|-----------|-------------|-----------|
| `lib/existing_module.rb` | Existing module | Will be extended with new functionality |
| `app/models/existing_model.rb` | Existing model | Will be updated with new attributes |

## Planned Files

| File Path | Description | Created In |
|-----------|-------------|------------|
| `lib/new_module.rb` | New module functionality | Step 1.1 |
| `app/services/new_service.rb` | Service orchestration | Step 1.2 |
| `spec/lib/new_module_spec.rb` | Module tests | Step 1.1 |

## Document Tree

### Before

project/
├── lib/
│   └── existing_module.rb
├── app/
│   └── models/
│       └── existing_model.rb
└── spec/
    └── lib/
        └── existing_module_spec.rb

### Added

project/
├── lib/
│   └── new_module.rb
├── app/
│   └── services/
│       └── new_service.rb
└── spec/
    └── lib/
        └── new_module_spec.rb
```

**Why**: Complete file tracking prevents surprises. Tree visualization shows structure changes.

---

### [PLAN][!MILESTONES-LOGICAL-GROUPS]

**Rule**: Milestones are logical groupings (3-7 steps) that deliver independently demonstrable functionality.

**Good Example:**

```markdown
## Milestone 1 - Build Core Service (4 steps)

Create core service infrastructure with domain objects and validation.

### 1.1 - Create Domain Context Class
### 1.2 - Add Validation to Context
### 1.3 - Create Service Orchestrator
### 1.4 - Integrate with External Dependency

## Milestone 2 - Add API Integration (3 steps)

Connect service to HTTP endpoints with serializers.

### 2.1 - Create Serializer Class
### 2.2 - Update Controller
### 2.3 - Add Documentation
```

**Why**: Milestones provide checkpoints. Each milestone is testable and demonstrable.

---

### [PLAN][!STEPS-SMALL-AND-FOCUSED]

**Rule**: Each step is small (one session), has Intent/Details/Tests, builds incrementally.

**Bad Example:**

```markdown
### 1.1 - Build Complete System

**Intent**: Create the entire system in one step.

**Details**:
- Build everything
- Make it work
- Add tests

**Tests**:
- Test everything
```

**Good Example:**

```markdown
### 1.1 - Create Domain Context Class

**Intent**: Create isolated data object for service requests. Provides clean interface between controllers and services.

**Details**:
- Plain Ruby class with keyword arguments
- Attributes: primary_field, required_field, optional_field (default: value), additional_fields
- Read-only accessors (attr_reader)
- No business logic, pure data container
- UUID generated in initialize

**Tests**:
- Initialize with all parameters
- Initialize with only required parameters
- Default values applied correctly
- Attribute readers work
- UUID unique per instance
```

**Why**: Small steps are completable. Clear intent guides implementation. Tests define success.

---

### [PLAN][!EVERY-STEP-HAS-TESTS]

**Rule**: Every step has Tests section with unit tests, integration tests, and edge cases.

**Good Example:**

```markdown
### 2.3 - Add Service Error Handling

**Intent**: Handle external API failures gracefully with proper error responses.

**Details**:
- Catch network timeouts (raise ServiceTimeoutError)
- Catch invalid API responses (raise ServiceAPIError)
- Catch rate limiting (raise ServiceRateLimitError)
- Return structured error responses to client

**Tests**:
Unit:
- Timeout raises ServiceTimeoutError
- Invalid response raises ServiceAPIError
- Rate limit raises ServiceRateLimitError

Integration:
- Controller returns 503 on timeout
- Controller returns 502 on API error
- Controller returns 429 on rate limit

Edge Cases:
- Multiple rapid failures
- Partial response handling
- Empty response body
```

**Why**: Tests define completion criteria. Edge cases prevent production bugs.

---

### [PLAN][!NO-IMPLEMENTATION-CODE]

**Rule**: Plans describe what and why, never how. No code in Details section.

**Bad Example:**

```markdown
**Details**:
- Add this code to the class:
  ```ruby
  def process(input, param)
    response = http_client.post('/endpoint', { input: input, param: param })
    JSON.parse(response.body)
  end
  ```
```

**Good Example:**

```markdown
**Details**:
- Accept input data and parameters
- Make HTTP POST request to external endpoint
- Parse JSON response
- Return processed result
- Handle network errors
```

**Why**: Implementation details constrain creativity. Describe outcomes, not code.

---

### [PLAN][!EXECUTION-ONE-STEP-AT-A-TIME]

**Rule**: Execute steps sequentially. Write tests first, run tests before next step, commit after each milestone.

**Good Pattern:**

```
Step 1.1:
1. Read step Intent and Details
2. Write tests (from Tests section)
3. Run tests (should fail - red)
4. Implement functionality
5. Run tests (should pass - green)
6. Refactor if needed
7. Run tests again (still green)
8. Mark step complete

Step 1.2:
(repeat pattern)

After Milestone 1:
- All tests passing
- Git commit with message: "Complete Milestone 1: [title]"
- Review milestone goals achieved
```

**Why**: Sequential execution prevents scope creep. TDD ensures quality. Commits provide rollback points.

---

## Pattern: Complete Project Plan

```markdown
# Project Plan: Feature Implementation

## Overview

Add new feature with service layer, domain objects, and API integration.

## Goals

- Create service layer for business logic
- Add domain models with validation
- Integrate with external dependencies
- Expose via RESTful API

---

## Milestone 1 - Build Core Domain

Create domain objects and business logic foundation.

### 1.1 - Create Domain Model

**Intent**: Create domain model to represent core entity.

**Details**:
- Primary identifier (unique, validated)
- Required attributes with validation
- Timestamp tracking
- UUID primary key

**Tests**:
- Create model with valid attributes
- Uniqueness constraints enforced
- Validation rules applied
- Attribute accessors work

---

### 1.2 - Create Service Class

**Intent**: Encapsulate business logic in service layer.

**Details**:
- Accept domain objects as input
- Perform business operations
- Coordinate with dependencies
- Return structured results
- Handle error cases

**Tests**:
- Service executes with valid input
- Service validates input parameters
- Service returns expected result format
- Service handles error cases
- Dependencies called correctly

---

## Milestone 2 - Add API Layer

Create HTTP endpoints and serializers.

### 2.1 - Create Controller

**Intent**: Handle HTTP requests and delegate to service.

**Details**:
- POST /api/resource endpoint
- Accept required parameters
- Validate request data
- Delegate to service layer
- Return serialized response
- Handle error responses

**Tests**:
- Request with valid data returns success
- Request with invalid data returns error
- Error responses include helpful messages
- Status codes correct for all cases
- Response format matches specification

---

(continue pattern...)
```

---

## Checklist

**Before Starting Implementation:**
- [ ] Research completed (docs + architecture)
- [ ] Project directory created with date prefix
- [ ] file_references.md lists all existing files
- [ ] file_references.md lists all planned files
- [ ] file_references.md has Before/Added tree sections
- [ ] project_plan.md has Overview and Goals
- [ ] Every milestone has 3-7 focused steps
- [ ] Every step has Intent section (what + why + how it fits)
- [ ] Every step has Details section (requirements, no code)
- [ ] Every step has Tests section (unit + integration + edge)
- [ ] Steps are numbered (milestone.step format)
- [ ] No implementation code in plan

**During Implementation:**
- [ ] Execute one step at a time
- [ ] Write tests first (TDD)
- [ ] Run tests before moving to next step
- [ ] Commit after each milestone
- [ ] Update file_references.md as files created

---

## Summary

**Key Principles:**

1. **Research first** - Use docs before source code
2. **Complete file tracking** - All existing and planned files
3. **Logical milestones** - Independently demonstrable progress
4. **Small steps** - One session, clear intent, tests required
5. **No code in plans** - Describe what, not how
6. **Sequential execution** - One step at a time, TDD, commit after milestones

**Benefits:**

- Clear roadmap reduces uncertainty
- Small steps enable steady progress
- Tests define completion criteria
- File tracking prevents surprises
- Milestones provide checkpoints
- Plans are reusable and reviewable


