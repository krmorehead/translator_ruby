# OOP Patterns Guide

## Overview

This guide establishes the object-oriented patterns used throughout the translator_ruby codebase. These patterns prioritize **type safety**, **single responsibility**, and **fail-fast validation** over backward compatibility.

## Core Principles

### 1. No Hash-Based State ❌

**BAD - Hash-based entities:**
```ruby
# ❌ NEVER DO THIS
@goal = {
  id: SecureRandom.uuid,
  text: "Complete task",
  status: :pending,
  progress: 0
}

# ❌ Direct hash manipulation
@goal[:status] = :completed
@goal[:progress] = 100
```

**GOOD - Proper classes:**
```ruby
# ✅ ALWAYS DO THIS
@goal = Goals::PrimaryGoal.new(
  goal_text: "Complete task",
  entry_id: entry.id,
  metadata: {}
)

# ✅ Methods encapsulate behavior
@goal.update_status(status: :complete, entry_id: entry.id, progress: 100)
```

### 2. Strict Type Validation ✓

Every class MUST validate all inputs and raise descriptive errors:

```ruby
def initialize(goal_text:, entry_id:, status: NOT_STARTED, metadata: {})
  raise ArgumentError, "goal_text must be a String" unless goal_text.is_a?(String)
  raise ArgumentError, "entry_id must be a String" unless entry_id.is_a?(String)
  raise ArgumentError, "Invalid status: #{status}" unless STATUSES.include?(status)
  
  @goal_text = goal_text
  @entry_id = entry_id
  # ...
end
```

### 3. Single Responsibility Principle

Each class has ONE clear purpose:

- `BaseGoal` - Core goal behavior (status, progress tracking)
- `PrimaryGoal` - Managing sub-goals and hierarchy
- `SubGoal` - Belonging to a parent with priority
- `GoalContext` - Coordinating goals with context entries

### 4. Composition Over Inheritance

Use composition for "has-a" relationships:

```ruby
class PrimaryGoal < BaseGoal
  def initialize(...)
    super
    @sub_goals = []           # Composition: has many SubGoals
    @sub_goal_map = {}        # Fast lookup
  end
  
  def add_sub_goal(...)
    sub_goal = SubGoal.new(...)
    @sub_goals << sub_goal
    sub_goal
  end
end
```

## Class Hierarchy Patterns

### Base Class Pattern

Every entity type should have a base class:

```ruby
module Contexts
  module Goals
    class BaseGoal
      # Constants at the top
      STATUSES = [
        NOT_STARTED = :not_started,
        IN_PROGRESS = :in_progress,
        COMPLETE = :complete,
        FAILED = :failed
      ].freeze

      # Attribute readers
      attr_reader :id, :goal_text, :status, :entries, :progress

      # Initialization with validation
      def initialize(goal_text:, entry_id:, status: NOT_STARTED, metadata: {})
        validate_types!(goal_text, entry_id, status)
        
        @id = SecureRandom.uuid
        @goal_text = goal_text
        @entries = [entry_id]
        @status = status
        @progress = 0
        @created_at = Time.now.utc.iso8601
        @updated_at = Time.now.utc.iso8601
        @metadata = metadata
      end

      # Public interface methods
      def update_status(status:, entry_id:, progress: nil)
        validate_update!(status, entry_id)
        
        @status = status
        @progress = progress unless progress.nil?
        @entries << entry_id
        @updated_at = Time.now.utc.iso8601
      end

      def completed?
        @status == COMPLETE
      end

      # Serialization (see serialization guide)
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

      def self.from_h(hash)
        validate_hash!(hash)
        reconstruct_from_hash(hash)
      end

      private

      def validate_types!(goal_text, entry_id, status)
        raise ArgumentError, "goal_text must be a String" unless goal_text.is_a?(String)
        raise ArgumentError, "entry_id must be a String" unless entry_id.is_a?(String)
        raise ArgumentError, "Invalid status: #{status}" unless STATUSES.include?(status)
      end

      def validate_update!(status, entry_id)
        raise ArgumentError, "Invalid status: #{status}" unless STATUSES.include?(status)
        raise ArgumentError, "entry_id must be a String" unless entry_id.is_a?(String)
      end
    end
  end
end
```

### Inheritance Pattern

Subclasses extend base functionality:

```ruby
module Contexts
  module Goals
    class PrimaryGoal < BaseGoal
      attr_reader :sub_goals, :sub_goal_map

      def initialize(goal_text:, entry_id:, status: NOT_STARTED, metadata: {})
        # Call parent with explicit parameters
        super(goal_text: goal_text, entry_id: entry_id, status: status, metadata: metadata)
        
        # Initialize subclass-specific state
        @sub_goals = []
        @sub_goal_map = {}
      end

      # Add subclass-specific behavior
      def add_sub_goal(goal_text:, entry_id:, priority: 2, metadata: {})
        validate_sub_goal_params!(goal_text, entry_id, priority)
        
        sub_goal = SubGoal.new(
          goal_text: goal_text,
          entry_id: entry_id,
          parent: self,
          priority: priority,
          metadata: metadata
        )
        
        @sub_goals << sub_goal
        @sub_goal_map[sub_goal.id] = sub_goal
        sub_goal
      end

      # Extend serialization with chaining
      def to_h
        {
          **super,  # Get all parent properties
          sub_goals: @sub_goals.map(&:to_h)  # Add subclass properties
        }
      end

      def self.from_h(hash)
        validate_hash_structure!(hash)
        
        # Reconstruct parent state
        primary_goal = allocate
        restore_base_state!(primary_goal, hash)
        
        # Reconstruct subclass state
        sub_goals = hash[:sub_goals].map { |sg| SubGoal.from_h(sg, parent: primary_goal) }
        primary_goal.instance_variable_set(:@sub_goals, sub_goals)
        primary_goal.instance_variable_set(:@sub_goal_map, build_map(sub_goals))
        
        primary_goal
      end

      private

      def validate_sub_goal_params!(goal_text, entry_id, priority)
        raise ArgumentError, "goal_text must be a String" unless goal_text.is_a?(String)
        raise ArgumentError, "entry_id must be a String" unless entry_id.is_a?(String)
        raise ArgumentError, "priority must be an Integer" unless priority.is_a?(Integer)
      end
    end
  end
end
```

## Validation Patterns

### Parameter Validation

**ALWAYS validate at the entry point:**

```ruby
def add_sub_goal(goal_text:, entry_id:, priority: 2, metadata: {})
  # Validate EVERYTHING
  raise ArgumentError, "goal_text must be a String" unless goal_text.is_a?(String)
  raise ArgumentError, "entry_id must be a String" unless entry_id.is_a?(String)
  raise ArgumentError, "priority must be an Integer" unless priority.is_a?(Integer)
  raise TypeError, "metadata must be a Hash" unless metadata.is_a?(Hash)
  
  # Only proceed with valid inputs
  # ...
end
```

### State Validation

```ruby
def update_status(status:, entry_id:, progress: nil)
  # Validate state transitions
  raise ArgumentError, "Invalid status: #{status}" unless STATUSES.include?(status)
  raise ArgumentError, "Cannot transition from #{@status} to #{status}" if invalid_transition?(@status, status)
  
  # Update state
  @status = status
  @updated_at = Time.now.utc.iso8601
end
```

