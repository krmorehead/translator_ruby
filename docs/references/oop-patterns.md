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

### Lesson 24: No Defensive Type Checking - Let Errors Fail Loudly

**Problem:** Adding defensive type checks (like `is_a?`) throughout the codebase hides bugs and violates fail-fast principles.

**Bad Pattern:**
```ruby
# ❌ BAD: Defensive type checking hides the real problem
def summarize
  transitions = @sections[:state_transitions]
  
  states_visited = transitions.map do |t|
    # Don't do this! If t isn't the right type, we should know immediately
    t.is_a?(StateTransition) ? t.to : (t[:to] || t["to"])
  end.compact.uniq
end

# ❌ BAD: Checking for nil everywhere
def process_user(user)
  return nil unless user
  return nil unless user.name
  return nil unless user.email
  
  # ... actual logic
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Expect correct types, fail loudly if wrong
def summarize
  transitions = @sections[:state_transitions]
  
  # If transitions contains non-StateTransition objects, .to will raise NoMethodError
  # This is GOOD - it tells us exactly what's wrong and where
  states_visited = transitions.map(&:to).uniq
end

# ✅ GOOD: Validate at construction, trust everywhere else
class UserProcessor
  def initialize(user:)
    raise ArgumentError, "user is required" unless user
    raise TypeError, "user must be a User, got #{user.class}" unless user.is_a?(User)
    
    @user = user
  end
  
  def process
    # No nil checks - we validated in constructor
    send_email(@user.name, @user.email)
  end
end
```

**Key Principles:**
1. **Validate once in constructors** - Not at every use site
2. **Trust your types** - If @sections[:state_transitions] should contain StateTransition objects, it DOES
3. **Let NoMethodError reveal bugs** - Don't hide them with defensive checks
4. **Fail fast** - Errors at the call site tell you exactly what's wrong
5. **No backward compatibility** - Fix the source of bad data, don't work around it

**Why This Matters:**
- **Bugs surface immediately** - Not hidden by fallback logic
- **Clear error messages** - NoMethodError on Hash tells you exactly what's wrong
- **Forces proper fixes** - Can't paper over architectural issues
- **Simpler code** - No branching for type checks
- **Better performance** - No runtime type checking overhead

**Migration Strategy:**
If you find defensive type checks in code:
1. Remove the type check
2. Run tests - they will fail with NoMethodError
3. Fix the ROOT CAUSE that's putting wrong types in
4. Don't add the type check back

**Example:**
```ruby
# Before migration - defensive code hiding bugs
def calculate_total
  items = @cart.items
  items.map { |i| i.is_a?(Item) ? i.price : 0 }.sum  # ❌
end

# After migration - let it fail
def calculate_total
  @cart.items.map(&:price).sum  # ✅
end
# If this raises NoMethodError, fix Cart#items to ensure it only contains Item objects

```

**No Rescue Blocks for Test Fallbacks:**
```ruby
# ❌ BAD: Catching errors to provide test data
def current_checkpoint_id
  CheckpointTracker.instance.current_id(path: extract_repo_path)
rescue => e
  Rails.logger.debug("Checkpoint tracking failed: #{e.message}, using test checkpoint")
  "test_checkpoint_#{SecureRandom.hex(8)}"  # DON'T DO THIS
end

# ✅ GOOD: Let it fail, fix the root cause
def current_checkpoint_id
  CheckpointTracker.instance.current_id(path: extract_repo_path)
  # If this fails, tests will show the real error
  # Fix the test setup to provide proper Git repositories
end
```

**Tests must use real data and real environments:**
- Tests should set up proper Git repositories if code needs Git
- Tests should use real checkpoint IDs, not fake fallbacks
- If code fails in tests, fix the test environment, don't catch the error

---

### Lesson 26: Test Behavior, Not Configuration

**Problem:** Tests that assert specific configuration values are brittle and fail when configuration changes, even though behavior is correct.

**Bad Pattern:**
```ruby
# ❌ BAD: Testing specific configuration value
test "model comes from general_llm capability" do
  prompt = NarrativePrompt.new
  assert_equal "./vllm/models/qwen3_30b_a3b_moe", prompt.model
end

# ❌ BAD: Testing exact paths
test "checkpoint path format" do
  assert_equal "/app/.agents/state/abc123", worker.checkpoint_path
end

# ❌ BAD: Testing exact error messages
test "validation error" do
  error = assert_raises(ValidationError) { create_invalid_user }
  assert_equal "Email must be valid format", error.message
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Test that model is set and valid
test "has a configured model" do
  prompt = NarrativePrompt.new
  assert_not_nil prompt.model
  assert_kind_of String, prompt.model
  assert prompt.model.length > 0
end

# ✅ GOOD: Test path structure/behavior
test "checkpoint path is in state directory" do
  assert_includes worker.checkpoint_path, ".agents/state"
  assert File.dirname(worker.checkpoint_path)  # Path is valid
end

# ✅ GOOD: Test error type and key content
test "validation error mentions email" do
  error = assert_raises(ValidationError) { create_invalid_user }
  assert_match(/email/i, error.message)
end
```

