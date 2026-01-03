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

## Real-World Learnings: E2E Testing with Strict OOP (January 2026)

### Context
Implemented comprehensive E2E tests for Sisyphus approval flow with real LLM integration while maintaining strict OOP compliance globally across frontend and backend.

### Key Learnings

#### 1. Frontend Models Must Mirror Backend Exactly

**Pattern:**
```javascript
// Backend (Ruby)
class Execution::ApprovalRequest
  def pending?
    @status == STATUS_PENDING
  end
  
  def approve(resolved_by:)
    self.class.new(...)  # Returns new instance
  end
end

// Frontend (JavaScript) - EXACT MIRROR
export class ApprovalRequest {
  isPending() {
    return this.status === ApprovalRequest.STATUS_PENDING;
  }
  
  approve(resolvedBy) {
    return new ApprovalRequest({ ... });  // Returns new instance
  }
}
```

**Result:** Perfect symmetry enables seamless TypeScript migration and reduces cognitive load.

#### 2. Inheritance Hierarchies Are Essential

Created `BaseRequest` class for common request functionality:

```javascript
export class BaseRequest {
  static STATUS_PENDING = "pending";
  static STATUS_COMPLETE = "complete";
  
  constructor({ id, status, createdAt }) {
    if (new.target === BaseRequest) {
      throw new Error("BaseRequest is abstract");
    }
    this.validateBaseParams(id, status, createdAt);
    // ...
    Object.freeze(this);
  }
  
  // Abstract methods that subclasses MUST implement
  isPending() {
    throw new Error(`${this.constructor.name} must implement isPending()`);
  }
  
  toJSON() {
    throw new Error(`${this.constructor.name} must implement toJSON()`);
  }
}

export class ApprovalRequest extends BaseRequest {
  constructor(params) {
    super(params);
    // ApprovalRequest-specific properties
  }
  
  // Must implement abstract methods
  isPending() {
    return this.status === ApprovalRequest.STATUS_PENDING;
  }
  
  toJSON() {
    return { /* ... */ };
  }
}
```

**Benefits:**
- All future request types inherit consistent interface
- Prevents duplication of validation logic
- Enforces contract at runtime
- Ready for TypeScript with minimal changes

#### 3. Factory Pattern in Tests (Both Layers)

```ruby
# Backend (Ruby)
approval = FactoryBot.build(:approval_request, :step, :with_planned_actions)
```

```javascript
// Frontend (JavaScript) - SAME PATTERN
const approval = ApprovalRequestFactory.buildStep({ 
  plannedActions: [...]
});
```

**Result:** Tests read identically across languages. Developers can context-switch seamlessly.

#### 4. No Hash Support, Ever

**Wrong (Initial Attempt):**
```javascript
// E2E tests initially tried this
const data = { 
  execution_id: "123", 
  type: "step",
  subject_title: "Test" 
};
await testService.inject(data);  // BAD: Raw object
```

**Correct (After Refactoring):**
```javascript
const approval = ApprovalRequestFactory.buildStep({
  executionId: "123",
  subjectTitle: "Test"
});
await realExecutionFlow.start(approval);  // GOOD: Real domain object
```

**What We Removed:**
- All "hash-friendly" fallback code
- Optional parameter handling (`params.type || params.approval_type`)
- Environment-specific controller behavior
- Test-only endpoints that accepted raw JSON

**Result:** Fail-fast validation caught all integration issues immediately.

#### 5. Abstract Base Classes Enforce Contracts

```javascript
class BaseRequest {
  constructor() {
    if (new.target === BaseRequest) {
      throw new Error("BaseRequest is abstract and cannot be instantiated");
    }
  }
  
  // Abstract method - subclasses MUST implement
  toJSON() {
    throw new Error(`${this.constructor.name} must implement toJSON()`);
  }
  
  static fromJSON(json) {
    throw new Error(`${this.name} must implement static fromJSON()`);
  }
}
```

**Caught at Test Time:**
```javascript
// This fails immediately
const base = new BaseRequest({ ... });
// Error: BaseRequest is abstract and cannot be instantiated

// This fails when method is called
class BadRequest extends BaseRequest {
  // Forgot to implement toJSON()
}
const bad = new BadRequest({ ... });
bad.toJSON();  // Error: BadRequest must implement toJSON()
```

**Result:** Subclasses MUST implement required methods. Failures are immediate and loud.

#### 6. Immutability with Object.freeze()

```javascript
class ApprovalRequest {
  constructor(params) {
    this._id = params.id;
    this._status = params.status;
    // ... more properties
    
    Object.freeze(this);  // Make immutable
  }
  
  // Getters provide read-only access
  get id() { return this._id; }
  get status() { return this._status; }
  
  // Transformations return NEW instances
  approve(resolvedBy) {
    return new ApprovalRequest({
      ...this.toJSON(),
      status: ApprovalRequest.STATUS_APPROVED,
      resolvedBy,
      resolvedAt: new Date().toISOString()
    });
  }
}
```

