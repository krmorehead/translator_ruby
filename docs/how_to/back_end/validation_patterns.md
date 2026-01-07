---
description: Input validation patterns for Ruby/Rails models and services
globs: app/{models,services}/**/*.rb
alwaysApply: false
---

# Input Validation Patterns

**Tags**: [coding, back_end]  
**Applies To**: Ruby/Rails validation  

## Overview

Validation patterns ensure data integrity through fail-fast validation in constructors and strict type checking. Validate types only, then let usage fail loudly.

## Validation Flow Tree

```
Validation Hierarchy
│
├── Constructor Validation (minimal, type-focused)
│   ├── Type Validation (verify class)
│   │   ├── raise TypeError unless param.is_a?(String)
│   │   ├── raise TypeError unless param.is_a?(Integer)
│   │   └── raise TypeError unless param.is_a?(Hash)
│   │
│   └── Let Everything Else Fail Naturally
│       ├── .nil? → Will fail when method called on nil
│       ├── .empty? → Will fail when used
│       ├── Invalid format → Will fail at usage point
│       └── Trust internal code to fail loudly
│
├── Hash Access (.fetch vs [])
│   ├── ❌ Silent: config = json["config"]  # nil if missing
│   └── ✅ Loud: config = json.fetch("config")  # KeyError
│
├── Method Calls (no safety conditionals)
│   ├── ❌ Safety: browser.quit if browser
│   └── ✅ Loud: browser.quit  # Raises if nil
│
└── No Fallbacks (require explicit values)
    ├── ❌ Mask: name = name || "Unknown"
    └── ✅ Explicit: name = name  # Requires value
```

---

## Rules

### [VAL][!TYPE-ONLY-NO-FALLBACKS]

**Rule**: Validate types in constructors only. No fallbacks, no defaults, no over-validation. Trust internal code to fail loudly.

**Bad Example:**

```ruby
# ❌ Over-validation + fallbacks mask real issues
class Task
  def initialize(text: nil, priority: nil)
    @text = text || "Unknown"  # Silent fallback!
    @priority = priority || 1
    
    raise ArgumentError if @text.strip.empty?  # Over-defensive
    raise ArgumentError unless (1..3).include?(@priority)  # Too specific
  end
  
  def process(entity:)
    entity.perform_action
  rescue StandardError => e
    {success: false}  # Swallows errors!
  end
end
```

**Good Example:**

```ruby
# typed: strict
# ✅ Type validation only, no fallbacks, fail loud
class Task
  extend T::Sig
  
  sig { params(text: String, priority: Integer).void }
  def initialize(text:, priority:)
    @id = T.let(UUID.generate, UUID)
    raise TypeError unless text.is_a?(String)
    raise TypeError unless priority.is_a?(Integer)
    
    @text = T.let(text, String)  # No fallback
    @priority = T.let(priority, Integer)
  end
  
  sig { returns(String) }
  def display
    @text.upcase  # Will fail loudly if @text is nil/empty
  end
  
  sig { params(entity: Entity).void }
  def process(entity:)
    entity.perform_action  # No rescue - let it fail
  end
end
```

**Why**: Over-validation is defensive programming that masks issues. Fallbacks hide bugs. Type checks ensure correct class, then let methods fail naturally with clear stack traces.

---

### [VAL][!FETCH-AND-FAIL-LOUD]

**Rule**: Use `.fetch()` for hash access. No safety conditionals. Let methods fail loud if unexpected state.

**Bad Example:**

```ruby
# ❌ Silent nils + safety conditionals
config = json["config"]  # nil if missing
capabilities = config["capabilities"] if config  # NoMethodError on nil!

if browser_tool.browser
  browser_tool.browser.quit  # Masks unexpected state
end

# ❌ Cleanup with safety
if @resource
  @resource.close
end
```

**Good Example:**

```ruby
# typed: strict
# ✅ .fetch() fails loud + no safety conditionals
config = T.let(json.fetch("config"), T::Hash[String, String])
capabilities = T.let(config.fetch("capabilities"), String)
model = T.let(capabilities.fetch("model"), String)

# ✅ Fail loud if unexpected state
browser_tool.browser.quit  # Raises if browser nil
browser_tool.instance_variable_set(:@browser, nil)

# ✅ No safety in cleanup
@resource.close  # Raises if unexpected state
```

**Why**: `.fetch()` makes missing keys obvious immediately. Safety conditionals mask bugs by hiding unexpected state. Clear failures point directly to problems.

---

## Summary

**Key Principles:**

1. **Type validation only** - No empty checks, no format validation
2. **No fallbacks** - No `||` operators, no default values
3. **Use `.fetch()`** - For hash access, fail loud on missing keys
4. **No safety conditionals** - No `if obj` checks, let methods fail
5. **No rescue blocks** - Don't swallow errors, let them bubble up
6. **Trust internal code** - Let usage fail naturally with clear stack traces

**Benefits:**

- Real errors surface immediately at source
- Clear stack traces point to actual problems
- No defensive programming masking bugs
- Predictable, deterministic behavior
- Faster debugging with loud failures