### Type Validation

```ruby
def add_sub_context(name, context)
  # Strict type checking - no duck typing
  raise TypeError, "context must be a BaseContext, got #{context.class}" unless context.is_a?(BaseContext)
  
  @sub_contexts[name.to_sym] = context
  context
end
```

## Error Messages

**Be specific and actionable:**

```ruby
# ❌ BAD
raise "Invalid input"

# ✅ GOOD
raise ArgumentError, "goal_text must be a String, got #{goal_text.class}"

# ✅ BETTER
raise ArgumentError, "goal_text must be a non-empty String, got #{goal_text.inspect}"

# ✅ BEST
raise ArgumentError, "Expected goal_text to be a String but got #{goal_text.class}. " \
                     "Example: 'Complete the project'"
```

## Testing Patterns

### Test Real Objects, Not Hashes

```ruby
# ❌ BAD - Testing hash structure
test "goal has correct structure" do
  goal = { id: "123", text: "Task", status: :pending }
  assert_equal "Task", goal[:text]
end

# ✅ GOOD - Testing object behavior
test "goal tracks status changes" do
  goal = Goals::BaseGoal.new(goal_text: "Task", entry_id: "e1")
  goal.update_status(status: Goals::BaseGoal::IN_PROGRESS, entry_id: "e2")
  
  assert_equal :in_progress, goal.status
  assert_includes goal.entries, "e2"
end
```

### Test Validation

```ruby
test "validates goal_text is a String" do
  error = assert_raises(ArgumentError) do
    Goals::BaseGoal.new(goal_text: 123, entry_id: "e1")
  end
  assert_match(/goal_text must be a String/, error.message)
end
```

### Test Serialization Round-Trips

```ruby
test "serializes and deserializes correctly" do
  original = Goals::PrimaryGoal.new(goal_text: "Test", entry_id: "e1")
  original.add_sub_goal(goal_text: "Sub", entry_id: "e2", priority: 1)
  
  hash = original.to_h
  reconstructed = Goals::PrimaryGoal.from_h(hash)
  
  assert_equal original.id, reconstructed.id
  assert_equal original.goal_text, reconstructed.goal_text
  assert_equal 1, reconstructed.sub_goals.size
end
```

## Common Patterns

### Factory Pattern for Complex Creation

```ruby
class GoalContext
  def add_sub_goal(goal_text, priority: 2, metadata: {})
    # Validate first
    raise TypeError, "Primary goal must be set first" unless @primary_goal
    
    # Create entry
    entry = add(content: "Sub-goal: #{goal_text}", topics: ["goal"], source: "goal_context")
    
    # Create and link goal
    sub_goal = @primary_goal.add_sub_goal(
      goal_text: goal_text,
      entry_id: entry.id,
      priority: priority,
      metadata: metadata
    )
    
    # Update entry with goal id
    entry.metadata[:goal_id] = sub_goal.id
    
    sub_goal
  end
end
```

### Builder Pattern for Complex Objects

```ruby
class GoalBuilder
  def initialize(goal_text)
    @goal_text = goal_text
    @priority = 1
    @metadata = {}
  end

  def with_priority(priority)
    @priority = priority
    self  # Return self for chaining
  end

  def with_metadata(metadata)
    @metadata = metadata
    self
  end

  def build(entry_id)
    PrimaryGoal.new(
      goal_text: @goal_text,
      entry_id: entry_id,
      metadata: @metadata.merge(priority: @priority)
    )
  end
end

# Usage:
goal = GoalBuilder.new("Complete project")
  .with_priority(1)
  .with_metadata(type: "milestone")
  .build(entry.id)
```

## Directory Structure

Organize related classes into modules/directories:

```
app/models/contexts/
├── goals/
│   ├── base_goal.rb
│   ├── primary_goal.rb
│   └── sub_goal.rb
├── entries/
│   ├── base_entry.rb
│   ├── research_entry.rb
│   ├── scene_entry.rb
│   └── message_entry.rb
├── actions/
│   ├── base_action.rb
│   └── tool_action.rb
└── workflow/
    ├── state_transition.rb
    ├── decision.rb
    └── workflow_error.rb
```

## Lessons Learned from Real Refactorings

### Parameter Naming Consistency

**Problem:** When creating related classes, inconsistent parameter names cause confusion and errors.

```ruby
# ❌ BAD - Inconsistent naming
class StateTransition
  def initialize(from:, to:, event:)  # Short names
    @from_state = from
    @to_state = to
  end
end

class WorkflowContext
  def record_transition(from_state:, to_state:, event:)  # Long names
    # This mismatch causes errors!
    StateTransition.new(from_state: from_state, to_state: to_state, event: event)
  end
end
```

```ruby
# ✅ GOOD - Consistent naming
class StateTransition
  def initialize(from:, to:, event:)
    @from_state = from  # Internal naming can differ
    @to_state = to
  end
end

class WorkflowContext
  def record_transition(from:, to:, event:)  # Match the class's API
    StateTransition.new(from: from, to: to, event: event)
  end
end
```

**Lesson:** Keep parameter names consistent across related classes, even if internal attribute names differ.

### Collections: attr_reader vs Methods

**Problem:** Should collections be exposed directly or through methods?

```ruby
# ❌ BAD - Filtering entries every time
class WorkflowContext
  def transitions
    @entries.select { |e| e.metadata[:entity_type] == :transition }
  end
end
```

```ruby
# ✅ GOOD - Dedicated collection with attr_reader
class WorkflowContext
  attr_reader :transitions  # Direct access to collection

  def initialize
    @transitions = []  # Dedicated storage
  end

  def record_transition(...)
    transition = Workflow::StateTransition.new(...)
    @transitions << transition  # Store object directly
    transition
  end
end
```

**Lesson:** When you have domain entities, store them in dedicated collections rather than filtering from a general list.

### Testing Collections of Objects

**Update tests to check object types, not metadata:**

```ruby
# ❌ BAD - Testing metadata
test "has transitions" do
  context.record_transition(from: :a, to: :b, event: :go)
  
  transitions = context.entries.select { |e| e.metadata[:entity_type] == :transition }
  assert_equal 1, transitions.size
end
```

```ruby
# ✅ GOOD - Testing actual objects
test "has transitions" do
  transition = context.record_transition(from: :a, to: :b, event: :go)
  
  assert_instance_of Workflow::StateTransition, transition
  assert_equal 1, context.transitions.size
  assert context.transitions.all? { |t| t.is_a?(Workflow::StateTransition) }
end
```

**Lesson:** Test that methods return and store actual objects, not hashes with magic metadata keys.

### Refactoring Pitfalls

**Watch out for these common issues when refactoring to OOP:**

1. **Orphaned method parameters** - Old code may pass parameters that no longer exist
   ```ruby
   # ❌ Old code still using removed parameter
   load_sub_contexts_from_h(context, data, context_registry)
   
   # ✅ Remove all references to removed parameters
   load_sub_contexts_from_h(context, data)
   ```

2. **Accessor patterns** - Ensure readers exist for new collections
   ```ruby
   # ❌ Forgot to add reader
   def initialize
     @transitions = []  # No attr_reader!
   end
   
   # ✅ Add attr_reader
   attr_reader :transitions
   
   def initialize
     @transitions = []
   end
   ```