**Key Principles:**
1. **Test behavior, not values** - Does it work? Not what exact value it has
2. **Test contracts, not implementation** - Does it return a model? Not which model
3. **Make tests resilient to config changes** - Config can change without breaking behavior
4. **Test types and structure** - Is it a String? Not is it "xyz"
5. **Use pattern matching for messages** - Does it mention the field? Not exact wording

**Why This Matters:**
- **Tests remain valid when configuration changes** - Updating models doesn't break tests
- **Tests focus on correctness** - Is behavior right? Not is config the same
- **Easier maintenance** - Don't update tests when config changes
- **Better failure messages** - Failures indicate real problems, not config drift

**What to Test:**
- ✅ Method returns non-nil value
- ✅ Return value is correct type
- ✅ Behavior works as expected
- ✅ Integration points function
- ❌ Specific configuration values
- ❌ Exact file paths or URLs
- ❌ Exact error message wording

**Migration Strategy:**
```ruby
# Before: Brittle test
test "uses correct model" do
  assert_equal "gpt-4", service.model
end

# After: Resilient test
test "has a valid model configured" do
  assert_not_nil service.model
  assert_instance_of String, service.model
  refute_empty service.model
end
```

---

### Lesson 27: Speed Profile Categorization

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

### Lesson 27: Explicit Parameters in from_h Methods

**Problem:** `from_h` methods that accept a generic hash parameter hide their dependencies and make it unclear what data is required for deserialization.

**Bad Pattern:**
```ruby
# ❌ BAD: Generic hash parameter hides requirements
class AgentConfig
  def self.from_h(hash)
    # What keys does hash need? Unclear!
    capabilities = hash[:capabilities]
    environment = hash[:environment]
    
    new(
      capabilities: capabilities,
      environment: environment
    )
  end
end

# Calling code has no idea what's required
config = AgentConfig.from_h(some_hash)  # What does some_hash need?
```

**Good Pattern:**
```ruby
# ✅ GOOD: Explicit parameters document requirements
class AgentConfig
  def self.from_h(capabilities:, environment:)
    capabilities_objects = capabilities.transform_keys(&:to_sym).transform_values do |cap_hash|
      CapabilityConfig.from_h(**cap_hash)
    end
    
    new(
      capabilities: capabilities_objects,
      environment: environment
    )
  end
end

# Calling code is explicit
config = AgentConfig.from_h(
  capabilities: { general_llm: {...} },
  environment: { "API_KEY" => "..." }
)
```

**Key Principles:**
1. **Explicit parameters** - Every required field is a named parameter
2. **No hash unpacking** - Don't accept generic `hash` then extract keys
3. **Self-documenting** - Method signature shows exactly what's needed
4. **Fail fast** - Missing parameters raise `ArgumentError` immediately
5. **Consistent with initialize** - Same parameter names as constructor

**Why This Matters:**
- **Clear contracts** - Method signature documents dependencies
- **Better errors** - Ruby raises ArgumentError with parameter name
- **No silent nils** - Can't accidentally pass wrong hash structure
- **IDE support** - Autocomplete knows parameter names
- **Refactoring safety** - Changing requirements breaks at call sites

**Migration Strategy:**
```ruby
# Before: Hidden requirements
def self.from_h(hash)
  new(name: hash[:name], value: hash[:value])
end

# After: Explicit requirements  
def self.from_h(name:, value:)
  new(name: name, value: value)
end

# Update call sites from:
Thing.from_h(hash)

# To:
Thing.from_h(**hash)  # Splat operator unpacks hash to keyword args
```

---

### Lesson 28: No Defensive Validation in Constructors

**Problem:** Constructors with defensive type checking create duplicate validation logic and hide architectural issues.

**Bad Pattern:**
```ruby
# ❌ BAD: Defensive validation in constructor
class AgentConfig
  def initialize(capabilities:, environment:)
    # Checking types of everything
    raise ArgumentError, "capabilities must be a Hash" unless capabilities.is_a?(Hash)
    
    capabilities.each do |name, config|
      raise ArgumentError, "keys must be Symbols" unless name.is_a?(Symbol)
      raise TypeError, "values must be CapabilityConfig" unless config.is_a?(CapabilityConfig)
    end
    
    raise ArgumentError, "environment must be a Hash" unless environment.is_a?(Hash)
    
    @capabilities = capabilities
    @environment = environment
  end
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Trust your types, let it fail naturally
class AgentConfig
  def initialize(capabilities:, environment:)
    @capabilities = capabilities
    @environment = environment
  end
end

# If wrong types are passed, Ruby's NoMethodError tells you immediately:
# - capabilities.transform_values -> NoMethodError if not a Hash
# - environment["KEY"] -> NoMethodError if not a Hash
```

**Key Principles:**
1. **Required parameters enforce presence** - Keyword args without defaults
2. **Duck typing** - If it quacks like a hash, use it as a hash
3. **Fail naturally** - NoMethodError is clear enough
4. **No redundant checks** - Type checking is waste when callers are correct
5. **Constructor is lightweight** - Just assign instance variables

**When to Validate in Constructors:**
- ✅ Business rules (e.g., "age must be >= 18")
- ✅ Enum values (e.g., "status must be :active, :inactive, or :suspended")
- ✅ Format requirements (e.g., "email must match pattern")
- ❌ Type checking (let NoMethodError handle it)
- ❌ Nil checks (use required parameters)
- ❌ Collection element types (let iteration fail naturally)

