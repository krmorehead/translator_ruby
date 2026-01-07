---
description: Core OOP patterns for Ruby/Rails backend development
globs: app/**/*.rb
alwaysApply: false
---

# Core OOP Patterns

**Tags**: [coding, design, back_end]  
**Applies To**: Ruby/Rails applications  

## Overview

Core OOP patterns prioritizing type safety, single responsibility, and fail-fast validation. Eliminate hash-based state, enforce strict validation, and make code predictable and maintainable.

## OOP Fundamentals Pattern

```
Domain Model Architecture
│
├── Value Objects (no identity)
│   ├── Properties: Validated in constructor
│   ├── Behavior: Query methods, calculations
│   └── Examples: Money, Address, DateRange, Coordinates
│
├── Entity Objects (identity, lifecycle)
│   ├── Properties: Unique identifier, mutable state
│   ├── Behavior: State transitions, query methods
│   └── Examples: User, Order, Session, Task
│
├── Service Objects (single responsibility)
│   ├── Purpose: Coordinate operations, orchestrate workflows
│   ├── Pattern: Stateless, dependency injection
│   └── Examples: RegistrationService, PaymentProcessor
│
├── Composition Over Inheritance
│   └── Compose behavior from capabilities rather than inherit
│
└── Base Class Pattern (when needed)
    ├── Base class provides common functionality
    ├── Subclasses extend with domain-specific behavior
    └── Always call super() explicitly

Validation Strategy:
Constructor Validation (fail fast)
├── Type validation: Ensure correct types
├── Value validation: Check constraints
└── Business validation: Domain rules

Pattern Comparison:
├── ❌ Hash-Based State
│   ├── No type safety
│   ├── Typos not caught
│   └── No methods available
│
├── ❌ Positional Arguments
│   ├── Not self-documenting
│   ├── Order-dependent
│   └── Refactoring danger
│
└── ✅ Proper Class
    ├── Type safe
    ├── Typos caught immediately
    └── Methods available
```

---

## Rules

### [OOP][!CLASSES-WITH-KEYWORDS]

**Rule**: Always use classes with keyword arguments. Never use hashes or positional arguments.

**Bad Example:**

```ruby
# ❌ Hash-based state + positional arguments
@execution = {
  id: SecureRandom.uuid,
  status: :pending,
  metadata: {}
}
@execution[:statu] = :complete  # Typo not caught!

class ExecutionService
  def initialize(store, broadcaster)  # ❌ Positional
    @store = store
  end
  
  def create(goal, priority)  # ❌ What's the order?
    @store.save(goal, priority)
  end
end

service.create("Goal", 1)  # Is it (goal, priority) or (priority, goal)?
```

**Good Example:**

```ruby
# typed: strict
# ✅ Proper class with keyword arguments
class Execution
  extend T::Sig
  
  STATUSES = T.let([:pending, :running, :complete].freeze, T::Array[Symbol])
  
  sig { returns(UUID) }
  attr_reader :id
  
  sig { returns(Symbol) }
  attr_reader :status
  
  sig { params(status: Symbol, metadata: T::Hash[Symbol, String]).void }
  def initialize(status: :pending, metadata: {})
    @id = T.let(UUID.generate, UUID)  # First line always
    raise TypeError unless status.is_a?(Symbol)
    @status = T.let(status, Symbol)
    @metadata = T.let(metadata, T::Hash[Symbol, String])
  end
  
  sig { returns(Execution) }
  def start
    Execution.new(status: :running, metadata: @metadata)
  end
end

class ExecutionService
  extend T::Sig
  
  sig { params(store: StateStore, broadcaster: Broadcaster).void }
  def initialize(store:, broadcaster:)  # ✅ Keywords everywhere
    @id = T.let(UUID.generate, UUID)
    @store = T.let(store, StateStore)
    @broadcaster = T.let(broadcaster, Broadcaster)
  end
  
  sig { params(goal: String, priority: Integer).returns(Execution) }
  def create(goal:, priority:)  # ✅ Self-documenting
    execution = Execution.new
    @store.save(execution: execution)
    execution
  end
end

# ✅ Crystal clear - order doesn't matter
service = ExecutionService.new(store: StateStore.new, broadcaster: Broadcaster.new)
service.create(goal: "Add feature", priority: 1)
service.create(priority: 1, goal: "Add feature")  # Same result!
```

**Why**: Classes provide type safety and catch typos. Keyword arguments prevent order mistakes, enable safe refactoring, and make code self-documenting.

---

### [OOP][!VALIDATE-AND-FAIL-FAST]

**Rule**: Validate all parameters in constructors. Use `.fetch()` for hash access. Let errors happen loudly.

**Bad Example:**

```ruby
# ❌ No validation + silent nils
class Goal
  def initialize(text:, priority:)
    @text = text  # Accepts nil
    @priority = priority  # Accepts anything
  end
end

config = json["config"]  # nil if missing
capabilities = config["capabilities"]  # NoMethodError on nil!

# ❌ Conditional safety masks bugs
if Tools::BrowserTool.browser
  Tools::BrowserTool.browser.quit
end
```

**Good Example:**

