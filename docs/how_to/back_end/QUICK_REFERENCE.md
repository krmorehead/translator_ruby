---
description: Quick reference card for backend Ruby/Rails patterns
globs: ""
alwaysApply: false
---

# Backend Quick Reference

**Purpose**: Fast rule scanning for LLMs and developers

---

## Object-Oriented Programming

`[OOP][!CLASSES-WITH-KEYWORDS]` - Use classes with keyword arguments, never plain objects or hashes  
`[OOP][!VALIDATE-AND-FAIL-FAST]` - Type validation in constructors, fail loud on invalid input  
`[OOP][!SINGLE-RESPONSIBILITY]` - One class, one purpose; split if >150 lines  
`[OOP][!COMPOSITION-OVER-INHERITANCE]` - Compose behavior from capabilities rather than deep inheritance

---

## Validation

`[VAL][!TYPE-ONLY-NO-FALLBACKS]` - Validate types only in constructors; no fallbacks, no defaults  
`[VAL][!FETCH-AND-FAIL-LOUD]` - Use `.fetch()` for hash access; no safety conditionals

---

## Service Objects

`[SVC][!THIN-CONTROLLERS-DELEGATE-TO-SERVICES]` - Controllers delegate to services for business logic  
`[SVC][!EXPLICIT-DEPENDENCIES-NO-DEFAULTS]` - Inject dependencies explicitly; no defaults that mask errors  
`[SVC][!EXPLICIT-PARAMS-NO-SPLATS]` - Define explicit named parameters; no `**params` or `**options`

---

## Serialization

`[SER][!SERIALIZER-CLASSES-NOT-MODELS]` - Dedicated serializer classes with `show(instance:)` and `index(collection:)`  
`[SER][!USE-GETTERS-NOT-INSTANCE-VARS]` - Serializers read via getters, never access instance variables  
`[SER][!NESTED-SERIALIZERS]` - Use nested serializers for complex objects  
`[SER][!MULTIPLE-VIEWS]` - Use view parameter for different representations

---

## Testing

`[TEST][!RSPEC-FACTORYBOT-LET]` - RSpec structure with FactoryBot factories and lazy `let()`  
`[TEST][!INPUT-OUTPUT-NO-MOCKS]` - Test inputs/outputs only; use real instances, not mocks  
`[TEST][!WAIT-FOR-CONDITIONS]` - Wait for actual conditions, never use explicit timeouts  
`[TEST][!REAL-LLM-SLOW-PROFILE]` - LLM tests call real APIs with speed_profile :slow  
`[TEST][!USE-STANDARDIZED-SCRIPTS]` - Always use `bin/test`, never direct `rspec` commands

---

## Scripts

`[SCRIPT][!TRAP-CLEANUP-AND-ENV]` - Use trap for cleanup, set -e for fail-fast, explicit environment  
`[SCRIPT][!KILL-PORTS-AND-WAIT]` - Kill existing processes on ports, wait for health checks  
`[SCRIPT][!SPEED-FILTER-AND-COLOR]` - Support speed filter arguments and colored output

---

## Cross-Reference

- **Full OOP Patterns**: `back_end/oop_fundamentals.md`
- **Validation Details**: `back_end/validation_patterns.md`
- **Service Patterns**: `back_end/service_objects.md`
- **Serializer Patterns**: `back_end/serialization.md`
- **Testing Guide**: `back_end/testing_backend.md`
- **Script Patterns**: `back_end/script_design.md`