**Why This Matters:**
- **Simpler code** - 3 lines instead of 15
- **Better performance** - No runtime type checking
- **Clear errors** - NoMethodError shows exact problem
- **Forces proper usage** - Callers can't be lazy

---

### Lesson 29: Delete Tests for Removed Validation

**Problem:** When removing defensive validation from code, tests that verify the validation continue to fail and clutter the test suite.

**Bad Pattern:**
```ruby
# Code: Removed defensive validation
class AgentConfig
  def initialize(capabilities:, environment:)
    @capabilities = capabilities  # No type check
    @environment = environment
  end
end

# Test: Still expects the removed validation
test "validates capabilities must be a Hash" do
  error = assert_raises(ArgumentError) do
    AgentConfig.new(capabilities: "not a hash", environment: {})
  end
  assert_match(/capabilities must be a Hash/, error.message)
end
# TEST FAILS - No ArgumentError is raised anymore!
```

**Good Pattern:**
```ruby
# Code: Trust types
class AgentConfig
  def initialize(capabilities:, environment:)
    @capabilities = capabilities
    @environment = environment
  end
end

# Test: DELETE defensive validation tests entirely
# (No test needed - if wrong type is passed, NoMethodError will occur naturally)

# Keep tests that verify BEHAVIOR
test "stores capabilities and environment" do
  config = AgentConfig.new(
    capabilities: { llm: cap_object },
    environment: { "KEY" => "value" }
  )
  
  assert_equal cap_object, config.capability(:llm)
  assert_equal({ "KEY" => "value" }, config.environment)
end
```

**Key Principles:**
1. **Delete validation tests** - When removing validation, delete its tests
2. **Test behavior, not validation** - Focus on what the class DOES
3. **Trust types** - Don't test that wrong types raise errors
4. **Keep integration tests** - Ensure full workflows work correctly
5. **Update test counts** - Expect fewer tests after cleanup

**Types of Tests to Delete:**
- ❌ "validates X must be a Y"
- ❌ "validates X keys must be Symbols"
- ❌ "validates X must not be nil"
- ❌ "raises TypeError for invalid X"
- ✅ Keep: "serializes correctly"
- ✅ Keep: "returns correct values"
- ✅ Keep: "workflow completes successfully"

**Why This Matters:**
- **Honest test suite** - Tests match actual code behavior
- **Faster tests** - Fewer unnecessary validation tests
- **Clear intent** - Tests show what matters, not what doesn't
- **No false failures** - Tests don't expect removed validation

---

### Lesson 31: No Type Branching - Expect One Type

**Problem:** Methods that accept "anything" and branch on type checks are defensive, complex, and hide contract violations.

**Bad Pattern:**
```ruby
# ❌ BAD: Type checking and branching
def self.from_section_data(data, source:)
  if data.is_a?(Array)
    data.each do |entry_data|
      if entry_data.is_a?(Entry)
        context.add_entry(entry_data)
      elsif entry_data.is_a?(Hash)
        entry = Entry.from_h(entry_data)
        context.add_entry(entry)
      else
        context.add(content: entry_data.to_s, topics: [], source: source)
      end
    end
  elsif data.is_a?(Hash)
    # Handle hash...
  end
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Expect ONE type, fail if wrong
def self.from_section_data(entries, source:)
  # entries is an Array of Entry objects, period
  context = new
  entries.each { |entry| context.add_entry(entry) }
  context
end

# If caller passes wrong type, they get clear NoMethodError
```

**Key Principles:**
1. **One type per parameter** - Method accepts Entry objects, not "data"
2. **No type checking** - No `is_a?`, `kind_of?`, `respond_to?`
3. **No fallbacks** - Don't try to "fix" bad input
4. **Fail loudly** - Let NoMethodError reveal contract violation
5. **Document expectations** - Method name and parameters show what's expected

**When You're Tempted to Type Check:**
```ruby
# ❌ Temptation: "What if they pass a Hash?"
if data.is_a?(Hash)
  # handle hash
end

# ✅ Solution: Don't accept Hash! Fix the caller to pass proper type
def process_entries(entries)  # Array of Entry objects
  entries.each { |entry| entry.process }
end
```

**Why This Matters:**
- **Clear contracts** - Method signature documents exactly what's expected
- **Fail fast** - Errors happen at call site, not deep in method
- **Simpler code** - No branching, no type checks
- **Forces proper usage** - Callers must create proper objects
- **Better errors** - NoMethodError shows exactly what method was called on what type

**Migration Strategy:**
1. Identify methods with type checking
2. Determine what type SHOULD be passed
3. Remove all type checks and branches
4. Update callers to pass correct type
5. Let tests fail with NoMethodError
6. Fix callers, not the method

**Example:**
```ruby
# Before: Accepts anything
def add_items(items)
  items.each do |item|
    if item.is_a?(String)
      add_string_item(item)
    elsif item.is_a?(Hash)
      add_hash_item(item)
    else
      add_object_item(item)
    end
  end
end

# After: Expects one thing
def add_items(items)
  # items is Array<Item>, call methods on them
  items.each { |item| item.add_to(self) }
end
```

---

### Lesson 30: Pass Objects, Not Primitives

