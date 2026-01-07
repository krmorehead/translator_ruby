---
description: LLM-optimized architecture and design patterns documentation index
globs: ""
alwaysApply: true
---

# How To: LLM-Optimized Architecture & Design Patterns

**Audience**: LLMs and developers building robust applications  
**Format**: Strict rule syntax with concrete examples

## Overview

This documentation captures comprehensive architectural and design patterns for building robust, maintainable applications. All patterns are **framework-agnostic**, focusing on principles and shapes rather than specific implementations. Uses strict `[CATEGORY][!TAG]` rule syntax optimized for LLM consumption.

**Core Philosophies:**
- **Fail fast with descriptive errors** - No fallbacks, no safety conditionals
- **Real instances over mocks** - Always test with real objects
- **Type safety everywhere** - Strict validation in constructors  
- **Proper classes for entities** - Not hash-based state
- **Explicit over implicit** - Clear dependencies, no magic

**Documentation Approach:**
- **Patterns over specifics** - Shows shapes and principles, not exact methods
- **Small, illustrative examples** - Demonstrates concepts clearly
- **Framework-agnostic** - Applicable to any modern stack
- **LLM-optimized** - Structured for easy parsing and understanding

---

## Documentation Structure

### Project Planning (1 file)

Structured project planning with milestones and incremental development.

1. **[project_plan_structure.md](project_planning/project_plan_structure.md)**
   - Tags: [planning, design]
   - Research-first approach
   - File references (existing + planned)
   - Milestone-based structure
   - Small, testable steps
   - Test-driven execution
   - No implementation code in plans

**Quick Reference**: [project_planning/QUICK_REFERENCE.md](project_planning/QUICK_REFERENCE.md)

---

### Architecture (10 files)

System-level design patterns for scalable applications.

1. **[api_design.md](architecture/api_design.md)**
   - Tags: [architecture, coding, back_end]
   - Thin controller pattern
   - Parameter validation with string access
   - Service delegation
   - Serializer-based responses
   - Error handling
   - RESTful API design

2. **[parameter_patterns.md](architecture/parameter_patterns.md)**
   - Tags: [architecture, coding, back_end]
   - Explicit parameter patterns
   - No `**params` or `**options`
   - T::Struct for complex parameters
   - Sorbet signatures required
   - Anti-patterns to avoid

3. **[external_api_clients.md](architecture/external_api_clients.md)**
   - Tags: [architecture, coding, back_end]
   - External API client patterns
   - Request/response serializers
   - Inheritance hierarchy for reuse
   - String-only key access
   - LLM and third-party integrations
   - Domain object boundaries

4. **[type_safety_sorbet.md](architecture/type_safety_sorbet.md)**
   - Tags: [architecture, coding, back_end]
   - Sorbet type checking patterns
   - Method signatures with sig
   - Instance variable types with T.let
   - UUID type for identifiers
   - Type assertions at boundaries
   - Typed arrays and hashes

5. **[inheritance_hierarchical_patterns.md](architecture/inheritance_hierarchical_patterns.md)**
   - Tags: [architecture, design, coding]
   - Base class pattern with strict validation
   - Inheritance hierarchies (specialized subclasses)
   - Hierarchical relationships (parent → child contexts)
   - State machines for agents (idle → running → complete/failed)
   - Error recovery and retry logic for agents

6. **[streaming_architecture.md](architecture/streaming_architecture.md)**
   - Tags: [architecture, design]
   - Message broker pub/sub pattern
   - Server-Sent Events (SSE) for real-time updates
   - Centralized broadcaster service pattern
   - Reusable streaming concerns
   - Terminal event detection and auto-cleanup

7. **[service_layer_architecture.md](architecture/service_layer_architecture.md)**
   - Tags: [architecture, design, coding]
   - Controller → Service → Model layering
   - Service composition patterns
   - Service vs Agent decision tree
   - Dependency injection (explicit, no defaults)
   - Configuration vs execution services

8. **[tool_registration_patterns.md](architecture/tool_registration_patterns.md)**
   - Tags: [architecture, design, coding]
   - Registration pattern (agents declare needed tools)
   - Generic, reusable tool design
   - Context injection (working directory, boundaries)
   - Self-generating LLM-compatible schemas
   - Safety validation (path boundaries, restricted areas)

9. **[context_and_checkpoints.md](architecture/context_and_checkpoints.md)**
   - Tags: [architecture, design]
   - Context pattern for execution state
   - Explicit parameter passing (no global state)
   - Automatic checkpoint pattern with VCS
   - Metadata storage with version control
   - Singleton coordination pattern