3. **Return types changed** - Methods that returned entries now return objects
   ```ruby
   # ❌ Test expects entry
   entry = context.record_transition(...)
   assert_equal :transition, entry.metadata[:entity_type]
   
   # ✅ Test expects object
   transition = context.record_transition(...)
   assert_instance_of StateTransition, transition
   ```

### Safe Refactoring Process

When refactoring from hashes to OOP:

1. **Create the new classes first** - Get them working independently
2. **Update the context** - Change how entities are stored
3. **Run tests and read errors carefully** - They tell you what's broken
4. **Update tests to use objects** - Change assertions to check types
5. **Remove old code** - Delete hash-based patterns completely
6. **Check integration tests** - Ensure the full system works

## Key Takeaways

1. **Always use proper classes, never hashes** for domain entities
2. **Validate everything** at method entry points
3. **Fail fast** with descriptive errors
4. **Use composition** for "has-a" relationships
5. **Chain serialization** with `**super` pattern
6. **Test real objects** and their behavior
7. **No backward compatibility** - only support proper types
8. **Single responsibility** - one purpose per class
9. **Keep parameter names consistent** across related classes
10. **Use dedicated collections** instead of filtering general lists

## Migration Checklist

When refactoring from hashes to OOP:

- [ ] Create base class with core behavior
- [ ] Add strict type validation
- [ ] Implement to_h/from_h (see serialization guide)
- [ ] Create subclasses for specialization
- [ ] Update all usage sites to use objects
- [ ] Write comprehensive tests
- [ ] Remove all hash-based code
- [ ] Update documentation

### Lesson 6: State Machine Completion Pattern

**Problem:** State machines must complete their full transition cycle. Building result objects with state information before final transition creates timing bugs.

**Bad Pattern:**
```ruby
# ❌ BAD: Captures state before transition completes
def execute
  trigger(:start)
  do_work
  trigger(:working)
  @result = build_result  # current_state = :working
  # Never calls trigger(:finish)!
end

def build_result
  { final_state: current_state }  # Returns :working instead of :complete
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Complete state machine, then update metadata
def execute
  trigger(:start)
  do_work
  trigger(:working)
  @result = build_result        # Build with intermediate state
  trigger(:finish)              # Complete the state machine
  @result[:metadata][:final_state] = current_state  # Update with actual final state
  @result
end
```

**Key Principles:**
1. **Always complete state transitions** - Every state machine path should end at a terminal state
2. **Capture dynamic state after transitions** - Don't freeze state prematurely
3. **Return values from execute** - Makes result accessible and testable
4. **Update metadata post-transition** - Ensure accuracy of state information

---

### Lesson 7: Inheritance and Optional Parameters

**Problem:** Parent class requires parameter, but not all subclasses need it. Forcing all subclasses to provide meaningless values violates LSP.

**Bad Pattern:**
```ruby
# ❌ BAD: Forces all subclasses to provide tools even when unused
class ToolCallPrompt < BasePrompt
  def initialize(tools:)  # Required parameter
    raise ArgumentError if tools.nil?
    @tools = tools
    super()
  end
end

class FileRelevancePrompt < ToolCallPrompt
  # Has to call super with dummy value!
  def initialize
    super(tools: [])  # Meaningless empty array
  end
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Default parameter, subclasses override when needed
class ToolCallPrompt < BasePrompt
  attr_reader :tools
  
  def initialize(tools: [])  # Optional with sensible default
    @tools = Array(tools)
    super()
  end
end

class ActionDetectionPrompt < ToolCallPrompt
  def initialize(tools:)
    raise ArgumentError if tools.nil? || tools.empty?
    super(tools: tools)  # Enforces requirement at subclass level
  end
end

class FileRelevancePrompt < ToolCallPrompt
  # No initialize needed - uses parent default
end
```

**Key Principles:**
1. **Make parent class flexible** - Use defaults for optional behavior
2. **Let subclasses enforce constraints** - Each subclass knows its own requirements
3. **Document parameter purpose** - Clarify when tools are actually used
4. **Use meaningful defaults** - Empty array, not nil, for collections

**Why This Matters:**
- Subclasses aren't forced into unnatural patterns
- Code self-documents which prompts use which features
- Easier to add new subclasses without boilerplate
- Follows Liskov Substitution Principle

---

### Lesson 8: Symbol Standardization at Interface Boundaries

**Problem:** Mixing string and symbol keys throughout the application creates confusion, bugs, and inconsistent code. LLMs return JSON with string keys but the application expects symbols.

**Bad Pattern:**
```ruby
# ❌ BAD: Converting to symbols in multiple places
class MyPrompt < BasePrompt
  def parse_response(response)
    result = super
    # Have to remember to symbolize here
    result[:content] = result[:content].symbolize_keys if result[:content].is_a?(Hash)
    result
  end
end

class MyWorkflow
  def process_llm_result(result)
    # Accessing with both strings and symbols
    tools = result["tool_sequence"] || result[:tool_sequence] || []
    tools.each do |tool|
      name = tool["tool"] || tool[:tool]  # More string/symbol confusion
    end
  end
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Symbolize once at the LLM boundary
class GenericLlmClient::ClientRetryWrapper
  def process_response(response)
    # Convert ALL keys to symbols at the boundary
    JSON.parse(JSON.generate(response), symbolize_names: true)
  end
end

class BasePrompt
  def parse_response(response)
    # Response already has symbol keys from GenericLlmClient
    message = response.dig(:choices, 0, :message)  # All symbols
    content = message[:content]
    
    # For structured JSON responses, parse with symbols
    parsed = JSON.parse(content, symbolize_names: true)
    { content: parsed, thoughts: response[:thoughts] }
  end
end

class MyWorkflow
  def process_llm_result(result)
    # Always use symbols - no string keys anywhere
    tools = result[:content][:tool_sequence]
    tools.each do |tool|
      execute_tool(tool[:tool], tool[:params])
    end
  end
end
```

**Key Principles:**
1. **Symbolize at boundaries** - LLM client converts all keys to symbols
2. **Application uses symbols** - No string keys in application code
3. **No defensive coding** - Don't check both `["key"]` and `[:key]`
4. **Consistent everywhere** - Hashes, JSON parsing, LLM responses all use symbols

---

### Lesson 9: Context-Aware Tools

**Problem:** Tools need to operate in specific contexts (directories, environments) but don't have access to that context. Generic tools that work everywhere don't work well anywhere.