**Problem:** Converting objects to strings or primitives to pass between methods loses type information and forces consumers to reconstruct or guess structure.

**Bad Pattern:**
```ruby
# ❌ BAD: Converting to string, losing all structure
def self.from_section_data(data, source:)
  if data.is_a?(Array)
    context = new
    data.each { |entry_data| context.add(content: entry_data.to_s, topics: [], source: source) }
    return context
  end
end

# ❌ BAD: Passing hashes instead of objects
def process_user(user_hash)
  name = user_hash[:name]
  email = user_hash[:email]
  # Now we have to know the hash structure everywhere
end
```

**Good Pattern:**
```ruby
# ✅ GOOD: Pass proper objects, let them handle themselves
def self.from_section_data(data, source:)
  if data.is_a?(Array)
    context = new
    data.each do |entry|
      # entry is already an Entry object or can be deserialized to one
      context.add_entry(entry)
    end
    return context
  end
end

# ✅ GOOD: Accept objects, call methods on them
def process_user(user)
  # user is a User object with methods
  send_email(user.name, user.email)
  user.mark_processed!
end
```

**Key Principles:**
1. **Objects carry behavior** - Strings are just data, objects have methods
2. **Type safety** - Objects enforce their own invariants
3. **Easier refactoring** - Change object internals without changing callers
4. **Self-documenting** - Method signatures show what type is expected
5. **No reconstruction** - Don't serialize just to deserialize again

**When to Convert to Primitives:**
- ✅ At system boundaries (JSON API responses, database storage)
- ✅ For display/logging only
- ✅ When storing in external systems
- ❌ NOT for passing between internal methods
- ❌ NOT for temporary convenience
- ❌ NOT to avoid thinking about types

**Why This Matters:**
- **Type errors caught early** - NoMethodError reveals contract violations
- **No data loss** - Objects preserve all information and relationships
- **Clearer contracts** - Method signature documents expectations
- **Better encapsulation** - Objects hide implementation details

**Example Flow:**
```ruby
# BAD: Converting between types unnecessarily
entry = Entry.new(content: "text", topics: ["a"], source: "test")
entry_string = entry.content  # Convert to string
context.add(content: entry_string, topics: [], source: "unknown")  # Lost topics!

# GOOD: Pass the object
entry = Entry.new(content: "text", topics: ["a"], source: "test")
context.add_entry(entry)  # Preserves everything
```

---

## Lesson 32: Never Default Context to Hash - Always Require Proper Objects

**Problem:** Allowing `context: {}` as a default parameter encourages passing raw hashes instead of proper context objects, violating type safety.

**Solution:** Always require context as a parameter with NO default value. Context must be a proper `Contexts::BaseContext` subclass.

### ❌ BAD: Optional hash context

```ruby
class BaseWorker
  def initialize(goal:, path:, context: {})
    @context = context || {}  # Defensive nil check, allows hash
  end
end

# Callers can pass anything or nothing
worker = BaseWorker.new(goal: "task", path: "/path")  # No context
worker = BaseWorker.new(goal: "task", path: "/path", context: { foo: "bar" })  # Raw hash
```

**Problems:**
- No type safety - accepts hashes, nils, or any object
- Encourages lazy coding - "just pass an empty hash"
- Defensive `|| {}` check hides bugs
- No clear contract for what context should contain

### ✅ GOOD: Required context object

```ruby
class BaseWorker
  def initialize(goal:, path:, context:)
    raise TypeError, "context must be a Contexts::BaseContext, got #{context.class}" unless context.is_a?(Contexts::BaseContext)
    @context = context
  end
end

# Callers MUST create proper context
context = Contexts::BaseContext.new
worker = BaseWorker.new(goal: "task", path: "/path", context: context)

# Fails fast if wrong type passed
worker = BaseWorker.new(goal: "task", path: "/path", context: {})
# => TypeError: context must be a Contexts::BaseContext, got Hash
```

### Configuration Objects Over Hash Parameters

**Problem:** Passing configuration as hashes with individual keyword arguments creates ambiguity and allows invalid combinations.

**Solution:** Create a dedicated Config class that validates all parameters together.

#### ❌ BAD: Individual config parameters with defaults

```ruby
class SisyphusWorker
  def initialize(execution_plan:, path:, context: {}, approval_mode: :autonomous, max_retries: 3, stream_progress: true, error_mode: :lenient, dry_run: false)
    @approval_mode = approval_mode
    @max_retries = max_retries
    # ... lots of instance variables
  end
end

# OR with hash config (also bad)
def initialize(execution_plan:, path:, context: {}, config: {})
  @config = build_config(config)  # Merges defaults, filters keys
end
```

**Problems:**
- Too many parameters (7+ is a code smell)
- Default values hide required configuration
- Validation scattered or missing
- Hash configs need defensive merging/filtering
- Can't freeze configuration
- No single place to validate parameter combinations

#### ✅ GOOD: Dedicated Config class with explicit parameters