10. **[component_composition.md](architecture/component_composition.md)**
   - Tags: [architecture, design, front_end]
   - Single Responsibility Principle for components
   - Composition over inheritance
   - Props down, events up (one-way data flow)
   - Custom hooks for business logic
   - Container vs Presentational separation

---

### Backend (6 files)

Ruby/Rails patterns for server-side development.

1. **[oop_fundamentals.md](back_end/oop_fundamentals.md)**
   - Tags: [coding, design, back_end]
   - `[OOP][!NO-HASH-ENTITIES]` - Never use hashes for domain entities
   - `[OOP][!STRICT-VALIDATION]` - Validate all parameters in constructors
   - `[OOP][!FAIL-FAST]` - Use .fetch() instead of []
   - `[OOP][!SINGLE-RESPONSIBILITY]` - One class, one purpose
   - `[OOP][!COMPOSITION]` - Prefer composition over inheritance

2. **[serialization.md](back_end/serialization.md)**
   - Tags: [coding, back_end]
   - `[SER][!SERIALIZER-CLASSES]` - Dedicated serializer classes for models
   - `[SER][!READ-PROPERTIES]` - Read via getters, not instance variables
   - `[SER][!NESTED-SERIALIZERS]` - Compose serializers for complex objects
   - `[SER][!COLLECTION-SERIALIZATION]` - Map over serializers for lists
   - Models have no serialization methods

3. **[validation_patterns.md](back_end/validation_patterns.md)**
   - Tags: [coding, back_end]
   - `[VAL][!VALIDATE-IN-CONSTRUCTOR]` - Validate in constructors
   - `[VAL][!NO-FALLBACKS]` - Never use fallbacks
   - `[VAL][!USE-FETCH]` - Use .fetch() instead of []
   - `[VAL][!NO-SAFETY-CONDITIONALS]` - No "if" for safety checks

4. **[testing_backend.md](back_end/testing_backend.md)**
   - Tags: [testing, back_end]
   - RSpec with FactoryBot patterns
   - `[TEST][!RSPEC-STRUCTURE]` - describe/context/it blocks
   - `[TEST][!FACTORYBOT-PATTERN]` - FactoryBot.define with traits
   - `[TEST][!LET-FOR-REUSE]` - let() for lazy evaluation
   - `[TEST][!CONTEXT-ISOLATION]` - Nested contexts for scenarios
   - `[TEST][!INPUT-OUTPUT-ONLY]` - Test public interface only
   - `[TEST][!NO-MOCKS]` - Real instances from FactoryBot
   - `[TEST][!NO-TIMEOUTS]` - Wait for conditions, not time
   - `[TEST][!REAL-LLM]` - Real LLM calls with speed_profile :slow
   - `[TEST][!REAL-LLM]` - All tests call real LLM
   - `[TEST][!FILE-OUTPUT]` - Save test output to files to avoid hangs
   - `[TEST][!FACTORIES]` - Use factories for complex objects
   - Speed SLAs: fast <10s, medium <60s, slow <120s

5. **[service_objects.md](back_end/service_objects.md)**
   - Tags: [coding, design, back_end]
   - `[SVC][!THIN-CONTROLLERS]` - Controllers delegate to services
   - `[SVC][!BUSINESS-LOGIC-IN-SERVICES]` - Business logic in services
   - `[SVC][!SERIALIZERS-FOR-JSON]` - Controllers use serializers
   - `[SVC][!SERVICE-NAMING]` - Clear naming: *Service, *Store, *Broadcaster
   - `[SVC][!DEPENDENCY-INJECTION]` - Explicit dependency injection, no defaults

6. **[script_design.md](back_end/script_design.md)**
   - Tags: [coding, back_end, testing]
   - `[SCRIPT][!ENV-MANAGEMENT]` - Load .env explicitly
   - `[SCRIPT][!CLEANUP-TRAPS]` - Use trap for cleanup on exit
   - `[SCRIPT][!KILL-EXISTING-PROCESSES]` - Kill before starting servers
   - `[SCRIPT][!WAIT-FOR-READY]` - Wait for server ready state
   - `[SCRIPT][!SPEED-FILTER-SUPPORT]` - Support TEST_SPEED_FILTER env var
   - `[SCRIPT][!COLOR-OUTPUT]` - Use colors for readability

---

### Frontend (7 files)

React/TypeScript patterns for client-side development.