**Prevents Accidental Mutations:**
```javascript
const approval = ApprovalRequestFactory.buildPending();
approval._status = 'approved';  // TypeError: Cannot assign to read only property
approval.status = 'approved';   // TypeError: Cannot set property (no setter)

// MUST use transformation methods
const approved = approval.approve('user@example.com');  // Returns NEW instance
```

**Result:** Impossible to accidentally mutate objects. All transformations are explicit and return new instances.

#### 7. Validation in Constructors (Fail Fast)

```javascript
constructor({ id, status, type, executionId, subjectTitle }) {
  // Validate ALL parameters immediately
  if (!id || typeof id !== 'string') {
    throw new Error(`Invalid id: ${id}`);
  }
  
  if (!['step', 'milestone'].includes(type)) {
    throw new Error(`Invalid type: ${type}. Must be 'step' or 'milestone'`);
  }
  
  if (!executionId || typeof executionId !== 'string') {
    throw new Error(`Invalid executionId: ${executionId}`);
  }
  
  if (!subjectTitle || typeof subjectTitle !== 'string') {
    throw new Error(`Invalid subjectTitle: ${subjectTitle}`);
  }
  
  // ... more validation
  
  // Only assign AFTER validation passes
  this._id = id;
  this._status = status;
  // ...
}
```

**Result:** Invalid objects can never exist. Tests fail loudly at construction time, not during execution.

### Anti-Patterns We Eliminated

#### ❌ Hash/Object Literals in Tests

**Wrong:**
```javascript
const data = { execution_id: "123", type: "step" };
await api.inject(data);
```

**Correct:**
```javascript
const approval = ApprovalRequestFactory.buildStep({ executionId: "123" });
await realExecutionFlow.start(approval);
```

#### ❌ Optional Fallbacks

**Wrong:**
```javascript
const type = params.type || params.approval_type || 'step';
const status = params.status || 'pending';
```

**Correct:**
```javascript
if (!params.type) {
  throw new Error('type is required');
}
if (!params.status) {
  throw new Error('status is required');
}
```

#### ❌ Environment-Specific Behavior

**Wrong:**
```ruby
def inject_test_approval
  return head :not_found unless Rails.env.test? || Rails.env.development?
  # test-only logic
end
```

**Correct:**
```ruby
# NO test-only endpoints
# Controllers work identically in all environments
def create
  # Same behavior in test, dev, prod
end
```

### Performance Impact of Strict OOP

**Fast Tests (17 tests, 1.9s)**:
- Pure OOP objects (construction, validation, transformation)
- **NO performance penalty** from strict typing
- Actually **faster** due to early validation catching issues

**Slow Tests (4 tests, < 120s each)**:
- Real LLM integration with full OOP models
- Domain objects serialized to/from JSON for API calls
- **NO performance issues**
- Cleanup is **easier** with well-defined object lifecycles

### TypeScript Migration Readiness

Our strict OOP patterns mean TypeScript migration will be straightforward:

**Current JavaScript:**
```javascript
class ApprovalRequest {
  constructor({ id, status, type }) {
    this._id = id;
    this._status = status;
    this._type = type;
  }
  
  get id() { return this._id; }
}
```

**Future TypeScript (minimal changes):**
```typescript
interface ApprovalRequestParams {
  id: string;
  status: 'pending' | 'approved' | 'rejected';
  type: 'step' | 'milestone';
}

class ApprovalRequest {
  private readonly _id: string;
  private readonly _status: string;
  private readonly _type: string;
  
  constructor({ id, status, type }: ApprovalRequestParams) {
    this._id = id;
    this._status = status;
    this._type = type;
  }
  
  get id(): string { return this._id; }
}
```

**All validation already exists. We just add type annotations!**

### Bottom Line: The ROI of Strict OOP

**Effort Required:**
- Refactored E2E tests to use real domain objects
- Created `BaseRequest` and `ApprovalRequest` classes
- Created `ApprovalRequestFactory` (JavaScript)
- Removed all test-only endpoints
- Removed all optional fallbacks

**Results Achieved:**
- ✅ **Zero hash-related bugs** in E2E tests
- ✅ **Perfect symmetry** between frontend and backend
- ✅ **21 E2E tests passing** with real LLM
- ✅ **Easy TypeScript migration** path
- ✅ **Tests fail fast and loudly**
- ✅ **No special test-only code** paths
- ✅ **1.9s fast test suite**, < 120s per slow test
- ✅ **No performance penalty** from strict OOP

**The effort to maintain strict OOP globally paid massive dividends in test reliability, maintainability, and developer confidence.**

### Key Takeaway

**OOP principles apply GLOBALLY:**
- ✅ Backend domain models
- ✅ Frontend domain models
- ✅ Test factories (both layers)
- ✅ E2E tests (use real objects)
- ✅ API serialization
- ✅ Controller logic

**No exceptions. No fallbacks. No "just for tests" code.**

**When in doubt, ask: "Would this pass code review in a strict OOP language like Java or C#?"**

---