**Bad Pattern:**
```ruby
# ❌ BAD: Tool doesn't know about execution context
class WriteFileTool
  def execute(path:, content:)
    File.write(path, content)  # Where? Current directory? Absolute path?
  end
end

class Workflow
  def execute_tool(tool_name, params)
    # Have to manipulate paths before calling tool
    full_path = File.join(@codebase_path, params[:path])
    tool.execute(path: full_path, content: params[:content])
  end
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Context-aware tool that knows its environment
module Sisyphus
  class WriteFileTool < BaseTool
    def self.parameters_schema
      {
        type: "object",
        properties: {
          path: { type: "string", description: "Relative path in codebase" },
          content: { type: "string" },
          codebase_path: { type: "string", description: "Root directory" }
        },
        required: ["path", "content", "codebase_path"]
      }
    end

    def execute(path:, content:, codebase_path:)
      validate_codebase!(codebase_path)
      full_path = File.join(codebase_path, path)
      validate_within_codebase!(full_path, codebase_path)
      
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      
      success_result("Wrote #{content.bytesize} bytes to #{path}")
    end

    private

    def validate_within_codebase!(target, root)
      real_root = File.realpath(root)
      real_target = File.realpath(File.dirname(target))
      unless real_target.start_with?(real_root)
        raise ArgumentError, "Path escapes codebase: #{target}"
      end
    end
  end
end

class StepExecutionWorkflow
  def execute_tool(tool_name, params)
    # Inject context automatically
    enriched_params = params.merge(codebase_path: @path)
    execute_sisyphus_tool(tool_name, enriched_params)
  end
end
```

**Key Principles:**
1. **Inject context** - Workflows provide context parameters to tools
2. **Validate context** - Tools validate they have the context they need
3. **Resolve paths** - Tools handle relative-to-absolute path conversion
4. **Safety first** - Validate operations stay within bounds (no escaping codebase)
5. **Namespace tools** - Context-specific tools live in their own namespace (e.g., `Sisyphus::`)

---

### Lesson 10: LLM Prompt Examples Drive Behavior

**Problem:** LLMs struggle with abstract schemas. Telling them "return an object with params" doesn't work as well as showing them exactly what you want.

**Bad Pattern:**
```ruby
# ❌ BAD: Abstract description without examples
def system_prompt
  <<~PROMPT
    Return a JSON object with:
    - `tool_sequence`: Array of tool calls
    - Each tool call has: `tool`, `params`, `rationale`
    - `params` is an object with the tool's parameters
  PROMPT
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Concrete examples showing exact format
def system_prompt
  <<~PROMPT
    ## Example Tool Calls

    ```json
    {
      "tool_sequence": [
        {
          "tool": "write_file",
          "params": {
            "path": "hello.rb",
            "content": "#!/usr/bin/env ruby\\nputs 'Hello, World!'"
          },
          "rationale": "Create the hello.rb file with Ruby code"
        },
        {
          "tool": "bash",
          "params": {
            "command": "chmod +x hello.rb"
          },
          "rationale": "Make the file executable"
        }
      ],
      "expected_outcome": "Created a working Ruby script"
    }
    ```

    ## Available Tools

    **write_file**: 
    - Parameters: `path` (string), `content` (string)
    - Example: `{"path": "app.rb", "content": "puts 'hi'"}`

    **bash**:
    - Parameters: `command` (string)
    - Example: `{"command": "ruby --version"}`

    **Important**: The `params` object must contain the exact parameter 
    names each tool expects. For example, write_file expects `path` and 
    `content`, bash expects `command`.
  PROMPT
end
```

**Key Principles:**
1. **Show, don't tell** - Provide complete JSON examples
2. **Be explicit** - Show exact parameter names and types
3. **Include variations** - Show different tool types
4. **Emphasize requirements** - Repeat critical requirements
5. **Use real values** - Examples should look like actual usage

---

### Lesson 11: Method Name Conflicts in Inheritance

**Problem:** Subclasses can accidentally override parent methods with different signatures, causing runtime errors that are hard to debug.

**Bad Pattern:**
```ruby
# ❌ BAD: Subclass overrides parent method with different signature
class BasePrompt
  def format_context(context, question: '')
    context.format_for_prompt(question)
  end
end

class StepPlanningPrompt < BasePrompt
  # Accidentally overrides parent with different signature!
  def format_context
    return "No context" if @assembled_context.empty?
    # Build context string...
  end
end

# Later, parent calls format_context(ctx, question: "foo")
# => ArgumentError: wrong number of arguments (given 2, expected 0)
```

**Good Pattern:**
```ruby
# ✅ GOOD: Use distinct method names for different purposes
class BasePrompt
  def format_context(context, question: '')
    return nil if context.nil?
    context.format_for_prompt(question)
  end
end

class StepPlanningPrompt < BasePrompt
  # Different name, no conflict
  def format_assembled_context
    return "No context" if @assembled_context.empty?
    # Build context string...
  end

  def build_user_message
    message = []
    message << "## Step Details"
    message << format_assembled_context  # Call our own method
    message.join("\n")
  end
end
```

**Key Principles:**
1. **Use descriptive names** - `format_assembled_context` vs `format_context`
2. **Check parent class** - Always review parent's public methods before naming
3. **Call super carefully** - If overriding, ensure signature matches exactly
4. **Fail fast** - Run tests immediately after creating subclass
5. **Namespace carefully** - Consider using prefixes for subclass-specific methods

---

### Lesson 12: Built-in Message Builders in Prompts

**Problem:** Workflows building prompt messages manually leads to inconsistent formatting and missed prompt improvements.

**Bad Pattern:**
```ruby
# ❌ BAD: Workflow builds message manually
class MyWorkflow
  def plan_step
    prompt = StepPlanningPrompt.new(step: @step, tools: @tools)
    
    # Workflow has to know how to format the message
    message = <<~MSG
      Step: #{@step.title}
      Details: #{@step.details.join(", ")}
      Tools available: #{@tools.map(&:name).join(", ")}
    MSG
    
    prompt.execute(prompt: message, context: nil)
  end
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Prompt encapsulates its own message building
class StepPlanningPrompt < BasePrompt
  def build_user_message
    message = []
    message << "## Step to Execute"
    message << ""
    message << "**Step #{@step.number}**: #{@step.title}"
    message << ""
    message << "**Intent**: #{@step.intent}"
    message << ""
    message << "**Details**:"
    @step.details.each { |d| message << "- #{d}" }
    message << ""
    message << "## Available Tools"
    message << format_tools
    message.join("\n")
  end
end

class MyWorkflow
  def plan_step
    prompt = StepPlanningPrompt.new(step: @step, tools: @tools)
    
    # Use the prompt's built-in builder
    message = prompt.build_user_message
    
    prompt.execute(prompt: message, context: nil)
  end
end
```

**Key Principles:**
1. **Prompts own their format** - Message building is part of the prompt
2. **Single responsibility** - Workflow orchestrates, prompt formats
3. **Easy updates** - Change format in one place (the prompt)
4. **Consistency** - All uses of prompt get same formatting
5. **Testing** - Can test message format independently

---

### Lesson 13: Centralized Test Infrastructure

**Problem:** Test infrastructure code (speed profiling, setup, etc.) is duplicated across every test file, violating DRY and making changes difficult.

**Bad Pattern:**
```javascript
// In EVERY test file
const speed_profile = (profile) => (name, fn) => {
  const timeouts = { fast: 1000, medium: 5000, slow: 30000 };
  return test(name, fn, timeouts[profile]);
};

describe("MyComponent", () => {
  speed_profile("fast")("test name", () => { /* ... */ });
});
```

