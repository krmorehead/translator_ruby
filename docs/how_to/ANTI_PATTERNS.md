---
description: Comprehensive anti-pattern reference for code review
globs: ""
alwaysApply: false
---

# Anti-Pattern Reference

**Purpose**: Code review checklist - identify problematic patterns quickly  
**Usage**: Use during code review to catch common mistakes

---

## Backend Anti-Patterns

### Object-Oriented Programming

❌ **Plain Objects Instead of Classes**
```ruby
# Bad: Plain hash with typo risk
execution = { id: uuid, status: "pending" }
execution[:statu] = "complete"  # Typo not caught!
```

❌ **Positional Arguments**
```ruby
# Bad: Unclear what parameters mean
def create(goal, priority, metadata)
service.create("Goal", 1, {})  # What's the order?
```

❌ **Hash-Based State**
```ruby
# Bad: No type safety, no methods
def initialize(data)
  @state = data  # Hash, not class
end
```

❌ **No Validation or Late Validation**
```ruby
# Bad: No validation in constructor
def initialize(text:)
  @text = text  # Could be nil, could be empty
end
```

❌ **Over-Validation**
```ruby
# Bad: Too defensive, masks issues
raise ArgumentError if text.strip.empty?  # Too specific
raise ArgumentError unless (1..3).include?(priority)  # Over-defensive
```

---

### Validation

❌ **Fallback Defaults**
```ruby
# Bad: Silent fallbacks mask missing data
def initialize(name: nil, age: nil)
  @name = name || "Unknown"  # Masks missing name
  @age = age || 0
end
```

❌ **Swallowing Errors**
```ruby
# Bad: Rescue blocks hide real issues
def process(entity:)
  entity.perform_action
rescue StandardError => e
  {success: false}  # Swallows error!
end
```

❌ **Silent Hash Access**
```ruby
# Bad: Returns nil if missing
config = json["config"]  # nil if missing
value = config["key"]  # NoMethodError on nil!
```

❌ **Safety Conditionals**
```ruby
# Bad: Masks unexpected state
if browser_tool.browser
  browser_tool.browser.quit
end
```

---

### Service Objects

❌ **Default Dependencies**
```ruby
# Bad: Defaults mask missing dependencies
def initialize(store: nil, broadcaster: nil)
  @store = store || StateStore.new  # Silent fallback!
end
```

❌ **Splat Operators**
```ruby
# Bad: Unclear what's valid
def create_entity(**params)
  # What parameters are valid? Unknown!
end

def configure(options: {})
  @timeout = options[:timeout] || 30  # What options exist?
end
```

---

### Serialization

❌ **Serialization on Models**
```ruby
# Bad: Model has serialization methods
class Execution
  def as_json
    { id: @id, status: @status }  # Wrong layer!
  end
end
```

❌ **Positional Serializer Calls**
```ruby
# Bad: Not self-documenting
ExecutionSerializer.show(execution)  # What is this parameter?
```

❌ **Direct Instance Variable Access**
```ruby
# Bad: Breaks encapsulation
def show(execution:)
  { id: execution.instance_variable_get(:@id) }  # Bad!
end
```

---

### Testing

❌ **Testing Internals**
```ruby
# Bad: Testing private state
expect(service.instance_variable_get(:@internal_flag)).to be true
```

❌ **Using Mocks**
```ruby
# Bad: Mocks drift from reality
mock_store = double('StateStore')
allow(mock_store).to receive(:save)
```

❌ **Explicit Timeouts**
```ruby
# Bad: Arbitrary waits
sleep(5)  # What are we waiting for?
Timeout.timeout(10) { service.execute }  # Flaky!
```

❌ **Direct Test Commands**
```ruby
# Bad: Bypasses script safeguards
bundle exec rspec  # Should use bin/test
```

---

### Scripts

❌ **No Error Handling**
```bash
# Bad: No set -e, no cleanup trap
#!/usr/bin/env bash
rails server &
# Server left running on error!
```

❌ **Arbitrary Sleeps**
```bash
# Bad: Arbitrary wait
rails server &
sleep 5  # Is server ready? Unknown!
```

---

## Frontend Anti-Patterns

### Object-Oriented Programming

❌ **Plain Objects**
```typescript
// Bad: No type safety, no methods
const execution = {
  id: crypto.randomUUID(),
  status: 'pending'
};
execution.statu = 'complete';  // Typo not caught!
```

❌ **Positional Parameters**
```typescript
// Bad: Order-dependent, not clear
constructor(store: StateStore, broadcaster: Broadcaster) {
  // What's the order?
}
```

❌ **Public Fields**
```typescript
// Bad: No encapsulation
class Execution {
  id: string;  // Public, can be changed
  status: string;
}
```

❌ **No Validation**
```typescript
// Bad: Accepts invalid input
constructor({ text }: { text: string }) {
  this._text = text;  // Could be empty, no validation
}
```

---

### TypeScript

❌ **Using `any` or `unknown`**
```typescript
// Bad: Loses type safety
function process(data: any) {  // Bad!
  return data.value;
}
```

❌ **No Strict Mode**
```typescript
// Bad: tsconfig.json
{
  "compilerOptions": {
    "strict": false  // Bad!
  }
}
```

❌ **Untyped Props**
```typescript
// Bad: No type safety
function Component(props) {  // Bad!
  return <div>{props.data}</div>;
}
```

---

### Components