```ruby
class SisyphusWorker < BaseWorker
  class Config
    attr_reader :approval_mode, :max_retries, :stream_progress, :error_mode, :dry_run

    def initialize(approval_mode:, max_retries:, stream_progress:, error_mode:, dry_run:)
      raise ArgumentError, "approval_mode must be one of #{APPROVAL_MODES}" unless APPROVAL_MODES.include?(approval_mode)
      raise ArgumentError, "max_retries must be positive" unless max_retries.positive?
      raise ArgumentError, "error_mode must be :lenient or :strict" unless [:lenient, :strict].include?(error_mode)

      @approval_mode = approval_mode
      @max_retries = max_retries
      @stream_progress = stream_progress
      @error_mode = error_mode
      @dry_run = dry_run
      freeze
    end

    def to_h
      {
        approval_mode: @approval_mode,
        max_retries: @max_retries,
        stream_progress: @stream_progress,
        error_mode: @error_mode,
        dry_run: @dry_run
      }
    end
  end

  DEFAULT_CONFIG = Config.new(
    approval_mode: :autonomous,
    max_retries: 3,
    stream_progress: true,
    error_mode: :lenient,
    dry_run: false
  ).freeze

  def initialize(execution_plan:, path:, context:, config: DEFAULT_CONFIG)
    raise TypeError, "context must be a Contexts::BaseContext, got #{context.class}" unless context.is_a?(Contexts::BaseContext)
    raise TypeError, "config must be a SisyphusWorker::Config, got #{config.class}" unless config.is_a?(Config)
    
    super(goal: execution_plan.goal, path: path, context: context)
    @config = config
  end

  # Use config object properties directly
  def some_method
    return unless @config.stream_progress
    retry_count = @config.max_retries
  end
end

# Usage
config = SisyphusWorker::Config.new(
  approval_mode: :step,
  max_retries: 5,
  stream_progress: true,
  error_mode: :strict,
  dry_run: false
)
worker = SisyphusWorker.new(
  execution_plan: plan,
  path: "/path",
  context: context,
  config: config
)

# Or use default
worker = SisyphusWorker.new(
  execution_plan: plan,
  path: "/path",
  context: context
)  # Uses DEFAULT_CONFIG
```

**Benefits:**
- **Single validation point** - All config validation in one place
- **Frozen immutability** - Config can't be accidentally modified
- **Clear API** - Config class documents all options
- **Type safety** - Constructor validates types and values together
- **No defensive code** - No merging, filtering, or nil checks needed
- **Explicit defaults** - DEFAULT_CONFIG constant is clear and reusable
- **Clean worker code** - Worker just validates config type, no parameter sprawl

**Key Principles:**
1. **Never default context to hash or nil** - Always require proper objects
2. **Type check immediately** - Fail fast in constructor
3. **No defensive nil checks** - If parameter is required, don't check for nil
4. **Configuration as objects** - Not hashes, not individual parameters
5. **Validate in config constructor** - Not in worker code
6. **Freeze config objects** - Make them immutable
7. **One DEFAULT_CONFIG constant** - Not scattered default values

**Apply This To:**
- ✅ ALL Worker classes (BaseWorker, SisyphusWorker, DaedalusWorker, AgentWorker)
- ✅ ALL Workflow classes
- ✅ ANY class that accepts context as a parameter
- ✅ ANY class with 4+ configuration parameters

**Why This Matters:**
- **Catches bugs at call site** - Missing context fails immediately
- **Forces proper design** - Callers must think about context needs
- **No ambiguity** - Clear what type is expected
- **Fail fast** - TypeError on wrong type, not mysterious bugs later
- **Self-documenting** - Method signature shows context is required
- **Configuration as first-class objects** - Not scattered parameters or hashes

---

### Lesson 33: Domain Objects Must Have ID Properties

**Problem:** Using arbitrary attributes (like `project_name`, `goal`, or `created_at`) as identifiers creates ambiguity and makes objects harder to track and reference.

**Solution:** Every domain object should have an explicit `id` property that serves as its unique identifier.

#### ❌ BAD: Using other attributes as identifiers

```ruby
# ❌ BAD: Using project_name as identifier
@execution_record = Execution::ExecutionRecord.new(
  plan_id: @execution_plan.project_name || "execution_#{Time.now.to_i}",
  step_results: [],
  started_at: Time.now.utc.iso8601,
  status: :running
)

# ❌ BAD: No clear way to reference this record
log_execution(@execution_record.plan_id)  # Is this the plan's ID or the record's ID?
```

#### ✅ GOOD: Explicit id property on all domain objects

```ruby
# ✅ GOOD: Use proper id properties
class Planning::Result
  attr_reader :id, :goal, :project_name, :milestones
  
  def initialize(goal:, project_name:, milestones:, ...)
    @id = SecureRandom.uuid  # Every instance has unique ID
    @goal = goal
    @project_name = project_name
    @milestones = milestones
  end
end

class Execution::ExecutionRecord
  attr_reader :id, :plan_id, :step_results
  
  def initialize(plan_id:, step_results:, started_at:, status:)
    @id = SecureRandom.uuid  # Record has its own ID
    @plan_id = plan_id        # References the plan's ID
    @step_results = step_results
  end
end

# Usage: Clear relationships
@execution_record = Execution::ExecutionRecord.new(
  plan_id: @execution_plan.id,  # Use the plan's actual ID
  step_results: [],
  started_at: Time.now.utc.iso8601,
  status: :running
)

# Clear what we're referencing
log_execution(record_id: @execution_record.id, plan_id: @execution_plan.id)
```

