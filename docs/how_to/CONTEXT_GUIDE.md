---
alwaysApply: true
---

# LLM Context Inclusion Guide

**Purpose**: Guide for selecting appropriate documentation files as context for different tasks

---

## Quick Reference: What to Include When

### Working on Controllers/APIs
**Include**:
- `architecture/api_design.md` (thin controllers, validation, serializers)
- `architecture/parameter_patterns.md` (explicit parameters, no splats)
- `back_end/serialization.md` (show/index methods)
- `architecture/type_safety_sorbet.md` (Sorbet signatures)

### Working on Services
**Include**:
- `architecture/service_layer_architecture.md` (service patterns, DI)
- `back_end/service_objects.md` (service object patterns)
- `back_end/oop_fundamentals.md` (core OOP, validation)
- `architecture/parameter_patterns.md` (explicit parameters)

### Working on External API Integrations (LLMs, Payment APIs)
**Include**:
- `architecture/external_api_clients.md` (request/response serializers)
- `llm_integration.md` (LLM-specific patterns)
- `architecture/parameter_patterns.md` (explicit parameters)

### Working on Domain Models (Backend)
**Include**:
- `back_end/oop_fundamentals.md` (entity/value objects, validation)
- `back_end/validation_patterns.md` (constructor validation)
- `architecture/type_safety_sorbet.md` (Sorbet types, UUID)

### Working on Domain Models (Frontend)
**Include**:
- `front_end/domain_models_frontend.md` (frontend OOP patterns)
- `front_end/type_safety_typescript.md` (TypeScript strict mode)
- `front_end/state_management.md` (Zustand integration)

### Working on React Components
**Include**:
- `front_end/component_patterns.md` (component structure)
- `architecture/component_composition.md` (composition patterns)
- `front_end/type_safety_typescript.md` (TypeScript for components)
- `front_end/state_management.md` (state management)

### Working on Tests (Backend)
**Include**:
- `back_end/testing_backend.md` (RSpec, FactoryBot, speed profiles)
- `back_end/oop_fundamentals.md` (for creating test fixtures)

### Working on Tests (Frontend)
**Include**:
- `front_end/testing_frontend.md` (Playwright, typed factories)
- `front_end/domain_models_frontend.md` (for creating test fixtures)

### Working on Streaming/Real-time Features
**Include**:
- `architecture/streaming_architecture.md` (SSE, pub/sub)
- `architecture/service_layer_architecture.md` (broadcaster pattern)

### Working on Agent/Tool Systems
**Include**:
- `architecture/tool_registration_patterns.md` (tool registration)
- `architecture/context_and_checkpoints.md` (context management)
- `architecture/inheritance_hierarchical_patterns.md` (state machines)

### Working on Scripts/DevOps
**Include**:
- `back_end/script_design.md` (shell script patterns)

### Working on Refactoring/Architecture Review
**Include**:
- `README.md` (overview of all patterns)
- Specific files based on area being refactored

---

## File Sizes (for context planning)

**Small (~300-500 lines)** - Can include multiple:
- oop_fundamentals.md
- validation_patterns.md
- api_design.md
- parameter_patterns.md
- serialization.md
- service_objects.md
- script_design.md

**Medium (~600-800 lines)** - Include 1-2:
- testing_backend.md
- testing_frontend.md
- type_safety_sorbet.md
- type_safety_typescript.md
- external_api_clients.md
- context_and_checkpoints.md
- tool_registration_patterns.md
- streaming_architecture.md

**Large (~900-1100 lines)** - Include only 1:
- service_layer_architecture.md
- inheritance_hierarchical_patterns.md

---

## Pattern Cross-References

### Keyword Arguments Pattern
Referenced in:
- ALL backend files (uses Ruby keyword arguments)
- ALL frontend files (uses TypeScript destructured parameters)
- Explicitly documented as anti-pattern in 5 files

### Serializer Pattern (show/index)
Referenced in:
- `back_end/serialization.md` (defines pattern)
- `architecture/api_design.md` (uses in controllers)
- `architecture/type_safety_sorbet.md` (shows types)
- `back_end/service_objects.md` (uses in examples)

### Type Safety Pattern
Referenced in:
- `architecture/type_safety_sorbet.md` (backend)
- `front_end/type_safety_typescript.md` (frontend)
- Used in all code examples across all files

### Validation Pattern
Referenced in:
- `back_end/validation_patterns.md` (defines pattern)
- `back_end/oop_fundamentals.md` (shows in constructors)
- Used in all model examples

---

## Universal Patterns (in ALL files)

1. **No Positional Arguments**
   - Ruby: Always use `param:`
   - TypeScript: Always use `{ param }`

2. **Keyword Arguments Everywhere**
   - Methods: `def method(param:)`
   - Calls: `method(param: value)`

3. **Strong Typing**
   - Ruby: Sorbet `sig` blocks
   - TypeScript: Explicit types, no `any`

4. **UUID for IDs**
   - Ruby: Custom `UUID` type
   - TypeScript: `string` with uuid validation

5. **Fail Fast Validation**
   - Validate in constructors
   - Raise with clear messages
   - No safety fallbacks

6. **No Mocks in Tests**
   - Use real instances
   - FactoryBot (backend)
   - Factory functions (frontend)

---

## When to Update This Guide

Update when:
- Adding new documentation files
- Changing file organization
- Adding new major patterns
- Splitting or merging files

