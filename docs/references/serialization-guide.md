# Serialization Guide: to_h and from_h Patterns

## Overview

This guide establishes patterns for serializing and deserializing objects in the translator_ruby codebase. All serialization uses **symbol keys only** and enforces **strict type checking** with **no legacy format support**.

## Core Principles

1. **Symbol keys only** - No string keys, no fallbacks
2. **Fail fast** - Validate structure immediately
3. **Graceful chaining** - Use `**super` to inherit parent serialization
4. **Type safety** - Reconstruct proper objects, not hashes
5. **No legacy support** - Only accept hashes from `to_h`

## Basic Pattern

### to_h - Serialization

Every class implements `to_h` that returns a hash with symbol keys:

```ruby
class BaseGoal
  def to_h
    {
      id: @id,
      goal_text: @goal_text,
      status: @status,
      entries: @entries,
      progress: @progress,
      created_at: @created_at,
      updated_at: @updated_at,
      metadata: @metadata
    }
  end
end
```

**Rules:**
- Return a Hash with symbol keys
- Include ALL state needed for reconstruction
- Convert nested objects to hashes (call `.to_h` on them)
- Keep it flat when possible
- No computation - just state serialization

### from_h - Deserialization

Class method that reconstructs the object:

```ruby
class BaseGoal
  def self.from_h(hash)
    # 1. Validate hash structure
    raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
    raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
    raise ArgumentError, "Missing required keys" unless 
      hash.key?(:id) && hash.key?(:goal_text) && hash.key?(:status)

    # 2. Reconstruct object without calling initialize
    goal = allocate
    
    # 3. Restore instance variables
    goal.instance_variable_set(:@id, hash[:id])
    goal.instance_variable_set(:@goal_text, hash[:goal_text])
    goal.instance_variable_set(:@status, hash[:status])
    goal.instance_variable_set(:@entries, hash[:entries])
    goal.instance_variable_set(:@progress, hash[:progress] || 0)
    goal.instance_variable_set(:@created_at, hash[:created_at])
    goal.instance_variable_set(:@updated_at, hash[:updated_at])
    goal.instance_variable_set(:@metadata, hash[:metadata] || {})
    
    # 4. Return reconstructed object
    goal
  end
end
```

**Rules:**
- Validate hash structure FIRST
- Use `allocate` to bypass initialize
- Set instance variables directly
- Reconstruct nested objects (call `.from_h` on them)
- No defaults or fallbacks for missing keys

## Inheritance Pattern

### Chaining with `**super`

Subclasses extend parent serialization gracefully:

```ruby
class PrimaryGoal < BaseGoal
  def to_h
    {
      **super,  # Spread all parent properties
      sub_goals: @sub_goals.map(&:to_h)  # Add subclass properties
    }
  end
end
```

This produces:

```ruby
{
  id: "...",
  goal_text: "...",
  status: :in_progress,
  # ... all BaseGoal properties ...
  sub_goals: [
    { id: "...", goal_text: "...", ... },
    { id: "...", goal_text: "...", ... }
  ]
}
```

### Reconstruction with Inheritance

```ruby
class PrimaryGoal < BaseGoal
  def self.from_h(hash)
    # 1. Validate subclass requirements
    raise ArgumentError, "Missing required key :sub_goals" unless hash.key?(:sub_goals)
    raise TypeError, "sub_goals must be an Array" unless hash[:sub_goals].is_a?(Array)

    # 2. Reconstruct base state
    primary_goal = allocate
    primary_goal.instance_variable_set(:@id, hash[:id])
    primary_goal.instance_variable_set(:@goal_text, hash[:goal_text])
    primary_goal.instance_variable_set(:@status, hash[:status])
    primary_goal.instance_variable_set(:@entries, hash[:entries])
    primary_goal.instance_variable_set(:@progress, hash[:progress] || 0)
    primary_goal.instance_variable_set(:@created_at, hash[:created_at])
    primary_goal.instance_variable_set(:@updated_at, hash[:updated_at])
    primary_goal.instance_variable_set(:@metadata, hash[:metadata] || {})

    # 3. Reconstruct subclass state
    sub_goals = hash[:sub_goals].map { |sg_hash| SubGoal.from_h(sg_hash, parent: primary_goal) }
    sub_goal_map = sub_goals.each_with_object({}) { |sg, map| map[sg.id] = sg }
    
    primary_goal.instance_variable_set(:@sub_goals, sub_goals)
    primary_goal.instance_variable_set(:@sub_goal_map, sub_goal_map)

    # 4. Return fully reconstructed object
    primary_goal
  end
end
```

## Validation Patterns

### Standard Validation

Every `from_h` starts with this:

```ruby
def self.from_h(hash)
  # Type check
  raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
  
  # Key type check
  raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
  
  # Required keys check
  raise ArgumentError, "Missing required keys: #{missing_keys(hash)}" unless has_required_keys?(hash)
  
  # Proceed with reconstruction...
end

private

def self.required_keys
  [:id, :goal_text, :status, :entries]
end

def self.has_required_keys?(hash)
  required_keys.all? { |key| hash.key?(key) }
end

def self.missing_keys(hash)
  required_keys.reject { |key| hash.key?(key) }.join(", ")
end
```

### Nested Object Validation

When deserializing nested objects:

```ruby
def self.from_h(hash)
  validate_hash_structure!(hash)
  
  # Validate nested structure
  raise TypeError, "sub_goals must be an Array" unless hash[:sub_goals].is_a?(Array)
  raise TypeError, "each sub_goal must be a Hash" unless hash[:sub_goals].all? { |sg| sg.is_a?(Hash) }
  
  # Reconstruct nested objects
  sub_goals = hash[:sub_goals].map { |sg_hash| SubGoal.from_h(sg_hash, parent: self) }
  
  # ...
end
```

## Context Serialization

Contexts serialize their entries as objects:

```ruby
class GoalContext < BaseContext
  def to_h
    super.merge(
      primary_goal: @primary_goal.to_h,  # Call to_h on nested object
      overall_progress: overall_progress
    )
  end

  def self.from_h(hash)
    raise TypeError, "Expected Hash, got #{hash.class}" unless hash.is_a?(Hash)
    raise ArgumentError, "Hash keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
    raise ArgumentError, "Missing required key :primary_goal" unless hash.key?(:primary_goal)
    raise TypeError, "primary_goal must be a Hash" unless hash[:primary_goal].is_a?(Hash)

    # Reconstruct nested object
    primary_goal = Goals::PrimaryGoal.from_h(hash[:primary_goal])
    
    # Allocate and restore state
    context = allocate
    context.instance_variable_set(:@primary_goal, primary_goal)
    context.instance_variable_set(:@entries, [])
    context.instance_variable_set(:@topic_index, Hash.new { |h, k| h[k] = Set.new })
    context.instance_variable_set(:@sub_contexts, {})

    # Restore entries as Entry objects
    load_entries_from_h(context, hash)
    load_sub_contexts_from_h(context, hash)

    context
  end
end
```

## Helper Methods Pattern

Common helper for loading collections:

```ruby
class BaseContext
  def self.load_entries_from_h(context, data)
    raise TypeError, "data must be a Hash" unless data.is_a?(Hash)
    raise ArgumentError, "data must contain :entries key" unless data.key?(:entries)
    raise TypeError, "entries must be an Array" unless data[:entries].is_a?(Array)

    entries_data = data[:entries]
    entries_data.each do |entry_data|
      raise TypeError, "each entry must be a Hash" unless entry_data.is_a?(Hash)
      
      # Reconstruct Entry object, not hash
      entry = Entries::BaseEntry.from_h(entry_data)
      context.instance_variable_get(:@entries) << entry
      
      # Rebuild indexes
      entry.topics.each do |topic|
        context.instance_variable_get(:@topic_index)[topic].add(entry.id)
      end
    end
  end
end
```

## Collections

### Arrays of Objects

```ruby
def to_h
  {
    **super,
    sub_goals: @sub_goals.map(&:to_h),  # Map each to hash
    actions: @actions.map(&:to_h)
  }
end

def self.from_h(hash)
  # Validate
  raise TypeError, "sub_goals must be an Array" unless hash[:sub_goals].is_a?(Array)
  
  # Reconstruct each object
  sub_goals = hash[:sub_goals].map { |sg| SubGoal.from_h(sg, parent: parent) }
  
  # ...
end
```

### Hashes of Objects

```ruby
def to_h
  {
    **super,
    sub_contexts: @sub_contexts.transform_values(&:to_h)  # Transform values to hashes
  }
end

def self.from_h(hash)
  # Validate
  raise TypeError, "sub_contexts must be a Hash" unless hash[:sub_contexts].is_a?(Hash)
  
  # Reconstruct each value
  sub_contexts = hash[:sub_contexts].transform_values { |ctx_hash|
    class_name = ctx_hash[:context_class]
    klass = class_name.constantize
    klass.from_h(ctx_hash)
  }
  
  # ...
end
```

## Special Cases

### Circular References

When objects reference each other (like SubGoal -> Parent):