**Key Principles:**
1. **Every domain object gets an ID** - Use `SecureRandom.uuid` in constructor
2. **ID is immutable** - Set once, never changes
3. **Use IDs for relationships** - `plan_id` references `Plan.id`, not `plan.project_name`
4. **Expose via attr_reader** - Make ID accessible but not writable
5. **Include in serialization** - `to_h` should include `id`, `from_h` should restore it

**Benefits:**
- **Clear relationships** - Foreign keys point to actual IDs
- **Easy tracking** - Every object can be uniquely identified in logs
- **Better debugging** - "ExecutionRecord abc123" is clearer than "ExecutionRecord for calculator_logging"
- **Database-ready** - IDs match database primary key patterns
- **No ambiguity** - ID is always the identifier, never something else

**Apply To:**
- ✅ All model classes (Planning::Result, Planning::Milestone, Planning::Step)
- ✅ All workflow execution classes (ExecutionRecord, StepResult)
- ✅ All memory classes (Decision, StateTransition, Error)
- ✅ Any object that needs to be referenced or tracked

---

### Lesson 34: from_h Requires ID - Constructors May Default It

**Problem:** Confusion about when `id` should be required vs. optional leads to inconsistent object creation patterns.

**Solution:** `from_h` methods always require `id` because they're hydrating existing objects. Constructors for new objects can have `id` as optional with a default.

#### ❌ BAD: from_h allows missing id

```ruby
# ❌ BAD: from_h tries to generate new ID if missing
class Planning::Result
  def self.from_h(hash)
    id = hash[:id] || hash["id"] || SecureRandom.uuid  # WRONG!
    new(id: id, goal: hash[:goal], ...)
  end
end
```

#### ✅ GOOD: from_h requires id, constructor defaults it

```ruby
# ✅ GOOD: Clear distinction between creation and hydration
class Planning::Result
  attr_reader :id, :goal, :project_name
  
  def initialize(goal:, project_name:, milestones:, id: SecureRandom.uuid)
    @id = id  # Optional for NEW objects
    @goal = goal
    @project_name = project_name
    @milestones = milestones
  end
  
  def self.from_h(id:, goal:, project_name:, milestones:, **rest)
    # id is REQUIRED - we're hydrating an existing object
    new(
      id: id,
      goal: goal,
      project_name: project_name,
      milestones: milestones.map { |m| Milestone.from_h(**m) }
    )
  end
end

# Usage
new_result = Planning::Result.new(goal: "Build X", ...)  # Gets new UUID
existing = Planning::Result.from_h(id: "abc123", goal: "Build X", ...)  # Uses provided ID
```

**Key Principles:**
1. **`from_h` always requires `id`** - Hydrating existing objects must preserve identity
2. **Constructor can default `id`** - New objects get fresh UUIDs automatically
3. **Use keyword arguments** - Make requirements explicit
4. **No fallbacks in from_h** - Don't hide missing data with defaults
5. **Deep symbolize keys before calling** - Caller responsibility: `from_h(**hash.deep_symbolize_keys)`

**Why This Matters:**
- **Clear intent** - Creation vs. hydration are distinct operations
- **Data integrity** - Existing objects keep their IDs
- **No confusion** - Method signature shows what's required
- **Fail fast** - Missing ID raises ArgumentError immediately

---

### Lesson 35: Shadow Commit Log Pattern

**Problem:** Workflow memory files being tracked by Git causes unnecessary checkpoint creation on every memory update, creating noise in Git history.

**Solution:** Use `.gitignore` to exclude workflow memory and state files, creating a "shadow commit log" where checkpoints only track actual codebase changes.

#### ❌ BAD: Memory files tracked by Git

```ruby
# .gitignore doesn't exclude memory files
# Result: Every workflow state update creates a Git change

# CheckpointService sees this as a codebase change:
def has_uncommitted_changes?
  `git diff --quiet`
  !$?.success?  # Returns true when memory file updated
end
```

**Problems:**
- Memory updates trigger checkpoint creation
- Git history cluttered with memory file commits
- Checkpoint != actual code change
- Tests create hundreds of meaningless checkpoints

#### ✅ GOOD: Gitignore memory files (shadow commit log)

```gitignore
# .gitignore
# Workflow memory and state files (shadow commit log)
*_memory.json
sisyphus_memory.json
workflow_memory.json
research_memory.json
**/state/*.json
**/workflows/**/*.json
```

```ruby
# CheckpointService only tracks REAL codebase changes
def has_uncommitted_changes?
  # Only checks tracked files - ignores gitignored memory files
  result = `git diff HEAD --quiet`
  !$?.success?
end

def current_checkpoint_id
  # Return current HEAD if no tracked changes
  return @current_checkpoint.id unless has_uncommitted_changes?
  
  # Create checkpoint ONLY for actual code changes
  create_checkpoint("Code changes detected")
end
```

**Key Principles:**
1. **Memory files are gitignored** - Workflow state doesn't pollute Git
2. **Checkpoints track code only** - Use `git diff HEAD` for tracked files
3. **Always have a checkpoint** - HEAD is always valid
4. **Create checkpoints on demand** - Only when tracked files change
5. **Test repos need .gitignore** - Include in `create_temp_git_repo` helper

