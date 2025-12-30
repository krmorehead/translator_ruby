# Tool Configuration Pattern

## Core Principle
**Push configuration down to the tool class as much as possible.** Tools should be self-contained and define their own constants, schemas, and behavior. Controllers, services, and tests should remain ignorant of tool-specific configuration.

## Rules

### 1. Tool Classes Own Their Configuration
**DO:** Define constants at the class level
```ruby
class MemoryTool < BaseTool
  DEFAULT_FILENAME = "memory.json"
  PATH = File.join("tmp", "dnd_chat_sandbox", DEFAULT_FILENAME)
  NAME = "memory".freeze
  OP_UPDATE = "update_section".freeze
  OP_GET = "get_section".freeze
  OP_LIST = "list_sections".freeze
end
```

**DON'T:** Define tool configuration in controllers or services
```ruby
# BAD - Controller knows about tool paths
class DndChatController
  MEMORY_PATH = "tmp/dnd_chat_sandbox/memory.json"
  
  def normalize_tool_arguments(payload)
    args[:path] ||= MEMORY_PATH if tool == "memory"
  end
end
```

### 2. No Default Arguments in execute Methods
**DO:** Require all arguments explicitly
```ruby
def execute(operation:, section:, content:, append:, path:)
  # All arguments are required - no defaults
end
```

**DON'T:** Use default values in method signatures
```ruby
# BAD - Defaults hide configuration
def execute(operation: OP_UPDATE, path: PATH, section: nil, content: nil, append: true)
end
```

**WHY:** Default arguments in method signatures create hidden behavior. If a default is needed, handle it in the normalize/resolution logic inside the method where it's explicit and testable.

### 3. Callers Must Provide Explicit Arguments
**DO:** Tests and callers supply all required arguments
```ruby
# Test explicitly provides path
test "add item creates inventory file" do
  inv_path = File.join(@sandbox_path, "inventory.json")
  result = @tool.execute(
    operation: InventoryTool::OP_ADD_ITEM,
    path: inv_path,
    name: "Torch",
    weight: 1,
    description: "Light",
    property_type: "gear",
    quantity: 2
  )
end
```

**DON'T:** Rely on implicit defaults or helper methods to inject values
```ruby
# BAD - Test doesn't show what path is being used
test "add item creates inventory file" do
  result = @tool.execute(operation: InventoryTool::OP_ADD_ITEM, name: "Torch")
end

# BAD - Helper injects defaults
def filter_args_for(tool_name, args)
  args[:path] ||= @memory_path if tool_name == "memory"
  args[:operation] ||= "update"
end
```

### 4. Controllers Stay Ignorant of Tool Configuration
**DO:** Pass arguments through without modification
```ruby
def create_message
  payload = parse_tool_payload(llm_response)
  tool_result = tool_call_service.execute(
    tool_name: payload[:tool],
    arguments: payload[:arguments]
  )
end
```

**DON'T:** Inject tool-specific defaults in controllers
```ruby
# BAD - Controller knows memory tool details
def normalize_tool_arguments(payload)
  case payload[:tool]
  when MemoryTool::NAME
    payload[:arguments][:path] ||= MEMORY_PATH
    payload[:arguments][:append] ||= true
    payload[:arguments][:section] ||= MemoryKinds::RECENT_CONVERSATION
  end
end
```

### 5. Use Tool Constants, Not Magic Strings
**DO:** Reference tool constants
```ruby
when MemoryTool::NAME
  # ... handle memory tool
when InventoryTool::NAME
  # ... handle inventory tool
```

**DON'T:** Use string literals
```ruby
# BAD
when "memory"
  # ... handle memory tool
```

### 6. Tool Registration is Declarative
Tools register themselves at the bottom of their file:
```ruby
# At end of tool file
ToolCallService.register_tool(MemoryTool)
```

The service remains a dumb registry:
```ruby
class ToolCallService
  @tools = {}
  
  def self.register_tool(tool_class)
    @tools[tool_class.name_identifier] = tool_class
  end
  
  def execute(tool_name:, arguments:)
    tool_class = self.class.tool_class_for(tool_name)
    tool = tool_class.new(sandbox_path: sandbox_path)
    tool.execute(arguments)
  end
end
```

### 7. Workflows Define Their Available Tools
Workflows own which tools they use, not the service:
```ruby
class DndChatWorkflow
  AVAILABLE_TOOLS = [
    DiceRollTool,
    SkillCheckTool,
    MemoryTool,
    MemorySummarizeTool,
    InventoryTool
  ].freeze
  
  def chat_parameters
    {
      model: ENV["LLM_MODEL"],
      messages: build_messages,
      tools: AVAILABLE_TOOLS.map(&:schema),
      tool_choice: BaseTool.tool_choice
    }
  end
end
```

### 8. BaseTool Provides Common Behavior
Use inheritance for shared functionality:
```ruby
class BaseTool
  attr_reader :sandbox_path
  
  def initialize(sandbox_path: nil)
    @sandbox_path = sandbox_path
  end
  
  def self.schema
    {
      type: "function",
      function: {
        name: name_identifier,
        description: description,
        parameters: parameters_schema
      }
    }
  end
  
  def self.tool_choice
    { type: "auto" }
  end
  
    
  def success_result(result)
    { success: true, result: result }
  end
  
  def error_result(message)
    { success: false, error: message }
  end
end
```

## Testing Pattern

### Unit Tests: Use Sandbox Paths
```ruby
class MemoryToolTest < ActiveSupport::TestCase
  def setup
    @sandbox_path = Rails.root.join("test", "tool_test", "memory_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(@sandbox_path)
    @memory_path = File.join(@sandbox_path, "memory.json")
    @tool = MemoryTool.new(sandbox_path: @sandbox_path)
  end
  
  test "updates section with explicit path" do
    result = @tool.execute(
      operation: MemoryTool::OP_UPDATE,
      path: @memory_path,
      section: MemoryKinds::QUESTS,
      content: "Find the artifact",
      append: true
    )
    assert result[:success]
  end
end
```

### Integration Tests: Supply Full Arguments
```ruby
def execute_tool_response(parsed)
  tool_name = parsed["tool"]
  args = parsed["arguments"].transform_keys(&:to_sym)
  
  # Override paths to point inside test sandbox
  args[:path] = @memory_path if [MemoryTool::NAME, MemorySummarizeTool::NAME].include?(tool_name)
  args[:path] = @inventory_path if tool_name == InventoryTool::NAME
  
  ToolCallService.new(sandbox_path: @sandbox_path).execute(
    tool_name: tool_name,
    arguments: args
  )
end
```

## Benefits

1. **Single Source of Truth:** Tool configuration lives in one place - the tool class
2. **Explicit Over Implicit:** Every call shows exactly what arguments are being used
3. **Testability:** Tests are clear about what they're testing
4. **Maintainability:** Changes to tool behavior only require editing the tool class
5. **No Magic:** Controllers and services don't have hidden tool-specific logic
6. **Flexibility:** Different workflows can use different subsets of tools

## Anti-Patterns to Avoid

❌ Default values in execute method signatures  
❌ Controllers normalizing tool arguments  
❌ Tests relying on implicit defaults  
❌ Helper methods that inject configuration  
❌ Services knowing about tool-specific fields  
❌ Magic strings instead of constants  
❌ Scattered configuration across multiple files  

## Related Patterns

- See `docs/references/base_references.md` for BaseTool inheritance details
- See `docs/references/service_objects.md` for controller/service separation