```ruby
class SubGoal
  def to_h
    {
      **super,
      priority: @priority,
      parent_id: @parent.id  # Store ID, not full parent
    }
  end

  def self.from_h(hash, parent:)  # Accept parent as parameter
    raise TypeError, "parent must be a PrimaryGoal" unless parent.is_a?(PrimaryGoal)
    
    sub_goal = allocate
    # ... restore state ...
    sub_goal.instance_variable_set(:@parent, parent)  # Reconnect reference
    sub_goal
  end
end
```

### Polymorphic Deserialization

When you need to deserialize to different types:

```ruby
def self.from_h(hash)
  validate_hash_structure!(hash)
  
  # Determine type from metadata
  case hash[:type]
  when :research
    ResearchEntry.from_h(hash)
  when :scene
    SceneEntry.from_h(hash)
  else
    BaseEntry.from_h(hash)
  end
end
```

Or store class name:

```ruby
def to_h
  {
    class_name: self.class.name,
    **super
  }
end

def self.from_h(hash)
  klass = hash[:class_name].constantize
  klass.from_h(hash)
end
```

## Testing Serialization

### Round-Trip Test Pattern

Every class should have this test:

```ruby
test "serializes and deserializes correctly" do
  # 1. Create complex object
  original = Goals::PrimaryGoal.new(goal_text: "Test", entry_id: "e1")
  original.add_sub_goal(goal_text: "Sub 1", entry_id: "e2", priority: 1)
  original.add_sub_goal(goal_text: "Sub 2", entry_id: "e3", priority: 2)
  original.update_status(status: Goals::BaseGoal::IN_PROGRESS, entry_id: "e4")

  # 2. Serialize
  hash = original.to_h

  # 3. Deserialize
  reconstructed = Goals::PrimaryGoal.from_h(hash)

  # 4. Verify state matches
  assert_equal original.id, reconstructed.id
  assert_equal original.goal_text, reconstructed.goal_text
  assert_equal original.status, reconstructed.status
  assert_equal original.entries, reconstructed.entries
  assert_equal 2, reconstructed.sub_goals.size
  
  # 5. Verify nested objects
  assert_equal original.sub_goals[0].id, reconstructed.sub_goals[0].id
  assert_equal original.sub_goals[0].priority, reconstructed.sub_goals[0].priority
end
```

### Validation Test Pattern

```ruby
test "from_h validates hash structure" do
  # Test type validation
  error = assert_raises(TypeError) do
    Goals::BaseGoal.from_h("not a hash")
  end
  assert_match(/Expected Hash/, error.message)

  # Test key type validation
  error = assert_raises(ArgumentError) do
    Goals::BaseGoal.from_h({ "id" => "123", "goal_text" => "test" })
  end
  assert_match(/Hash keys must be symbols/, error.message)

  # Test required keys
  error = assert_raises(ArgumentError) do
    Goals::BaseGoal.from_h({ id: "123" })  # Missing goal_text
  end
  assert_match(/Missing required keys/, error.message)
end
```

## Common Pitfalls

### ❌ DON'T: Use string keys

```ruby
# ❌ BAD
def to_h
  {
    "id" => @id,
    "goal_text" => @goal_text
  }
end
```

### ❌ DON'T: Support legacy formats

```ruby
# ❌ BAD - No fallbacks!
def self.from_h(hash)
  id = hash[:id] || hash["id"]  # NO!
  goal_text = hash[:goal_text] || hash["goal_text"] || "default"  # NO!
end
```

### ❌ DON'T: Call initialize from from_h

```ruby
# ❌ BAD - Bypass validation in from_h
def self.from_h(hash)
  new(
    goal_text: hash[:goal_text],
    entry_id: hash[:entries].first  # Will run initialization validation
  )
end

# ✅ GOOD - Use allocate
def self.from_h(hash)
  goal = allocate
  goal.instance_variable_set(:@goal_text, hash[:goal_text])
  goal
end
```

### ❌ DON'T: Forget to reconstruct nested objects

```ruby
# ❌ BAD - Leaves hashes instead of objects
def self.from_h(hash)
  context = allocate
  context.instance_variable_set(:@sub_goals, hash[:sub_goals])  # Still hashes!
  context
end

# ✅ GOOD - Reconstruct as objects
def self.from_h(hash)
  context = allocate
  sub_goals = hash[:sub_goals].map { |sg| SubGoal.from_h(sg, parent: context) }
  context.instance_variable_set(:@sub_goals, sub_goals)
  context
end
```

## Quick Reference

### Template: Basic Class