**Implementation:**
```ruby
# test/test_helper.rb
def create_temp_git_repo
  dir = Dir.mktmpdir
  Dir.chdir(dir) do
    system("git init", out: File::NULL)
    system("git config user.email 'test@example.com'", out: File::NULL)
    system("git config user.name 'Test User'", out: File::NULL)
    
    # Create .gitignore for shadow commit log
    File.write(".gitignore", <<~GITIGNORE)
      *_memory.json
      sisyphus_memory.json
      workflow_memory.json
      **/state/*.json
      **/workflows/**/*.json
    GITIGNORE
    
    FileUtils.touch("README.md")
    system("git add .", out: File::NULL)
    system("git commit -m 'Initial commit'", out: File::NULL)
  end
  dir
end
```

**Why This Matters:**
- **Clean Git history** - Only code changes create commits
- **Correct semantics** - Checkpoint means "code changed", not "memory updated"
- **Fewer checkpoints** - No checkpoint spam from memory operations
- **Faster tests** - Don't create unnecessary Git commits

---

### Lesson 36: File Existence Determines Initialization Strategy

**Problem:** Complex logic trying to handle both new and existing objects in the same initialization path creates confusion and bugs.

**Solution:** Check if persistence file exists. If yes, load from disk. If no, initialize fresh. Never mix the two.

#### ❌ BAD: Mixed initialization strategies

```ruby
# ❌ BAD: Trying to be clever with fallbacks
def initialize(owner_id:, workflow_id:, workflow_name:, path:)
  @path = path
  @sections = load_sections || DEFAULT_SECTIONS rescue deep_dup(DEFAULT_SECTIONS)
  # Confusing! Which path are we on?
end

def load_sections
  return nil unless File.exist?(@path)
  data = JSON.parse(File.read(@path))
  deserialize_sections(data[:sections])
rescue
  nil  # Silent failure!
end
```

#### ✅ GOOD: Clear file-based branching

```ruby
# ✅ GOOD: Explicit branching based on file existence
def initialize(owner_id:, workflow_id:, workflow_name:, path:, parent_memory: nil)
  @owner_id = owner_id
  @workflow_id = workflow_id
  @workflow_name = workflow_name
  @parent_memory = parent_memory
  @path = path
  
  if File.exist?(path) && File.size(path) > 0
    # Load existing data from disk
    data = JSON.parse(File.read(path), symbolize_names: true)
    @started_at = Time.parse(data[:started_at])
    @last_transition_at = Time.parse(data[:last_transition_at])
    @sections = {
      state_transitions: self.class.deserialize_array(
        data: data[:sections][:state_transitions],
        klass: WorkflowMemories::StateTransition
      ),
      # ... other sections
    }
  else
    # Initialize fresh
    @sections = deep_dup(DEFAULT_SECTIONS)
    @started_at = Time.now.utc
    @last_transition_at = Time.now.utc
  end
end

# from_h is for explicit deserialization with ALL data
def self.from_h(owner_id:, workflow_id:, workflow_name:, path:, sections:, started_at:, last_transition_at:)
  store = allocate
  # Set all instance variables explicitly
  store.instance_variable_set(:@owner_id, owner_id)
  store.instance_variable_set(:@started_at, Time.parse(started_at))
  store.instance_variable_set(:@sections, deserialize_sections(sections))
  store
end
```

**Key Principles:**
1. **Check file existence explicitly** - `File.exist?(path) && File.size(path) > 0`
2. **Two clear branches** - Load existing OR initialize fresh, never both
3. **No rescue fallbacks** - Let errors bubble up
4. **from_h is different** - Used when you have full data already in memory
5. **No complex helper methods** - Inline the logic for clarity

**Why This Matters:**
- **Predictable behavior** - Clear which path is taken
- **No silent failures** - Errors reveal problems immediately
- **Easier debugging** - Can follow exact execution path
- **Proper separation** - File loading vs. memory deserialization are distinct

---

### Lesson 37: deserialize_array Must Be a Class Method When Used in Initialization

**Problem:** Calling instance methods from `initialize` before the instance is fully set up can fail, especially when using `allocate` pattern.

**Solution:** Make deserialization methods class methods so they can be called during initialization without instance context.

#### ❌ BAD: Private instance method called during init

```ruby
# ❌ BAD: Instance method used in initialization
class WorkflowMemoryStore
  def initialize(path:, ...)
    if File.exist?(path)
      data = load_data(path)
      @sections = deserialize_sections(data)  # Calling instance method during init
    end
  end
  
  private
  
  def deserialize_sections(data)
    # What if this needs other instance vars that aren't set yet?
  end
end
```

#### ✅ GOOD: Class method for deserialization

```ruby
# ✅ GOOD: Class method can be called anytime
class WorkflowMemoryStore
  def initialize(path:, ...)
    if File.exist?(path)
      data = load_data(path)
      # Call class method - no instance context needed
      @sections = {
        state_transitions: self.class.deserialize_array(
          data: data[:state_transitions],
          klass: WorkflowMemories::StateTransition
        )
      }
    end
  end
  
  # Class method - stateless, works anywhere
  def self.deserialize_array(data:, klass:)
    data.map { |hash| klass.from_h(**hash.deep_symbolize_keys) }
  end
end

# from_h can also use it
def self.from_h(sections:, ...)
  store = allocate
  deserialized = {
    state_transitions: WorkflowMemoryStore.deserialize_array(
      data: sections[:state_transitions],
      klass: WorkflowMemories::StateTransition
    )
  }
  store.instance_variable_set(:@sections, deserialized)
  store
end
```