**Good Pattern:**
```javascript
// In frontend/src/test/speedProfile.js (ONCE)
const SPEED_LEVELS = Object.freeze({
  FAST: 'fast',
  MEDIUM: 'medium',
  SLOW: 'slow'
});

const SPEED_LIMITS = Object.freeze({
  [SPEED_LEVELS.FAST]: 1000,
  [SPEED_LEVELS.MEDIUM]: 5000,
  [SPEED_LEVELS.SLOW]: 30000
});

export const speed_profile = (profile) => {
  if (!Object.values(SPEED_LEVELS).includes(profile)) {
    throw new Error(`Invalid speed profile: ${profile}`);
  }
  
  return (name, fn, options = {}) => {
    const timeout = SPEED_LIMITS[profile];
    return test(name, fn, { timeout, ...options });
  };
};

// In test files
import { speed_profile } from "../../test/speedProfile";

describe("MyComponent", () => {
  speed_profile("fast")("test name", () => { /* ... */ });
});
```

**Backend Pattern (Ruby):**
```ruby
# In test/support/speed_profile.rb (ONCE)
module SpeedProfile
  SPEED_LEVELS = [
    FAST = :fast,
    MEDIUM = :medium,
    SLOW = :slow
  ].freeze

  SPEED_LIMITS = {
    FAST => 10,
    MEDIUM => 60,
    SLOW => 120
  }.freeze

  def self.included(base)
    base.class_eval do
      def speed_profile(level)
        unless SPEED_LEVELS.include?(level)
          raise ArgumentError, "Invalid speed profile: #{level}"
        end
        @next_speed_profile = level
      end
    end
  end

  private

  def validate_speed_profile!
    speed = self.class.speed_profile_for(name)
    raise ArgumentError, "Test must declare speed_profile" unless speed
  end
end

# In test/test_helper.rb
module ActiveSupport
  class TestCase
    include SpeedProfile
  end
end

# In test files
class MyTest < ActiveSupport::TestCase
  speed_profile :fast
  test "something" do
    # ...
  end
end
```

**Key Principles:**
1. **Single Definition** - Test infrastructure defined once, used everywhere
2. **Fail Fast** - Invalid profiles raise errors immediately
3. **Type Safety** - Frozen constants prevent modification
4. **Enforced** - Tests without speed profiles fail with clear error
5. **Consistent** - Same pattern across backend and frontend

**Why This Matters:**
- Change timeout limits in ONE place
- Add new speed levels in ONE place
- Ensure ALL tests follow the same pattern
- Clear error messages when misused
- Easier to maintain and update

**Migration Checklist:**
- [ ] Create centralized speed profile module
- [ ] Export it from test setup/helper
- [ ] Update all test files to import from central module
- [ ] Remove duplicated speed_profile definitions
- [ ] Add validation/enforcement
- [ ] Document usage in testing guide

---

### Lesson 14: Deep Validation for Collection Parameters

**Problem:** Validating that a parameter is an Array is not enough - the array elements must also be validated to prevent runtime errors.

**Bad Pattern:**
```ruby
# ❌ BAD: Only validates container type, not contents
class Checkpoint
  def initialize(id:, files_changed: [])
    raise TypeError, "files_changed must be an Array" unless files_changed.is_a?(Array)
    @files_changed = files_changed
  end
end

# Later in code:
checkpoint = Checkpoint.new(id: "abc", files_changed: ["file.rb", 123, nil])
# No error! But files_changed now contains invalid types
```

**Good Pattern:**
```ruby
# ✅ GOOD: Validates both container and contents
class Checkpoint
  def initialize(id:, files_changed: [])
    validate_files_changed!(files_changed)
    @files_changed = files_changed
  end

  private

  def validate_files_changed!(files_changed)
    raise TypeError, "files_changed must be an Array, got #{files_changed.class}" unless files_changed.is_a?(Array)
    
    # Validate ALL elements
    unless files_changed.all? { |f| f.is_a?(String) }
      invalid_types = files_changed.map(&:class).uniq - [String]
      raise TypeError, "files_changed must contain only Strings, found: #{invalid_types.join(', ')}"
    end
  end
end
```

**Key Principles:**
1. **Deep Validation** - Check container type AND element types
2. **Descriptive Errors** - Show what invalid types were found
3. **Fail Fast** - Catch errors at object creation, not later during iteration
4. **Type Safety** - Guarantee internal state is always valid

**Why This Matters:**
- Prevents `NoMethodError` when calling String methods on non-strings
- Makes debugging easier (fails at creation, not usage)
- Documents expected types clearly
- Enables safe iteration without type checking

---

### Lesson 15: Immutable Collection Accessors

**Problem:** Exposing mutable collections via `attr_reader` allows external code to modify internal state, violating encapsulation.

**Bad Pattern:**
```ruby
# ❌ BAD: Exposes mutable array
class CheckpointRegistry
  attr_reader :checkpoints  # Returns @checkpoints array directly
  
  def initialize
    @checkpoints = []
  end
  
  def add(checkpoint)
    @checkpoints << checkpoint
  end
end

# External code can break invariants:
registry = CheckpointRegistry.new
registry.checkpoints << "not a checkpoint"  # BAD!
registry.checkpoints.clear  # BAD!
registry.checkpoints.sort!  # Changes internal order!
```

**Good Pattern - Option 1: Defensive Copy:**
```ruby
# ✅ GOOD: Return frozen copy
class CheckpointRegistry
  def initialize
    @checkpoints = []
  end
  
  # Return defensive copy
  def all
    @checkpoints.dup.freeze
  end
  
  def add(checkpoint)
    validate_checkpoint!(checkpoint)
    @checkpoints << checkpoint
  end
end

# External code cannot mutate:
registry = CheckpointRegistry.new
registry.all << "test"  # RuntimeError: can't modify frozen Array
```

**Good Pattern - Option 2: Enumerable Interface:**
```ruby
# ✅ BETTER: Provide iteration methods, don't expose array
class CheckpointRegistry
  include Enumerable
  
  def initialize
    @checkpoints = []
  end
  
  # Implement Enumerable interface
  def each(&block)
    @checkpoints.each(&block)
  end
  
  # Provide specific query methods
  def count
    @checkpoints.size
  end
  
  def latest
    @checkpoints.last
  end
  
  def find(id)
    @checkpoints.find { |cp| cp.id == id }
  end
end

# External code can iterate but not mutate:
registry.each { |cp| puts cp.id }  # Works
registry.map(&:id)  # Works
registry.clear  # NoMethodError - collection is protected
```

**Key Principles:**
1. **Never expose mutable collections** - Use `dup.freeze` or provide iterator methods
2. **Prefer Enumerable** - Implement `each` and include `Enumerable` for full interface
3. **Specific accessors** - Provide query methods for common operations
4. **Protect invariants** - Internal state cannot be corrupted from outside

**Why This Matters:**
- Maintains encapsulation
- Prevents accidental mutations
- Makes threading safer (immutable data)
- Clear API (explicit methods vs. array manipulation)

---

### Lesson 16: Polymorphic Parameters with Type Guards

**Problem:** APIs often need to accept multiple related types (domain object or primitive ID), requiring type extraction logic.

**Bad Pattern:**
```ruby
# ❌ BAD: Callers must always convert to ID
class GitRollbackService
  def rollback_to(checkpoint_id)  # Only accepts String
    # ...
  end
end

# Usage requires conversion:
checkpoint = find_checkpoint(...)
service.rollback_to(checkpoint.id)  # Caller must know to extract ID
```

