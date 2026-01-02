... (keeping existing content) ...

---

### Lesson 48: Never Use Mocks - Always Use Real Instances

**Problem:** Mock objects in tests hide integration issues, make tests brittle, and don't verify actual behavior of real objects.

**Solution:** Always use real instances of classes in tests. Create factories or helpers to make instantiation easy.

#### ❌ BAD: Using mock objects

```ruby
# ❌ BAD: Mock that pretends to be a MemoryStore
class MockParentMemory
  def initialize(sections = {})
    @sections = sections
  end

  def context_for(workflow_name)
    Contexts::BaseContext.new
  end
end

test "some behavior" do
  parent = MockParentMemory.new  # Not a real MemoryStore!
  workflow = WorkflowMemoryStore.new(..., parent: parent)
  # Test passes but doesn't verify real MemoryStore works
end
```

**Problems:**
- Mock doesn't have same behavior as real class
- Mock won't catch breaking changes to real class
- Mock signatures can drift from real implementations
- Tests pass with mocks but fail with real objects

#### ✅ GOOD: Use real instances with factories

```ruby
# ✅ GOOD: Use factory to create real MemoryStore
test "some behavior" do
  parent = build(:memory_store, base_dir: temp_dir, owner: owner_id)
  workflow = build(:workflow_memory_store, parent: parent)
  # Tests real integration between actual classes
end

# Factory makes it easy
factory :memory_store do
  transient do
    base_dir { Dir.mktmpdir("memory_store_test") }
    owner { SecureRandom.uuid }
  end
  
  initialize_with do
    FileUtils.mkdir_p(File.dirname(path))
    MemoryStore.new(path: path, owner_id: owner_id)
  end
end
```

#### ✅ GOOD: Use helper methods for common setups

```ruby
# test/test_helper.rb
def create_memory_store(owner_id: SecureRandom.uuid, base_dir: Dir.mktmpdir)
  path = File.join(base_dir, owner_id, "memory.json")
  FileUtils.mkdir_p(File.dirname(path))
  MemoryStore.new(path: path, owner_id: owner_id)
end

# In tests
test "something" do
  parent = create_memory_store(owner_id: @owner_id, base_dir: @temp_dir)
  workflow = WorkflowMemoryStore.new(..., parent_id: parent.id)
end
```

**Key Principles:**
1. **Never create mock classes** - Use real instances
2. **Create factories** - Make real objects easy to instantiate  
3. **Use helper methods** - Common setups in test_helper.rb
4. **Test real integrations** - Verify actual classes work together
5. **Fail with real errors** - See actual problems, not mock behavior

**When Mocks Seem Tempting:**
- ❌ "Real object is hard to create" → Create a factory instead
- ❌ "Real object is slow" → Mark test as :medium or :slow
- ❌ "Real object needs dependencies" → Create those too (factories cascade)
- ❌ "Want to verify method calls" → Test outcomes, not calls

**Benefits:**
- **Real integration testing** - Catches actual incompatibilities
- **Refactoring safety** - Real tests fail when contracts break
- **No drift** - Tests always use current implementations
- **Better errors** - See real failures, not mock mismatches

**Apply To:**
- ✅ ALL test classes - zero mocks allowed
- ✅ Create factories for complex objects
- ✅ Use real database, real files, real services
- ✅ Only stub external APIs (Stripe, AWS, etc.)

---