**Key Principles:**
1. **Deserialize methods are class methods** - No instance state needed
2. **Use explicit keyword arguments** - `data:` and `klass:` are clear
3. **Call with self.class or ClassName** - Works from instance or class context
4. **Stateless operations** - Pure transformation of data

**Why This Matters:**
- **Works in all contexts** - Initialize, from_h, anywhere
- **No instance dependencies** - Pure data transformation
- **allocate pattern compatible** - Can set instance vars in any order
- **Reusable** - One implementation for all deserialization needs

---

### Lesson 38: No Safety Checks in Deserialization - Clean Up Old Data

**Problem:** Adding safety checks to handle old or malformed data hides the real problem and prevents proper data migrations.

**Solution:** Remove all safety checks. If deserialization fails, fix the source data, don't work around it.

#### ❌ BAD: Defensive deserialization

```ruby
# ❌ BAD: Trying to handle every possible data format
def self.deserialize_array(data:, klass:)
  return [] if data.nil?  # WRONG!
  return [] unless data.is_a?(Array)  # WRONG!
  
  data&.map do |item|  # WRONG!
    if item.is_a?(klass)
      item
    elsif item.is_a?(Hash)
      klass.from_h(item.deep_symbolize_keys)
    else
      nil
    end
  end.compact  # Hiding failures!
end
```

**Problems:**
- Hides data quality issues
- Returns partial data silently
- Makes debugging impossible
- Prevents proper data migration

#### ✅ GOOD: Fail fast, fix data

```ruby
# ✅ GOOD: Expect correct format, fail if wrong
def self.deserialize_array(data:, klass:)
  # No safety checks - data must be correct
  data.map { |hash| klass.from_h(**hash.deep_symbolize_keys) }
  # If this fails:
  # - NoMethodError -> data isn't an array
  # - ArgumentError -> hash missing required keys
  # Both are GOOD - they tell you exactly what's wrong
end

# When errors occur:
# 1. Check test/production data directories
# 2. Delete old incompatible files
# 3. Run migrations if needed
# 4. Don't add safety checks to hide the problem
```

**How to Fix Old Data:**
```bash
# Find and delete old state files with wrong format
rm -rf .agents/state/*
rm -rf test/tmp/*

# Or write a migration script if data must be preserved
ruby scripts/migrate_workflow_memory_v1_to_v2.rb
```

**Key Principles:**
1. **No `data&.map`** - Use required keyword args instead
2. **No nil checks** - If data is required, enforce it
3. **No type branching** - Expect one format
4. **No rescue blocks** - Let errors surface
5. **Clean up old data** - Don't code around it

**Why This Matters:**
- **Real errors surface** - Know exactly what's wrong
- **Forces proper migrations** - Handle data changes correctly
- **Simpler code** - No defensive complexity
- **Honest failures** - Tests fail with real problems, not hidden issues

---

## Lesson 46: Always Use ENV.fetch() - No Fallback Defaults

**Problem**: Using `ENV["KEY"] || default_value` silently hides configuration errors and makes debugging harder.

**Bad**:
```ruby
def base_path
  ENV["AGENT_DATA_PATH"] || File.join(".agents", "state")
end
```

**Good**:
```ruby
def base_path
  ENV.fetch("AGENT_DATA_PATH")
end
```

**Why This Matters:**
- **Fail fast** - Missing ENV vars are caught immediately, not at runtime
- **Explicit contracts** - `.env.test` MUST define all required variables
- **No silent failures** - Know exactly when configuration is wrong
- **Test integrity** - Tests fail loudly if `.env.test` isn't loaded

**Rule**: ALL environment variable access must use `ENV.fetch("KEY")` with NO default fallback. The `.env.test` file must define all variables needed for tests.

---

## Lesson 45: Tests Should Never Set ENV Variables - Use .env.test

**Problem**: Tests that manually set `ENV` variables create brittle, environment-dependent tests that can interfere with each other in parallel execution.

**Bad**:
```ruby
test "some behavior" do
  ENV["AGENT_STATE_PATH"] = temp_dir
  # ... test code ...
ensure
  ENV.delete("AGENT_STATE_PATH")
end
```

**Good**:
```ruby
# .env.test (auto-loaded during test execution)
AGENT_DATA_PATH=tmp/test_agent_data
AGENT_STATE_PATH=tmp/test_state

# test
test "some behavior" do
  # ENV is already configured correctly
  # ... test code ...
end
```

**Why This Matters:**
- **Parallel safety** - ENV modifications can leak between parallel tests
- **Single source of truth** - All test config in .env.test
- **Simpler tests** - No setup/teardown for ENV
- **Production parity** - Tests use same ENV pattern as production

**Rule**: Tests should NEVER set ENV variables. If a test needs specific config, it should be:
1. **Added to .env.test** for test-wide defaults
2. **Passed as parameters** to the class/method under test

---

## References

- [Serialization Guide](./serialization-guide.md)
- SOLID Principles
- Ruby Style Guide
- Domain-Driven Design patterns