1. **[oop_fundamentals.md](front_end/oop_fundamentals.md)**
   - Tags: [coding, design, front_end]
   - Core OOP patterns for TypeScript/JavaScript
   - `[FE-OOP][!NO-POSITIONAL-PARAMS]` - Named parameters everywhere
   - `[FE-OOP][!NO-PLAIN-OBJECTS]` - Classes not plain objects
   - `[FE-OOP][!STRICT-VALIDATION]` - Constructor validation
   - `[FE-OOP][!COMPOSITION]` - Composition over inheritance
   - `[FE-OOP][!UUID-PATTERN]` - crypto.randomUUID() first line

2. **[type_safety_typescript.md](front_end/type_safety_typescript.md)**
   - Tags: [coding, front_end]
   - TypeScript strict mode configuration
   - Domain model interfaces
   - Component prop types
   - API request/response types
   - Discriminated unions for state
   - Generics for reusable components

3. **[domain_models_frontend.md](front_end/domain_models_frontend.md)**
   - Tags: [coding, design, front_end]
   - `[FE-OOP][!MIRROR-BACKEND]` - Frontend models mirror backend exactly
   - `[FE-OOP][!VALIDATE-IN-CONSTRUCTOR]` - Validate all parameters in constructor
   - `[FE-OOP][!GETTERS-ONLY]` - Getters for read-only access
   - Base classes for shared functionality
   - TypeScript migration readiness

4. **[component_patterns.md](front_end/component_patterns.md)**
   - Tags: [coding, design, front_end]
   - `[COMP][!SRP-COMPONENTS]` - One responsibility per component
   - `[COMP][!PROPS-DOWN-EVENTS-UP]` - One-way data flow
   - `[COMP][!EXTRACT-HOOKS]` - Business logic in custom hooks
   - `[COMP][!CONTAINER-PRESENTATIONAL]` - Separate logic from presentation
   - Components < 100 lines

5. **[state_management.md](front_end/state_management.md)**
   - Tags: [coding, front_end]
   - `[STATE][!ZUSTAND-GLOBAL]` - Zustand for global state
   - `[STATE][!LOCAL-UI-STATE]` - Keep UI state local
   - `[STATE][!GROUP-ACTIONS-BY-DOMAIN]` - Group by domain
   - `[STATE][!NO-MUTATION]` - Never mutate state directly

6. **[testing_frontend.md](front_end/testing_frontend.md)**
   - Tags: [testing, front_end]
   - `[TEST-FE][!SPEED-PROFILE-E2E]` - Use fast/medium/slow functions
   - `[TEST-FE][!NO-EXPLICIT-TIMEOUTS]` - Never use timeouts/sleeps - wait for conditions
   - `[TEST-FE][!NO-NETWORKIDLE]` - Never use waitForLoadState("networkidle")
   - `[TEST-FE][!WAIT-FOR-ELEMENTS]` - Wait for specific elements
   - `[TEST-FE][!TYPED-PAGE-OBJECTS]` - Use typed page object models
   - `[TEST-FE][!REAL-DOMAIN-OBJECTS]` - Use real objects in E2E
   - Speed SLAs: fast <5s, medium <15s, slow <30s

7. **[api_integration.md](front_end/api_integration.md)**
   - Tags: [coding, front_end]
   - `[API][!DESERIALIZE-TO-DOMAIN-OBJECTS]` - Transform responses to objects
   - `[API][!FROM-JSON-STATIC-METHOD]` - Static fromJSON for deserialization
   - `[API][!TO-JSON-BEFORE-SENDING]` - Serialize with toJSON()
   - `[API][!EVENTSOURCE-FOR-STREAMING]` - Use EventSource for SSE

---

### Cross-Cutting (1 file)

Patterns applicable across all layers.

1. **[llm_integration.md](llm_integration.md)**
   - Tags: [architecture, coding, design]
   - `[LLM][!PROMPT-EXAMPLES]` - Concrete JSON examples in prompts
   - `[LLM][!CONTEXT-INJECTION]` - Inject context automatically
   - `[LLM][!SYMBOLIZE-AT-BOUNDARY]` - Symbolize responses at boundary
   - `[LLM][!TOOL-SCHEMA-GENERATION]` - Tools generate own schemas
   - `[LLM][!PROMPT-BUILDERS]` - Prompts encapsulate message building
   - `[LLM][!TOKEN-TRACKING]` - Track token usage for all calls

---

## Tag Index

Find documentation by tag:

### By Activity
- **[architecture]**: System design, patterns, high-level structure
  - api_design, parameter_patterns, external_api_clients, type_safety_sorbet, inheritance_hierarchical_patterns, streaming_architecture, service_layer_architecture, tool_registration_patterns, context_and_checkpoints, component_composition, llm_integration

- **[coding]**: Implementation patterns, code-level guidance
  - api_design, parameter_patterns, external_api_clients, type_safety_sorbet, type_safety_typescript, inheritance_hierarchical_patterns, service_layer_architecture, tool_registration_patterns, oop_fundamentals, serialization, validation_patterns, service_objects, script_design, domain_models_frontend, component_patterns, state_management, api_integration, llm_integration

- **[design]**: Design patterns, structure, organization
  - inheritance_hierarchical_patterns, streaming_architecture, service_layer_architecture, tool_registration_patterns, context_and_checkpoints, component_composition, oop_fundamentals, service_objects, domain_models_frontend, component_patterns, llm_integration

- **[testing]**: Testing strategies, patterns, tooling
  - testing_backend, script_design, testing_frontend

### By Layer
- **[back_end]**: Server-side patterns
  - oop_fundamentals, serialization, validation_patterns, testing_backend, service_objects, script_design

- **[front_end]**: Client-side patterns
  - type_safety_typescript, component_composition, domain_models_frontend, component_patterns, state_management, testing_frontend, api_integration

---

## Quick Reference

### Universal Anti-Patterns

**[NO-POSITIONAL-ARGS]** - Never use positional arguments/parameters

```ruby
# ❌ BAD - Positional (Ruby)
def create(goal, priority)
service.create("goal", 1)

# ✅ GOOD - Keywords (Ruby)
def create(goal:, priority:)
service.create(goal: "goal", priority: 1)
```

```typescript
// ❌ BAD - Positional (TypeScript)
function create(goal: string, priority: number)
service.create("goal", 1)

// ✅ GOOD - Destructured (TypeScript)
function create({ goal, priority }: CreateParams)
service.create({ goal: "goal", priority: 1 })
```

**Why**: Self-documenting, order-independent, refactor-safe, prevents mistakes.

---

### Core Principles (Top 10)

1. **No hash-based entities** - Always create proper classes
2. **Validate in constructors** - Fail fast with descriptive errors
3. **No mocks in tests** - Always use real instances
4. **Real LLM calls** - Never mock LLM responses
5. **Speed profile every test** - Declare :fast/:medium/:slow
6. **Symbolize at boundaries** - Consistent symbol usage
7. **Explicit context passing** - No global state
8. **Single responsibility** - One class/component, one purpose
9. **Concrete examples in prompts** - Show, don't tell

### Common Patterns

**Object Creation:**
```ruby
# typed: strict
# ✅ Proper class with validation
class Execution
  extend T::Sig
  
  sig { params(status: Symbol).void }
  def initialize(status: :pending)
    @id = T.let(UUID.generate, UUID)
    raise TypeError unless status.is_a?(Symbol)
    @status = T.let(status, Symbol)
  end
end
```

**Service Pattern:**
```ruby
# typed: strict
# ✅ Service with dependency injection
class EntityService
  extend T::Sig
  
  sig { params(dependency: Dependency).void }
  def initialize(dependency:)
    @id = T.let(UUID.generate, UUID)
    @dependency = T.let(dependency, Dependency)
  end
  
  sig { params(entity_id: UUID, action: String).returns(Result) }
  def execute(entity_id:, action:)
    raise TypeError unless entity_id.is_a?(UUID)
    result = perform_operation(entity_id: entity_id, action: action)
    Result.new(success: true, data: result)
    # No rescue - let errors bubble up
  end
  
  private
  
  sig { params(entity_id: UUID, action: String).returns(String) }
  def perform_operation(entity_id:, action:)
    # Implementation
    "result"
  end
end
```

**Testing Pattern:**
```ruby
# typed: strict  # Tests use typed: strict for type safety
# ✅ RSpec with FactoryBot
RSpec.describe MyClass do
  speed_profile :fast
  
  let(:instance) { build(:my_class) }
  
  it "validates input" do
    service = MyService.new(dependency: RealDependency.new)
    result = service.execute(param: "value")
    assert result[:success]
  end
end
```

