---
description: Quick reference card for frontend TypeScript/React patterns
globs: ""
alwaysApply: false
---

# Frontend Quick Reference

**Purpose**: Fast rule scanning for LLMs and developers

---

## Object-Oriented Programming

`[FE-OOP][!CLASSES-WITH-NAMED-PARAMS]` - Use classes with named parameters (destructured), never plain objects  
`[FE-OOP][!VALIDATE-AND-FAIL-FAST]` - Type validation in constructors, fail fast on invalid input  
`[FE-OOP][!VALIDATE-IN-CONSTRUCTOR]` - All validation happens in constructor, fail immediately  
`[FE-OOP][!SINGLE-RESPONSIBILITY]` - One class, one purpose; split if >150 lines  
`[FE-OOP][!COMPOSITION-OVER-INHERITANCE]` - Compose behavior rather than deep inheritance  
`[FE-OOP][!ENCAPSULATION]` - Private fields with public getters, controlled state access  
`[FE-OOP][!GETTERS-ONLY]` - Read-only access via getters, no direct field access  
`[FE-OOP][!MIRROR-BACKEND]` - Frontend domain models mirror backend structure  
`[FE-OOP][!NO-POSITIONAL-PARAMS]` - Named parameters everywhere, never positional

---

## TypeScript Type Safety

`[TS][!STRICT-MODE]` - Always use `strict: true` in tsconfig  
`[TS][!DOMAIN-INTERFACES]` - Define interfaces for all domain models  
`[TS][!API-TYPES]` - Type all API request/response objects  
`[TS][!STATE-TYPES]` - Type all state slices in stores  
`[TS][!COMPONENT-PROPS]` - Interface for every component's props  
`[TS][!EVENT-HANDLERS]` - Type all event handler functions  
`[TS][!DISCRIMINATED-UNIONS]` - Use discriminated unions for state variants  
`[TS][!GENERICS]` - Use generics for reusable type-safe utilities  
`[TS][!NO-POSITIONAL-PARAMS]` - Named parameters in all function signatures

---

## Components

`[COMP][!SINGLE-RESPONSIBILITY]` - One component, one responsibility; split if >100 lines  
`[COMP][!PROPS-DOWN-EVENTS-UP]` - Data flows down via props, events flow up via callbacks  
`[COMP][!EXTRACT-HOOKS]` - Extract business logic to custom hooks  
`[COMP][!CONTAINER-PRESENTATIONAL]` - Separate container (logic) from presentational (rendering)

---

## State Management

`[STATE][!ZUSTAND-GLOBAL]` - Use Zustand for global application state  
`[STATE][!LOCAL-UI-STATE]` - Use useState for local UI-only state  
`[STATE][!NO-MUTATION]` - Immutable state updates with immer  
`[STATE][!GROUP-ACTIONS-BY-DOMAIN]` - Group related actions in domain slices

---

## API Integration

`[API][!FROM-JSON-STATIC-METHOD]` - Static `fromJson()` methods for deserialization  
`[API][!TO-JSON-BEFORE-SENDING]` - Instance `toJson()` methods for serialization  
`[API][!DESERIALIZE-TO-DOMAIN-OBJECTS]` - Always deserialize API responses to domain classes  
`[API][!EVENTSOURCE-FOR-STREAMING]` - Use EventSource utility for SSE streams

---

## Testing

`[TEST-FE][!TYPESCRIPT-STRICT]` - Full TypeScript type safety in tests  
`[TEST-FE][!TYPED-FACTORIES]` - Type-safe factory functions for test data  
`[TEST-FE][!BEFORE-EACH-FOR-REUSE]` - Use `beforeEach()` for reusable test setup  
`[TEST-FE][!INPUT-OUTPUT-ONLY]` - Test public interface only, not implementation  
`[TEST-FE][!SPEED-PROFILE-E2E]` - Speed profile functions for E2E tests (fast/medium/slow)  
`[TEST-FE][!WAIT-FOR-CONDITIONS]` - Wait for actual conditions, never explicit timeouts  
`[TEST-FE][!WAIT-FOR-ELEMENTS]` - Wait for specific elements, not network idle  
`[TEST-FE][!TYPED-PAGE-OBJECTS]` - Use typed page object models for complex pages  
`[TEST-FE][!USE-STANDARDIZED-SCRIPTS]` - Always use `bin/e2e` or `bin/test-fe`, never direct npm commands

---

## Cross-Reference

- **Full OOP Patterns**: `front_end/oop_fundamentals.md`
- **Type Safety Guide**: `front_end/type_safety_typescript.md`
- **Domain Models**: `front_end/domain_models_frontend.md`
- **Component Patterns**: `front_end/component_patterns.md`
- **State Management**: `front_end/state_management.md`
- **API Integration**: `front_end/api_integration.md`
- **Testing Guide**: `front_end/testing_frontend.md`