❌ **God Components**
```typescript
// Bad: Does everything (20+ state vars, 200+ lines)
function UnifiedIDE() {
  const [state1, setState1] = useState();
  const [state2, setState2] = useState();
  // ... 18 more state variables
  // ... 200+ lines of rendering
}
```

❌ **Mixed Concerns**
```typescript
// Bad: Logic and rendering mixed
function FileList() {
  const [files, setFiles] = useState([]);
  useEffect(() => {
    fetch('/api/files').then(r => r.json()).then(setFiles);
  }, []);
  return <div>{files.map(...)}</div>;  // Should be split!
}
```

---

### State Management

❌ **State Mutation**
```typescript
// Bad: Direct mutation
state.items.push(newItem);  // Mutates state directly!
```

❌ **Global UI State**
```typescript
// Bad: UI state in global store
const useStore = create((set) => ({
  dropdownOpen: false,  // Should be local!
  modalVisible: false   // Should be local!
}));
```

---

### Testing

❌ **Explicit Timeouts**
```typescript
// Bad: Arbitrary waits
await expect(page.locator('.result')).toBeVisible({ timeout: 30000 })
await page.waitForTimeout(5000)  // What are we waiting for?
```

❌ **Direct Test Commands**
```bash
# Bad: Bypasses script safeguards
npm run test:e2e  # Should use bin/e2e
npx playwright test  # Should use bin/e2e
```

❌ **Network Idle Waits**
```typescript
// Bad: Wastes time
await page.waitForLoadState('networkidle')
```

---

## Universal Anti-Patterns

### Parameter Patterns

❌ **Splat Operators**
```ruby
def method(**params)  # Bad: Unclear what's valid
def method(**options)  # Bad: Unclear what's valid
```

❌ **Empty Hash Defaults**
```ruby
def method(options: {})  # Bad: Should use options class
```

❌ **Positional Arguments**
```ruby
def method(arg1, arg2, arg3)  # Bad: Order-dependent
service.method(val1, val2, val3)  # Bad: Unclear
```

---

### Type Safety

❌ **Untyped Code**
```ruby
# Bad: No Sorbet types
def process(data)  # What type is data?
  data.value
end
```

```typescript
// Bad: Using any
function process(data: any) {  # Bad!
  return data.value;
}
```

❌ **Symbol Access**
```ruby
# Bad: Symbol access for params
params[:id]  # Should use string access
params.to_h.symbolize_keys  # Anti-pattern
```

---

### Testing

❌ **Timeouts and Sleeps**
```ruby
sleep(5)  # Bad: Arbitrary wait
Timeout.timeout(10) { }  # Bad: Flaky
```

```typescript
await page.waitForTimeout(5000)  # Bad: Arbitrary
setTimeout(() => {}, 3000)  # Bad: In tests
```

❌ **Mocking Internal Code**
```ruby
mock_store = double('Store')  # Bad: Use real instances
allow(service).to receive(:internal_method)  # Bad: Testing internals
```

❌ **Testing Implementation**
```ruby
expect(service.instance_variable_get(:@flag)).to be true  # Bad!
expect(service.send(:private_method, 'test')).to eq('result')  # Bad!
```

---

## Code Review Checklist

### OOP Review
- [ ] No plain objects (hashes in Ruby, plain objects in TypeScript)
- [ ] No positional arguments (all keyword/named parameters)
- [ ] Validation in constructors (type checks only)
- [ ] No fallback defaults (|| operators)
- [ ] Classes have single responsibility

### Type Safety Review
- [ ] No `T.untyped` in Sorbet
- [ ] No `any` or `unknown` in TypeScript
- [ ] All method signatures have types
- [ ] All parameters explicitly typed

### Validation Review
- [ ] Use `.fetch()` for hash access (not `[]`)
- [ ] No rescue blocks that swallow errors
- [ ] No safety conditionals (`if obj`)
- [ ] Type validation only, no over-validation

### Service Review
- [ ] No default dependencies in constructors
- [ ] No `**params` or `**options` in methods
- [ ] Controllers delegate to services
- [ ] Services use explicit parameters

### Serialization Review
- [ ] No serialization methods on models
- [ ] Serializers use `show(instance:)` and `index(collection:)`
- [ ] Serializers use keyword arguments
- [ ] Serializers read via getters only

### Testing Review
- [ ] No `sleep()` or `Timeout.timeout()`
- [ ] No mocks (use real instances)
- [ ] Tests use `bin/test` or `bin/e2e` scripts
- [ ] No testing internal state
- [ ] Wait for conditions, not timeouts

### Component Review
- [ ] Components < 100 lines
- [ ] Single responsibility per component
- [ ] Container/presentational separation
- [ ] Props down, events up

### State Review
- [ ] No direct state mutation
- [ ] Global state for application data only
- [ ] Local state for UI-only concerns
- [ ] Immutable updates with immer

---

## Priority Violations

### Critical (Fix Immediately):
1. Untyped code (`any`, `T.untyped`)
2. State mutation
3. Error swallowing (rescue blocks)
4. Testing with mocks
5. Direct test commands (not using scripts)

### High Priority:
6. Positional arguments
7. Plain objects instead of classes
8. No validation in constructors
9. Serialization on models
10. Timeout usage in tests

### Medium Priority:
11. Safety conditionals
12. Default dependencies
13. Splat operators
14. God components
15. Mixed concerns

---

**Use this file during every code review to catch anti-patterns early.**