**Good Pattern:**
```ruby
# ✅ GOOD: Accept both types with type guard
class GitRollbackService
  def rollback_to(checkpoint, strategy: :hard)
    checkpoint_id = extract_checkpoint_id(checkpoint)
    # ...
  end

  private

  def extract_checkpoint_id(checkpoint)
    case checkpoint
    when Checkpoint
      checkpoint.id
    when String
      checkpoint
    else
      raise TypeError, "checkpoint must be a Checkpoint or String, got #{checkpoint.class}"
    end
  end
end

# Usage is flexible:
service.rollback_to(checkpoint)          # Pass object
service.rollback_to("abc123")            # Or pass ID directly
service.rollback_to(123)                 # TypeError with clear message
```

**Key Principles:**
1. **Flexible API** - Accept related types that make sense
2. **Type Guard** - Extract/convert in one place with validation
3. **Fail Fast** - Raise TypeError for unsupported types
4. **Clear Errors** - Show what types are accepted

**Benefits:**
- Convenient for callers (don't need to know internal representation)
- Type safety maintained (validation in one place)
- Easy to extend (add more types to the case statement)
- Self-documenting (error message lists valid types)

---

### Lesson 17: Structured Result Hashes for Decisions

**Problem:** Methods that make decisions should return both the decision AND the reasoning for logging and debugging.

**Bad Pattern:**
```ruby
# ❌ BAD: Only returns boolean
class CheckpointPolicy
  def should_checkpoint?(context)
    return false unless config[:enabled]
    return false if too_soon?(context[:last_checkpoint])
    true
  end
end

# Usage: No insight into WHY
if policy.should_checkpoint?(context)
  create_checkpoint
else
  # Why not? Who knows!
  logger.info "Not creating checkpoint"
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Returns decision + reasoning
class CheckpointPolicy
  def should_checkpoint?(context)
    unless config[:enabled]
      return { should_checkpoint: false, reason: "Checkpoints disabled in config" }
    end
    
    if too_soon?(context[:last_checkpoint])
      return {
        should_checkpoint: false,
        reason: "Minimum interval not elapsed (#{config[:min_interval]}s required)"
      }
    end
    
    { should_checkpoint: true, reason: "Checkpoint interval elapsed" }
  end
end

# Usage: Can log reasoning
result = policy.should_checkpoint?(context)
if result[:should_checkpoint]
  logger.info "Creating checkpoint: #{result[:reason]}"
  create_checkpoint
else
  logger.info "Skipping checkpoint: #{result[:reason]}"
end
```

**Key Principles:**
1. **Structured Results** - Return hash with decision and reasoning
2. **Always Include Reason** - For both positive and negative decisions
3. **Actionable Reasons** - Include relevant values/thresholds
4. **Consistent Structure** - Same keys for all code paths

**Benefits:**
- Better logging (know why decisions were made)
- Easier debugging (can trace decision logic)
- Better UX (can show user why action was/wasn't taken)
- Self-documenting (reason explains the logic)

---

### Lesson 18: Shell Command Escaping

**Problem:** Building shell commands with string interpolation is dangerous - special characters can break commands or enable injection attacks.

**Bad Pattern:**
```ruby
# ❌ BAD: Manual escaping is fragile and incomplete
def create_backup(message)
  escaped = message.gsub("'", "\\\\'")  # Only handles single quotes
  result = `git commit -m '#{escaped}'`
end

# Breaks with: message = "It's done & saved"
# Results in: git commit -m 'It'\''s done & saved'
# The & becomes part of shell syntax!
```

**Good Pattern:**
```ruby
# ✅ GOOD: Use Shellwords for proper escaping
require 'shellwords'

def create_backup(message)
  escaped_message = Shellwords.escape(message)
  result = `git commit -m #{escaped_message}`
end

# Handles all special characters:
# message = "It's done & saved"
# Becomes: git commit -m It\'s\ done\ \&\ saved
```

**Best Pattern for Complex Commands:**
```ruby
# ✅ BEST: Use array form with Open3 (no shell interpolation)
require 'open3'

def create_backup(message)
  stdout, stderr, status = Open3.capture3(
    'git', 'commit', '-m', message  # Each arg is separate - no escaping needed!
  )
  
  {
    success: status.success?,
    output: status.success? ? stdout : stderr
  }
end
```

**Key Principles:**
1. **Never trust input** - Always escape user-provided strings
2. **Use Shellwords** - For string interpolation in shell commands
3. **Prefer array form** - With Open3.capture3 when possible
4. **Test edge cases** - Try strings with quotes, spaces, special chars

**Why This Matters:**
- Security: Prevents command injection
- Correctness: Handles all special characters
- Reliability: No silent failures from broken commands

---

### Lesson 19: Automatic Collection Ordering

**Problem:** Collections that have a natural order should maintain that order automatically, not require callers to sort.

**Bad Pattern:**
```ruby
# ❌ BAD: Caller must remember to sort
class CheckpointRegistry
  def add(checkpoint)
    @checkpoints << checkpoint
    # No sorting - order is arbitrary
  end
  
  def latest
    @checkpoints.sort_by(&:created_at).last  # Sorting every time!
  end
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Maintain order automatically
class CheckpointRegistry
  def add(checkpoint)
    validate_checkpoint!(checkpoint)
    @checkpoints << checkpoint
    @checkpoints.sort_by!(&:created_at)  # Always maintain chronological order
    @checkpoint_map[checkpoint.id] = checkpoint
    checkpoint
  end
  
  def latest
    @checkpoints.last  # Always returns latest due to maintained order
  end
end
```

**Key Principles:**
1. **Maintain Invariants** - Keep collection in correct state at all times
2. **Sort on Modification** - Not on access (pay cost once, not every time)
3. **Document Ordering** - Make it clear in docs that collection is ordered
4. **Efficient Access** - `latest` is O(1) instead of O(n log n)

**Benefits:**
- Simpler API (callers don't need to sort)
- Better performance (sort once, not every access)
- Guaranteed correctness (order can't be wrong)
- Clear semantics (order is part of the contract)

---

### Lesson 20: Required Parameters and No Defensive Nil Checks

**Problem:** Optional parameters with default values lead to defensive `nil` checks throughout the codebase, making code harder to reason about and hiding bugs.

**Bad Pattern:**
```ruby
# ❌ BAD: Optional parameter with nil default
class WorkflowMemoryStore
  def initialize(owner_id:, workflow_id:, workflow_name:, path: nil)
    @path = path || default_path
    @last_transition_at = nil
  end

  def calculate_duration
    return 0 unless @last_transition_at  # Defensive nil check
    Time.now.utc - @last_transition_at
  end

  def current_checkpoint_id
    return nil unless @path  # Defensive nil check
    CheckpointTracker.instance.current_id(path: @path)
  end
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Required parameters, always initialized
class WorkflowMemoryStore
  def initialize(owner_id:, workflow_id:, workflow_name:, path:)
    raise ArgumentError, "owner_id is required" if owner_id.nil? || owner_id.empty?
    raise ArgumentError, "workflow_id is required" if workflow_id.nil? || workflow_id.empty?
    raise ArgumentError, "path is required" if path.nil? || path.empty?

    @owner_id = owner_id
    @workflow_id = workflow_id
    @workflow_name = workflow_name
    @path = path
    @last_transition_at = Time.now.utc  # Always initialized
  end

  def calculate_duration
    # No nil check - @last_transition_at is always a Time object
    Time.now.utc - @last_transition_at
  end

  def current_checkpoint_id
    # No nil check - @path is always present
    CheckpointTracker.instance.current_id(path: @path)
  end
end
```

**Key Principles:**
1. **Make required parameters explicit** - No defaults for essential values
2. **Validate in constructor** - Fail fast with clear error messages
3. **Initialize all instance variables** - Never leave them nil if they'll be used
4. **No defensive nil checks** - If something is required, enforce it at creation
5. **Subclass for variations** - Create specialized classes instead of optional behavior

**When to Use Optional Parameters:**
```ruby
# ✅ Optional parameters are OK for true options/configuration
class MyService
  def initialize(path:, retry_count: 3, timeout: 30)
    # These are configuration options with sensible defaults
    @path = path  # Required
    @retry_count = retry_count  # Optional with default
    @timeout = timeout  # Optional with default
  end
end
```

**Why This Matters:**
- **Eliminates entire classes of bugs** - No more `NoMethodError` on nil
- **Clearer intent** - Required parameters document dependencies
- **Simpler code** - No defensive checks scattered throughout
- **Better errors** - Fail at construction time, not deep in execution
- **Type safety** - Instance variables have known, guaranteed types

**Migration Strategy:**
1. Identify optional parameters that are actually required
2. Change default values from `nil` to required (remove `= nil`)
3. Add validation in constructor
4. Initialize all instance variables that will be used
5. Remove all defensive `return if @var.nil?` checks
6. Update all call sites to provide required parameters

---

### Lesson 21: Singleton Pattern for Global State Tracking

**Problem:** Services that track global state (like current codebase checkpoint) need to be accessible from anywhere without being passed through every layer.

**Bad Pattern:**
```ruby
# ❌ BAD: Pass checkpoint service through every layer
class Worker
  def initialize(...)
    @checkpoint_service = CheckpointService.new(path: @path)
  end

  def create_memory_store
    WorkflowMemoryStore.new(..., checkpoint_service: @checkpoint_service)
  end
end

class WorkflowMemoryStore
  def initialize(..., checkpoint_service:)
    @checkpoint_service = checkpoint_service
  end

  def record_decision(...)
    checkpoint_id = @checkpoint_service.current_checkpoint_id
    # ...
  end
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Singleton for global state
module CheckpointTracker
  include Singleton

  def current_id(path:, message: nil, metadata: {})
    @mutex.synchronize do
      # Automatically create checkpoint if codebase changed
      service = checkpoint_service_for(path)
      if codebase_changed?(service)
        create_checkpoint(service, path, message, metadata).id
      else
        @last_checkpoint[path].id
      end
    end
  end
end

class WorkflowMemoryStore
  def record_decision(...)
    # Access singleton directly - no dependency injection needed
    checkpoint_id = CheckpointTracker.instance.current_id(path: extract_repo_path)
    # ...
  end
end
```

**Key Principles:**
1. **Use for truly global state** - Current checkpoint, configuration, caches
2. **Thread-safe with mutex** - Protect shared state with synchronization
3. **Lazy initialization** - Create resources on first use per path/key
4. **Clear, simple API** - `CheckpointTracker.instance.current_id(path: ...)`
5. **Automatic behavior** - Checkpoint created only when codebase changes

**When to Use Singleton:**
- **Global system state** - Current checkpoint, application config
- **Resource pools** - Database connections, HTTP clients
- **Caches** - Memoization across requests
- **System-wide coordinators** - Job schedulers, event buses

**When NOT to Use Singleton:**
- **Business logic** - Use regular services injected as dependencies
- **Per-request state** - Use instance variables or request objects
- **Testable collaborators** - Use dependency injection for easier mocking

**Why This Matters:**
- **Eliminates parameter threading** - No passing through every layer
- **Single source of truth** - One place tracks global state
- **Automatic management** - Handles creation/caching transparently
- **Cleaner interfaces** - Classes don't need irrelevant constructor params

---

### Lesson 22: Validation Belongs in Constructors, Not Service Methods

**Problem:** Services that validate inputs create redundant checks and hide the true contract. Validation should happen once at object creation, not at every method call.

**Bad Pattern:**
```ruby
# ❌ BAD: Service validates inputs
class VectorizationService
  def vectorize(text:)
    raise TypeError, "text must be a String, got #{text.class}" unless text.is_a?(String)
    raise ArgumentError, "text cannot be empty" if text.empty?
    
    embedding = @llm_client.embed(text: text)
    raise TypeError, "LLM client must return an Embedding, got #{embedding.class}" unless embedding.is_a?(Embedding)
    
    embedding
  end

  def find_similar(query_embedding:, memories:, threshold: 0.70)
    raise TypeError, "query_embedding must be an Embedding" unless query_embedding.is_a?(Embedding)
    raise TypeError, "memories must be an Array" unless memories.is_a?(Array)
    raise ArgumentError, "threshold must be between 0.0 and 1.0" unless threshold.between?(0.0, 1.0)
    
    # ... actual logic ...
  end
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Domain objects validate, services trust
class Embedding
  def initialize(vector:, text:)
    raise TypeError, "vector must be an Array, got #{vector.class}" unless vector.is_a?(Array)
    raise TypeError, "text must be a String, got #{text.class}" unless text.is_a?(String)
    raise ArgumentError, "text cannot be empty" if text.empty?
    raise ArgumentError, "vector dimension must be #{STANDARD_DIMENSION}" unless vector.length == STANDARD_DIMENSION
    
    @vector = vector.freeze
    @text = text.freeze
    freeze
  end
end

class VectorizationService
  # Service trusts inputs - validation happened at construction
  def vectorize(text:)
    @llm_client.embed(text: text)  # Returns Embedding (validated in constructor)
  end

  def find_similar(query_embedding:, memories:, threshold: DEFAULT_SIMILARITY_THRESHOLD)
    # No validation - query_embedding is an Embedding (already validated)
    # memories contain objects with #embedding (enforced by type system)
    results = memories.filter_map do |memory|
      memory_embedding = memory.embedding
      similarity = query_embedding.similarity_to(memory_embedding)
      { memory: memory, similarity: similarity } if similarity >= threshold
    end
    results.sort_by { |r| -r[:similarity] }
  end
end
```

**Key Principles:**
1. **Validate once in constructors** - Domain objects enforce their invariants
2. **Services trust their inputs** - Assume correct types were passed
3. **Let errors propagate naturally** - NoMethodError reveals contract violations
4. **Type system as documentation** - Method signatures show expected types

**Why This Works:**
- **Impossible invalid states** - Can't create invalid domain objects
- **Clearer contracts** - Method signatures reveal expectations
- **Less redundant code** - Validation written once, not everywhere
- **Better errors** - NoMethodError on wrong type is clear enough
- **Fail fast at construction** - Problems caught when object is created

**Example Flow:**
```ruby
# BAD: Validate at every step
text = "some text"
raise TypeError unless text.is_a?(String)  # Check 1
embedding = service.vectorize(text: text)  # Check 2 inside service
raise TypeError unless embedding.is_a?(Embedding)  # Check 3
results = service.find_similar(query_embedding: embedding, ...)  # Check 4 inside service

# GOOD: Validate once at construction
text = "some text"
embedding = Embedding.new(vector: [...], text: text)  # Validates here
results = service.find_similar(query_embedding: embedding, ...)  # Trusts type
```

**When Services Do Validate:**
- **Configuration/options with defaults** - e.g., `threshold.between?(0.0, 1.0)`
- **Business rules** - e.g., "cannot refund after 30 days"
- **External constraints** - e.g., "API rate limit exceeded"

**When Services Don't Validate:**
- **Type checking** - Domain objects handle this
- **Required parameters** - Handled by keyword arguments
- **Format validation** - Domain objects enforce format
- **Nil checks** - Required parameters prevent nil

**Benefits:**
- Services focus on business logic, not validation
- Single source of truth for what makes a valid object
- Easier to test (construct valid objects in setup)
- Clearer separation of concerns
- Less defensive programming

---

### Lesson 24: Speed Profile Categorization

**Problem:** Tests with incorrect speed profiles either timeout unnecessarily or hide performance issues.

**Speed Profile Guidelines:**

**Fast (<10s):**
- Unit tests with no external dependencies
- Pure logic, validation, serialization
- In-memory operations
- Object construction and manipulation
- 95% of tests should be fast

**Medium (10-60s):**
- Single LLM API calls with tight context
- Embedding generation (small text)
- Database queries with reasonable data
- File I/O operations
- Integration tests with one external service

**Slow (60-120s):**
- Multiple LLM API calls
- Large context processing
- Complex workflow execution
- Full end-to-end system tests
- Tests that process significant data

**Examples:**

```ruby
# ✅ FAST - Pure object logic
speed_profile :fast
test "validates required parameters" do
  error = assert_raises(ArgumentError) do
    Decision.new(decision: "", rationale: "test", context: {}, checkpoint_id: "abc", state: :planning)
  end
  assert_match(/decision cannot be empty/, error.message)
end

# ✅ FAST - Serialization round-trip
speed_profile :fast
test "serializes and deserializes correctly" do
  original = Decision.new(decision: "test", rationale: "test", context: {}, checkpoint_id: "abc", state: :planning)
  hash = original.to_h
  reconstructed = Decision.from_h(hash)
  assert_equal original.decision, reconstructed.decision
end

# ✅ MEDIUM - Single embedding call with small text
speed_profile :medium
test "generates embedding lazily" do
  decision = Decision.new(decision: "test decision", rationale: "test rationale", context: {}, checkpoint_id: "abc", state: :planning)
  embedding1 = decision.embedding
  embedding2 = decision.embedding
  assert_equal embedding1.object_id, embedding2.object_id
  assert_instance_of Embedding, embedding1
end

# ✅ MEDIUM - Vector similarity with two embeddings
speed_profile :medium
test "similarity_to compares with another decision" do
  decision1 = Decision.new(decision: "Implement logging", rationale: "Better debugging", context: {}, checkpoint_id: "abc", state: :planning)
  decision2 = Decision.new(decision: "Add error tracking", rationale: "Improved monitoring", context: {}, checkpoint_id: "def", state: :planning)
  similarity = decision1.similarity_to(decision2)
  assert similarity >= 0.0
  assert similarity <= 1.0
end

# ✅ SLOW - Full workflow with multiple LLM calls
speed_profile :slow
test "executes complete planning workflow" do
  workflow = PlanningWorkflow.new(goal: "Build feature X")
  result = workflow.execute
  assert result.success?
  assert result.steps.length > 0
end
```

**Key Principles:**
1. **Default to fast** - Most tests should be fast
2. **Tight context = medium** - Small LLM calls fit in 60s
3. **Large context = slow** - Multiple calls or big context needs 120s
4. **Measure actual times** - If test exceeds profile, move it up
5. **No buffer padding** - Categorize based on actual expected time

**Why This Matters:**
- Fast feedback loops for developers
- Parallel execution optimization
- Clear expectations for test runtime
- CI/CD pipeline efficiency

---

### Lesson 23: No Skips in Tests - Test Real Behavior

**Problem:** Tests that skip functionality or check ENV variables undermine test suite reliability and hide configuration issues.

**Bad Pattern:**
```ruby
# ❌ BAD: Skipping tests based on environment
test "generates embedding lazily" do
  skip "Requires LLM client configuration" unless ENV["OPENAI_API_KEY"]
  
  embedding = memory.embedding
  assert_instance_of Embedding, embedding
end

# ❌ BAD: Conditional test behavior based on ENV
test "calls external API" do
  if ENV["RUN_INTEGRATION_TESTS"]
    result = api.call
    assert result.success?
  else
    skip "Integration tests disabled"
  end
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Test real behavior, trust configuration
test "generates embedding lazily" do
  decision = WorkflowMemories::Decision.new(
    decision: "test decision",
    rationale: "test rationale",
    context: {},
    checkpoint_id: "abc",
    state: :planning
  )
  
  embedding1 = decision.embedding
  embedding2 = decision.embedding
  
  # Memoization works - same object returned
  assert_equal embedding1.object_id, embedding2.object_id
  assert_instance_of Embedding, embedding1
  assert_equal 1536, embedding1.dimension
end

# ✅ GOOD: Test with real service, let it fail if misconfigured
test "vectorization service generates embeddings" do
  service = VectorizationService.new
  embedding = service.vectorize(text: "test content")
  
  assert_instance_of Embedding, embedding
  assert_equal "test content", embedding.text
  assert_equal 1536, embedding.vector.length
end
```

**Key Principles:**
1. **Never skip tests** - If a test can't run, the test suite is broken
2. **No ENV checks in tests** - Configuration should always work
3. **Test real behavior** - Don't mock what you should be testing
4. **Fail loudly** - Better to fail with clear error than silently skip
5. **Separate test types** - Use test directories, not skips (e.g., `test/unit/`, `test/integration/`)

**Why This Matters:**
- **Reliability** - Skipped tests hide problems until production
- **Confidence** - Green suite means everything works, not "everything except skipped tests"
- **Configuration** - Forces proper test environment setup
- **Documentation** - Tests show how code actually works
- **CI/CD** - Automated builds catch configuration issues early

**Global Configuration:**
- Use `API_KEY` environment variable for all LLM APIs globally
- Test environment should have all necessary configuration
- If config is missing, tests fail with clear message (not skip)

**Test Organization Instead of Skips:**
```
test/
├── unit/          # Fast, no external dependencies
├── integration/   # Real APIs, databases, etc.
└── system/        # Full end-to-end tests

# Run different suites:
rails test:unit              # Fast unit tests
rails test:integration       # Integration tests
rails test                   # Everything
```

**Migration from Skips:**
- Remove all `skip` calls
- Remove ENV checks from test code
- Fix configuration issues that caused skips
- Let tests fail if environment isn't set up correctly
- Use descriptive error messages if something is missing

---

## References

- [Serialization Guide](./serialization-guide.md)
- SOLID Principles
- Ruby Style Guide
- Domain-Driven Design patterns