```ruby
# typed: strict
# ✅ Strict validation + fail fast
class Goal
  extend T::Sig
  
  PRIORITIES = T.let([1, 2, 3].freeze, T::Array[Integer])
  
  sig { params(text: String, priority: Integer).void }
  def initialize(text:, priority:)
    @id = T.let(UUID.generate, UUID)
    raise TypeError, "text must be String" unless text.is_a?(String)
    raise ArgumentError, "priority must be 1-3" unless PRIORITIES.include?(priority)
    
    @text = T.let(text, String)
    @priority = T.let(priority, Integer)
  end
end

# ✅ .fetch() fails loud
config = T.let(json.fetch("config"), T::Hash[String, String])
capabilities = T.let(config.fetch("capabilities"), String)

# ✅ Let methods fail loud
Tools::BrowserTool.browser.quit  # Fails if not in expected state
```

**Why**: Early validation catches bugs at source. `.fetch()` makes missing keys obvious immediately. Silent nils and conditional safety hide problems.

---

### [OOP][!SINGLE-RESPONSIBILITY]

**Rule**: Each class has ONE clear purpose. Split classes that do multiple things.

**Bad Example:**

```ruby
# ❌ God class doing everything
class UserManager
  def create_user(data:)
    # Validation, database, email, logging, cache, webhooks...
  end
end
```

**Good Example:**

```ruby
# typed: strict
# ✅ Single responsibilities
class User
  extend T::Sig
  
  sig { params(name: String, email: String).void }
  def initialize(name:, email:)
    @id = T.let(UUID.generate, UUID)
    @name = T.let(name, String)
    @email = T.let(email, String)
  end
end

class UserRepository
  extend T::Sig
  
  sig { params(user: User).void }
  def save(user:)
    # Database only
  end
end

class UserNotificationService
  extend T::Sig
  
  sig { params(user: User).void }
  def send_welcome_email(user:)
    # Email only
  end
end
```

**Why**: Small, focused classes are easier to test, understand, and modify.

---

### [OOP][!COMPOSITION-OVER-INHERITANCE]

**Rule**: Compose behavior from capabilities. Use inheritance only for true "is-a" relationships.

**Bad Example:**

```ruby
# ❌ Deep inheritance breaks contracts
class Bird < Animal
  def fly
    "flying"
  end
end

class Penguin < Bird
  def fly
    raise "Penguins can't fly"  # Breaking parent!
  end
end
```

**Good Example:**

```ruby
# typed: strict
# ✅ Composition with capabilities
class Capability
  extend T::Sig
  
  sig { returns(String) }
  def perform
    "default"
  end
end

class Flight < Capability
  sig { returns(String) }
  def perform
    "flying"
  end
end

class Swimming < Capability
  sig { returns(String) }
  def perform
    "swimming"
  end
end

class Animal
  extend T::Sig
  
  sig { returns(T::Array[Capability]) }
  attr_reader :capabilities
  
  sig { params(capabilities: T::Array[Capability]).void }
  def initialize(capabilities: [])
    @id = T.let(UUID.generate, UUID)
    @capabilities = T.let(capabilities, T::Array[Capability])
  end
end

bird = Animal.new(capabilities: [Flight.new])
penguin = Animal.new(capabilities: [Swimming.new])
```

**Why**: Composition is flexible and avoids inheritance problems.

---

## Pattern: Value Object

```ruby
# typed: strict
class Money
  extend T::Sig
  include Comparable
  
  sig { returns(Numeric) }
  attr_reader :amount
  
  sig { returns(String) }
  attr_reader :currency
  
  sig { params(amount: Numeric, currency: String).void }
  def initialize(amount:, currency:)
    @id = T.let(UUID.generate, UUID)
    raise TypeError unless amount.is_a?(Numeric)
    raise TypeError unless currency.is_a?(String)
    
    @amount = T.let(amount, Numeric)
    @currency = T.let(currency.upcase, String)
  end
  
  sig { params(other: Money).returns(Money) }
  def +(other)
    raise ArgumentError, "Different currencies" unless @currency == other.currency
    Money.new(amount: @amount + other.amount, currency: @currency)
  end
  
  sig { params(other: Money).returns(T.nilable(Integer)) }
  def <=>(other)
    return nil unless @currency == other.currency
    @amount <=> other.amount
  end
end

price = Money.new(amount: 19.99, currency: "USD")
tax = Money.new(amount: 2.00, currency: "USD")
total = price + tax
```

---

## Checklist

- [ ] Classes not hashes for domain entities
- [ ] Keyword arguments everywhere
- [ ] UUID as first line in constructor
- [ ] Strongly typed language for argument validation
- [ ] Use `.fetch()` for hash access
- [ ] Single responsibility per class
- [ ] Composition over inheritance
- [ ] `attr_reader` with type signatures

---

## Summary

**Key Principles:**

1. **Classes with keywords** - Never hashes or positional arguments
2. **UUID first** - Every constructor starts with `UUID.generate`
3. **Validate strict** - Type check in constructors, fail fast
4. **Fail loud** - Use `.fetch()`, no silent nils or conditional safety
5. **Single responsibility** - One purpose per class
6. **Composition** - Avoid deep inheritance

**Benefits:**

- Type safety prevents typos and errors
- Early validation catches bugs at source
- Small classes easier to test and maintain
- Clear responsibilities improve understanding
- Keyword arguments prevent order mistakes