```ruby
class MyClass
  attr_reader :id, :name, :status

  def initialize(name:, status:)
    validate!(name, status)
    @id = SecureRandom.uuid
    @name = name
    @status = status
  end

  def to_h
    {
      id: @id,
      name: @name,
      status: @status
    }
  end

  def self.from_h(hash)
    validate_hash!(hash)
    
    obj = allocate
    obj.instance_variable_set(:@id, hash[:id])
    obj.instance_variable_set(:@name, hash[:name])
    obj.instance_variable_set(:@status, hash[:status])
    obj
  end

  private

  def validate!(name, status)
    raise ArgumentError, "name must be a String" unless name.is_a?(String)
    raise ArgumentError, "status must be a Symbol" unless status.is_a?(Symbol)
  end

  def self.validate_hash!(hash)
    raise TypeError, "Expected Hash" unless hash.is_a?(Hash)
    raise ArgumentError, "Keys must be symbols" if hash.keys.any? { |k| !k.is_a?(Symbol) }
    raise ArgumentError, "Missing keys" unless hash.key?(:id) && hash.key?(:name) && hash.key?(:status)
  end
end
```

### Template: Inherited Class

```ruby
class MySubclass < MyClass
  attr_reader :extra_data

  def initialize(name:, status:, extra_data:)
    super(name: name, status: status)
    @extra_data = extra_data
  end

  def to_h
    {
      **super,  # Chain parent
      extra_data: @extra_data
    }
  end

  def self.from_h(hash)
    validate_hash!(hash)
    
    # Restore parent state
    obj = allocate
    obj.instance_variable_set(:@id, hash[:id])
    obj.instance_variable_set(:@name, hash[:name])
    obj.instance_variable_set(:@status, hash[:status])
    
    # Restore subclass state
    obj.instance_variable_set(:@extra_data, hash[:extra_data])
    obj
  end
end
```

## Common Refactoring Issues

### Issue 1: Parameter Name Mismatches

When refactoring, ensure serialization uses the same parameter names as the class:

```ruby
# ❌ BAD - Mismatch causes errors
class StateTransition
  def initialize(from:, to:, event:)  # Uses 'from' and 'to'
    @from_state = from
    @to_state = to
  end
  
  def to_h
    { from_state: @from_state, to_state: @to_state }  # Wrong keys!
  end
end
```

```ruby
# ✅ GOOD - Consistent keys
class StateTransition
  def initialize(from:, to:, event:)
    @from_state = from
    @to_state = to
  end
  
  def to_h
    { from: @from_state, to: @to_state }  # Matches initialize params
  end
  
  def self.from_h(hash)
    # Use allocate to avoid calling initialize
    transition = allocate
    transition.instance_variable_set(:@from_state, hash[:from])  # Correct key
    transition.instance_variable_set(:@to_state, hash[:to])
    transition
  end
end
```

### Issue 2: Collections in Parent Classes

When a parent class has collections, ensure they're initialized in from_h:

```ruby
class WorkflowContext < BaseContext
  attr_reader :transitions, :decisions
  
  def initialize
    super  # BaseContext initializes @entries, @sub_contexts
    @transitions = []
    @decisions = []
  end
  
  def self.from_h(hash)
    context = allocate
    
    # Initialize parent state
    context.instance_variable_set(:@entries, [])
    context.instance_variable_set(:@sub_contexts, {})
    
    # Initialize subclass collections - DON'T FORGET THESE!
    context.instance_variable_set(:@transitions, [])
    context.instance_variable_set(:@decisions, [])
    
    # Then reconstruct objects
    transitions = (hash[:transitions] || []).map { |t| StateTransition.from_h(t) }
    context.instance_variable_set(:@transitions, transitions)
    
    context
  end
end
```

### Issue 3: Forgetting to Serialize Collections

When adding new collections, remember to include them in to_h:

```ruby
# ❌ BAD - Forgot to serialize transitions
def to_h
  super.merge(
    workflow_name: @workflow_name,
    current_state: @current_state
    # Missing: transitions!
  )
end

# ✅ GOOD - All collections serialized
def to_h
  super.merge(
    workflow_name: @workflow_name,
    current_state: @current_state,
    transitions: @transitions.map(&:to_h),  # Don't forget!
    decisions: @decisions.map(&:to_h),
    errors: @errors.map(&:to_h)
  )
end
```

## Summary

1. **Use symbol keys only** in to_h
2. **Validate everything** in from_h
3. **Use `**super`** to chain parent serialization
4. **Use `allocate`** to bypass initialize
5. **Reconstruct nested objects** with their from_h
6. **Test round-trips** for every serializable class
7. **No legacy support** - fail fast with clear errors
8. **Match parameter names** between initialize and to_h keys
9. **Initialize all collections** in from_h, even empty ones
10. **Serialize all state** including collections of objects

## References

- [OOP Patterns Guide](./oop-patterns.md)
- Ruby `allocate` documentation
- Ruby `instance_variable_set` documentation