**Frontend Domain Model:**
```typescript
// ✅ Proper validation with TypeScript
type WorkflowStatus = 'pending' | 'approved' | 'rejected';

interface WorkflowEntityData {
  readonly status: WorkflowStatus;
  readonly resolvedBy?: string;
}

export class WorkflowEntity {
  private readonly _id: string;
  private readonly _status: WorkflowStatus;
  private readonly _resolvedBy?: string;

  constructor(data: WorkflowEntityData) {
    this._id = crypto.randomUUID();
    this._status = data.status;
    this._resolvedBy = data.resolvedBy;
  }
  
  get id(): string { 
    return this._id; 
  }
  
  get status(): WorkflowStatus { 
    return this._status; 
  }
  
  approve(by: string): void {
    // Mutate the object
    this._status = 'approved';
    this._resolvedBy = by;
  }
}
```

---

## Usage Guidelines

### For LLMs

This documentation uses strict rule syntax for easy parsing:

```
[CATEGORY][!TAG] Rule description

**Bad Example:** ... (code showing what NOT to do)
**Good Example:** ... (code showing correct approach)
**Why:** ... (explanation of benefits)
```

**Categories:**
- `OOP`, `SER`, `VAL`, `TEST`, `SVC`, `SCRIPT` (Backend)
- `FE-OOP`, `COMP`, `STATE`, `TEST-FE`, `API` (Frontend)
- `ARCH`, `LLM` (Cross-cutting)

**To use:**
1. Search by tag: `[architecture]`, `[testing]`, `[coding]`
2. Search by rule: `[OOP][!NO-HASH-ENTITIES]`
3. Follow concrete examples (Bad → Good)
4. Apply "Why" reasoning to similar situations

### For Developers

Each file contains:
- **Rules** - Prescriptive patterns with examples
- **Patterns** - Reusable code templates
- **Real-World Examples** - Actual codebase usage
- **Checklists** - Verification steps
- **Summary** - Quick reference

**Best practices:**
1. Read "Overview" to understand when to use
2. Follow "Rules" strictly (marked with `[CATEGORY][!TAG]`)
3. Copy "Patterns" as starting templates
4. Adapt "Real-World Examples" to your context
5. Use "Checklists" to verify implementation

---

## Framework Agnostic

While examples use Ruby on Rails and React, the principles apply to any stack:

- **OOP patterns** → Java, C#, Python, TypeScript
- **Service layer** → Any MVC framework
- **Testing patterns** → JUnit, pytest, Jest
- **Component composition** → Vue, Angular, Svelte
- **State management** → Redux, MobX, Pinia
- **LLM integration** → Any LLM API (OpenAI, Anthropic, etc.)

Translate syntax while preserving principles:
- Ruby `def` → JavaScript `function`
- Ruby `raise` → JavaScript `throw new Error`
- Ruby symbols → JavaScript strings
- RSpec `describe/it` → Jest/Vitest `describe/it`
- FactoryBot → Factory functions in TypeScript

---

## Migration Notes

This documentation consolidates and supersedes:
- `rules/` directory (2026-01-05 and earlier)
- `docs/references/` directory (2026-01-05 and earlier)

All patterns have been extracted, generalized, and organized into the current structure.

**What changed:**
- Strict rule syntax (`[CATEGORY][!TAG]`)
- Framework-agnostic where possible
- Comprehensive tag index
- LLM-optimized format

**What stayed the same:**
- Core principles (fail-fast, no mocks, etc.)
- Real-world patterns from production code
- Concrete examples with Bad → Good transitions

---

## Contributing

When adding new patterns:

1. **Choose correct category** - architecture, back_end, front_end, or cross-cutting
2. **Use strict rule syntax** - `[CATEGORY][!TAG] Rule description`
3. **Provide concrete examples** - Both Bad (❌) and Good (✅)
4. **Explain why** - Benefits and reasoning
5. **Update this README** - Add to index and tag reference
6. **Keep it framework-agnostic** - Use Ruby/React as reference, make principles universal

---

## Complete File Index

**Total: 32 comprehensive documentation files**

- Project Planning: 2 files (1 guide + 1 quick ref)
- Architecture: 10 files
- Backend: 8 files (6 patterns + 1 quick ref + 1 anti-patterns)
- Frontend: 8 files (7 patterns + 1 quick ref)
- Cross-Cutting: 1 file
- Universal: 1 anti-patterns file

All patterns extracted from production codebase with real-world battle testing.
All documentation optimized for LLM consumption with strict rule syntax.
All principles framework-agnostic and applicable to any modern application stack.

---

**Last Updated**: 2026-01-05  
**Status**: Complete - All patterns documented  
**Format**: LLM-optimized with strict rule syntax

