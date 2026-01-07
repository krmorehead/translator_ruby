---
description: Tool registration and plugin system patterns
globs: app/{tools,prompts,agents}/**/*.rb
alwaysApply: false
---

# Tool Registration & Plugin System

**Tags**: [architecture, design, coding]  
**Applies To**: Any system with pluggable functionality (Ruby/Rails as reference)  
**Date**: 2026-01-05

## Overview

Tool registration patterns enable flexible, plugin-based architectures where prompts/agents register only the tools they need. This approach keeps tools generic and reusable while allowing different contexts to access different capabilities.

**When to use this pattern:**
- Different agents need different tool subsets
- Tools should be reusable across multiple agents
- New tools should be addable without modifying existing code
- LLMs need to discover available tools dynamically

## Tool Registration Pattern

```
Tool Base Pattern
├── AbstractBaseTool
│   ├── Class-level: schema(), name(), description(), parameters()
│   ├── Instance-level: execute(**args) → {success, result, error}
│   └── Self-generating schemas (OpenAI/Claude compatible)
│
├── Concrete Tools (generic, reusable)
│   ├── ReadOnlyTools (safe for all agents)
│   │   ├── FileListing: List directory structure
│   │   ├── FileReader: Read file contents
│   │   └── SearchTool: Search for patterns
│   │
│   └── ModificationTools (restricted agents only)
│       ├── FileWriter: Create/modify files
│       ├── CommandExecutor: Run system commands
│       └── Context injected: Working directory, boundaries
│
└── Security Pattern
    ├── Path validation: Within allowed boundaries
    ├── No traversal: Block ../ patterns
    └── Restricted paths: .git, .env, node_modules

Prompt Registration Pattern
├── BasePromptWithTools
│   ├── initialize(tools: [])
│   ├── Stores tool collection
│   └── Serializes to LLM format
│
├── ReadOnlyAgentPrompt
│   ├── Registers: [FileListing, FileReader, SearchTool]
│   ├── Purpose: Exploration, analysis, Q&A
│   └── Security: No modification capabilities
│
├── ModificationAgentPrompt
│   ├── Registers: [FileListing, FileReader, SearchTool, FileWriter, CommandExecutor]
│   ├── Purpose: Code modification, execution
│   └── Security: Full capabilities with validation
│
└── Custom AgentPrompt
    ├── Registers: Subset based on needs
    ├── Purpose: Specific task type
    └── Principle: Least privilege

Context Injection Pattern
├── Tool Construction
│   ├── Tool initialized with context (working_dir, boundaries)
│   ├── Context NOT passed on every call
│   └── Reduces LLM token usage
│
├── LLM Sees
│   └── parameters: {path: "relative/path", content: "..."}
│
└── Tool Executes
    ├── Resolves: full_path = join(context_dir, relative_path)
    ├── Validates: full_path within allowed boundaries
    └── Executes: with full path

Multi-Turn Tool Calling Flow
1. Agent registers needed tools
2. LLM receives tool schemas
3. LLM requests tool execution
4. Agent executes tool (validates first)
5. Agent adds result to conversation
6. Loop until LLM stops requesting tools
```

---

## Rules

### [ARCH][!PROMPTS-REGISTER-TOOLS]

**Rule**: Prompts declare which tools they need at initialization, not hardcoded globally.

**Bad Example:**

```ruby
# ❌ Global tool registration - all prompts get all tools
class ToolRegistry
  GLOBAL_TOOLS = [
    FileTreeTool,
    ReadFileTool,
    GrepTool,
    WriteFileTool,    # Dangerous for read-only agents!
    BashTool,         # Dangerous for read-only agents!
    DeleteFileTool    # Dangerous for everyone!
  ]
end

class DaedalusPrompt < ToolCallPrompt
  def initialize
    @id = SecureRandom.uuid
    # Gets ALL tools including dangerous ones
    super(tools: ToolRegistry.GLOBAL_TOOLS)
  end
end

class SisyphusPrompt < ToolCallPrompt
  def initialize
    # Also gets ALL tools even if it only needs some
    super(tools: ToolRegistry.GLOBAL_TOOLS)
  end
end
```

**Good Example:**

```ruby
# ✅ Each prompt registers only the tools it needs (pass classes)
class ReadOnlyPrompt < ToolEnabledPrompt
  def initialize
    @id = SecureRandom.uuid
    # Read-only: exploration tools only
    tools = [FileTreeTool, GrepTool, ReadFileTool]
    super(tools: tools)
  end
end

class ReadWritePrompt < ToolEnabledPrompt
  def initialize
    @id = SecureRandom.uuid
    # Read + write: exploration + modification tools
    tools = [FileTreeTool, GrepTool, ReadFileTool, WriteFileTool, ShellTool]
    super(tools: tools)
  end
end
```

**Why**: Each prompt gets only the tools appropriate for its purpose. Read-only operations can't accidentally modify state. Security through least privilege.

---

### [ARCH][!GENERIC-TOOLS]

**Rule**: Keep tool implementations generic and reusable. Specialization happens at registration time, not in the tool itself.

**Bad Example:**

```ruby
# ❌ Specialized tools that duplicate logic
class DaedalusReadFileTool < BaseTool
  def execute(path:)
    # Read file logic for Daedalus
    # (exact same as Sisyphus needs)
  end
end

class SisyphusReadFileTool < BaseTool
  def execute(path:)
    # Read file logic for Sisyphus
    # (duplicated from Daedalus)
  end
end

class ResearcherReadFileTool < BaseTool
  def execute(path:)
    # Read file logic for Researcher
    # (duplicated again)
  end
end
```

**Good Example:**

```ruby
# ✅ Generic tool used by all agents
class ReadFileTool < BaseTool
  def self.name_identifier
    "read_file"
  end
  
  def self.description
    "Read the complete contents of a file at the given path"
  end
  
  def self.parameters_schema
    {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: "Path to the file to read"
        }
      },
      required: ["path"]
    }
  end
  
  def execute(path:)
    validate_path!(path)
    
    content = File.read(path)
    success_result(content)
  rescue => e
    error_result(e.message)
  end
end

# All agents register the same generic tool
class DaedalusChatPrompt < ToolCallPrompt
  extend T::Sig
  
  sig { params(path: String).void }
  def initialize(path:)
    @id = T.let(UUID.generate, UUID)
    @path = T.let(path, String)
    tools = [ReadFileTool]
    super(tools: tools)
  end
end

class SisyphusChatPrompt < ToolCallPrompt
  extend T::Sig
  
  sig { params(path: String).void }
  def initialize(path:)
    @id = T.let(UUID.generate, UUID)
    @path = T.let(path, String)
    tools = [ReadFileTool]
    super(tools: tools)
  end
end
```

**Why**: Generic tools eliminate duplication, reduce maintenance burden, and ensure consistent behavior across agents.

---

### [ARCH][!CONTEXT-INJECTION]

**Rule**: Inject context (codebase_path, working_directory) automatically in tools, not passed as parameters every time.

**Bad Example:**

```ruby
# ❌ Context passed explicitly on every call
class Sisyphus::WriteFileTool < BaseTool
  def self.parameters_schema
    {
      type: "object",
      properties: {
        codebase_path: { type: "string" },  # Repeated on every call!
        path: { type: "string" },
        content: { type: "string" }
      },
      required: ["codebase_path", "path", "content"]
    }
  end
  
  def execute(codebase_path:, path:, content:)
    full_path = File.join(codebase_path, path)
    File.write(full_path, content)
  end
end

# LLM must remember and pass codebase_path every time
{
  tool_name: "write_file",
  arguments: {
    codebase_path: "/project/path",  # Redundant!
    path: "src/app.js",
    content: "..."
  }
}
```

**Good Example:**

```ruby
# ✅ Context injected at tool creation
class Sisyphus::WriteFileTool < BaseTool
  def initialize(codebase_path:)
    @id = SecureRandom.uuid
    validate_codebase_path!(codebase_path)
    @codebase_path = codebase_path
  end
  
  def self.parameters_schema
    {
      type: "object",
      properties: {
        path: { type: "string" },
        content: { type: "string" }
      },
      required: ["path", "content"]
    }
  end
  
  def execute(path:, content:)
    full_path = resolve_path(path)
    validate_within_codebase!(full_path)
    
    File.write(full_path, content)
    success_result("Wrote #{File.size(full_path)} bytes to #{path}")
  end
  
  private
  
  def resolve_path(path)
    File.expand_path(path, @codebase_path)
  end
  
  def validate_within_codebase!(full_path)
    unless full_path.start_with?(@codebase_path)
      raise SecurityError, "Path #{full_path} is outside codebase #{@codebase_path}"
    end
  end
end

# LLM only needs path and content
{
  tool_name: "write_file",
  arguments: {
    path: "src/app.js",
    content: "..."
  }
}
```

**Why**: Context injection reduces LLM token usage, eliminates repetition, and enforces security boundaries automatically.

---

### [ARCH][!TOOL-SCHEMA-GENERATION]

**Rule**: Tools generate their own OpenAI-compatible schemas. No manual schema maintenance.

**Bad Example:**

```ruby
# ❌ Manual schema maintenance separate from tool
class ToolRegistry
  SCHEMAS = {
    read_file: {
      type: "function",
      function: {
        name: "read_file",
        description: "Read a file",  # Out of sync with tool!
        parameters: {
          type: "object",
          properties: {
            path: { type: "string" }
          },
          required: ["path"]
        }
      }
    }
  }
end

class ReadFileTool
  def execute(path:, encoding: nil)  # Added encoding parameter
    # Schema doesn't know about encoding!
  end
end
```

**Good Example:**

```ruby
# ✅ Tool generates its own schema
class ReadFileTool < BaseTool
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
  
  def self.name_identifier
    "read_file"
  end
  
  def self.description
    "Read the complete contents of a file at the given path. Supports various text encodings."
  end
  
  def self.parameters_schema
    {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: "Path to the file to read"
        },
        encoding: {
          type: "string",
          description: "File encoding (utf-8, ascii, etc.). Defaults to utf-8",
          enum: ["utf-8", "ascii", "iso-8859-1"]
        }
      },
      required: ["path"]
    }
  end
  
  def execute(path:, encoding: "utf-8")
    content = File.read(path, encoding: encoding)
    success_result(content)
  end
end

# Schema is always in sync with implementation
tools = [ReadFileTool, WriteFileTool, ShellTool]
```

**Why**: Self-generating schemas eliminate sync issues between documentation and implementation. Add a parameter once, it's automatically in the schema.

---

### [ARCH][!SAFETY-BOUNDARIES]

**Rule**: Tools validate paths and enforce safety boundaries. Don't trust LLM output.

**Bad Example:**

```ruby
# ❌ No validation - LLM can access anything
class WriteFileTool < BaseTool
  def execute(path:, content:)
    File.write(path, content)  # LLM controls full path!
    success_result("Wrote file")
  end
end

# LLM can do this:
{
  tool_name: "write_file",
  arguments: {
    path: "/etc/passwd",  # Oops!
    content: "hacked"
  }
}
```

**Good Example:**

```ruby
# ✅ Strict validation and safety boundaries
class Sisyphus::WriteFileTool < BaseTool
  def initialize(codebase_path:)
    @id = SecureRandom.uuid
    @codebase_path = File.expand_path(codebase_path)
    validate_codebase_exists!
  end
  
  def execute(path:, content:)
    validate_path_format!(path)
    
    full_path = resolve_path(path)
    validate_within_codebase!(full_path)
    validate_not_restricted!(full_path)
    
    ensure_directory_exists!(File.dirname(full_path))
    File.write(full_path, content)
    
    success_result("Wrote #{content.bytesize} bytes to #{path}")
  rescue SecurityError => e
    error_result("Security violation: #{e.message}")
  rescue => e
    error_result("Failed to write file: #{e.message}")
  end
  
  private
  
  def validate_codebase_exists!
    unless Dir.exist?(@codebase_path)
      raise ArgumentError, "Codebase path does not exist: #{@codebase_path}"
    end
  end
  
  def validate_path_format!(path)
    if path.start_with?('/')
      raise SecurityError, "Absolute paths not allowed. Use relative paths within codebase."
    end
    
    if path.include?('..')
      raise SecurityError, "Path traversal (..) not allowed"
    end
  end
  
  def resolve_path(path)
    File.expand_path(path, @codebase_path)
  end
  
  def validate_within_codebase!(full_path)
    unless full_path.start_with?(@codebase_path)
      raise SecurityError, "Path #{full_path} is outside codebase #{@codebase_path}"
    end
  end
  
  def validate_not_restricted!(full_path)
    restricted_patterns = [
      /\.git\//,
      /\.env/,
      /node_modules\//,
      /vendor\//
    ]
    
    restricted_patterns.each do |pattern|
      if full_path.match?(pattern)
        raise SecurityError, "Cannot modify restricted path: #{full_path}"
      end
    end
  end
end
```

**Why**: LLMs can make mistakes or be malicious. Tool validation enforces security boundaries regardless of LLM behavior.

---

## Patterns

### Pattern: Base Tool with Schema Generation

```ruby
class BaseTool
  # Schema generation
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
  
  # Compatibility methods
  def self.name
    name_identifier
  end
  
  # Instance delegation (OOP pattern: tools are objects)
  def name
    self.class.name_identifier
  end
  
  # Abstract methods subclasses must implement
  def self.name_identifier
    raise NotImplementedError
  end
  
  def self.description
    raise NotImplementedError
  end
  
  def self.parameters_schema
    raise NotImplementedError
  end
  
  def execute(**args)
    raise NotImplementedError
  end
  
  # Helper methods for results
  def success_result(result)
    { success: true, result: result, error: nil }
  end
  
  def error_result(error)
    { success: false, result: nil, error: error }
  end
end
```

---

### Pattern: Tool-Calling Prompt Base Class

```ruby
class ToolCallPrompt < BasePrompt
  attr_reader :tools
  
  def initialize(tools: [])
    @id = SecureRandom.uuid
    @tools = Array(tools)
    super()
  end

  # Get tool schemas for OpenAI function calling
  def tool_schemas
    @tools.map { |tool| tool.class.schema }
  end
  
  # Include tools in LLM parameters
  def build_parameters(messages)
    parameters = super(messages)
    parameters[:tools] = serialize_tools
    parameters
  end
  
  # Execute with multi-turn tool calling loop
  def execute_with_tools(user_message:, max_iterations: 20)
    messages = build_messages_with_history(user_message)
    iteration = 0
    
    loop do
      break if iteration >= max_iterations
      
      # Call LLM
      response = call_llm(messages)
      
      # Check if LLM wants to use tools
      if tool_calls_present?(response)
        # Execute each tool
        tool_results = execute_tool_calls(response[:tool_calls])
        
        # Add results to conversation
        messages += format_tool_results(tool_results)
        iteration += 1
      else
        # No more tool calls - return final response
        return response
      end
    end
    
    raise "Exceeded max iterations (#{max_iterations})"
  end
  
  protected
  
  # Subclasses must implement
  def build_messages_with_history(user_message)
    raise NotImplementedError
  end
  
  def execute_tool(name, args)
    raise NotImplementedError
  end
end
```

---

### Pattern: Prompt-Specific Tool Registration

```ruby
# Read-only agent: exploration tools only
class DaedalusChatPrompt < ToolCallPrompt
  def initialize(path:, conversation_history: [])
    @id = SecureRandom.uuid
    validate_params!(path)
    
    @path = path
    @conversation_history = conversation_history
    
    # Register only read-only tools
    tools = [FileTreeTool, GrepTool, ReadFileTool]
    
    super(tools: tools)
  end
  
  def execute_tool(name, args)
    tool = @tools.find { |t| t.name == name }
    return error_result("Unknown tool: #{name}") unless tool
    
    # Context injection happens here
    tool.new.execute(**args.merge(base_path: @base_path))
  end
  
  private
  
  def resolve_path(path)
    File.expand_path(path, @path)
  end
end

# Modification agent: exploration + modification tools
class SisyphusChatPrompt < ToolCallPrompt
  def initialize(path:, conversation_history: [])
    validate_params!(path)
    
    @path = path
    @conversation_history = conversation_history
    
    # Register exploration + modification tools
    tools = [FileTreeTool, GrepTool, ReadFileTool, WriteFileTool, ShellTool]
    
    super(tools: tools)
  end
  
  def execute_tool(name, args)
    case name
    when "file_tree", "grep", "read_file"
      # Use shared tools
      execute_shared_tool(name, args)
    tool = @tools.find { |t| t.name == name }
    return error_result("Unknown tool: #{name}") unless tool
    
    # Context injection for write operations
    tool.new.execute(**args.merge(base_path: @base_path))
  end
end
```

---

## Real-World Examples

### Example 1: Adding a New Tool

```ruby
# Step 1: Create generic tool
class DiffTool < BaseTool
  def self.name_identifier
    "diff"
  end
  
  def self.description
    "Show differences between two files or between a file and its backup"
  end
  
  def self.parameters_schema
    {
      type: "object",
      properties: {
        file1: { type: "string", description: "First file path" },
        file2: { type: "string", description: "Second file path" }
      },
      required: ["file1", "file2"]
    }
  end
  
  def execute(file1:, file2:)
    content1 = File.read(file1)
    content2 = File.read(file2)
    
    # Generate diff
    diff = generate_diff(content1, content2)
    success_result(diff)
  rescue => e
    error_result(e.message)
  end
end

# Step 2: Register in prompts that need it
class ReadWritePrompt < ToolEnabledPrompt
  def initialize
    @id = SecureRandom.uuid
    tools = [
      FileTreeTool, GrepTool, ReadFileTool,
      WriteFileTool, ShellTool,
      DiffTool  # Added!
    ]
    super(tools: tools)
    
    super(tools: tools)
  end
  
  def execute_tool(name, args)
    case name
  def execute_tool(name, args)
    tool = @tools.find { |t| t.name == name }
    return error_result("Unknown tool: #{name}") unless tool
    
    tool.new.execute(**args)
  end
end

# DaedalusChatPrompt doesn't need diff - doesn't register it
# ResearcherPrompt can choose to register it or not
```

---

## Checklist

When implementing tool registration patterns:

- [ ] Tools are generic and reusable (not agent-specific)
- [ ] Prompts register only the tools they need
- [ ] Context injected at tool creation (not passed as parameters)
- [ ] Tools generate their own OpenAI-compatible schemas
- [ ] Path validation enforces safety boundaries
- [ ] Absolute paths and path traversal (..) blocked
- [ ] Restricted paths (.git, .env, etc.) protected
- [ ] Error messages are descriptive and actionable
- [ ] Tools return standardized result format ({success, result, error})
- [ ] BaseTool defines interface all tools follow
- [ ] Tool schemas include parameter descriptions
- [ ] New tools can be added without modifying existing code

---

## Summary

**Key Principles:**

1. **Prompts register tools** they need at initialization
2. **Tools are generic** and reusable across agents
3. **Context injection** reduces repetition and enforces security
4. **Self-generating schemas** eliminate sync issues
5. **Safety boundaries** prevent dangerous operations

**Benefits:**

- Least privilege security (agents only get tools they need)
- Generic tools eliminate duplication
- Context injection simplifies LLM calls
- Schemas always match implementation
- Path validation prevents security violations
- Easy to add new tools without modifying existing code

**When to Use:**

- Different agents need different tool subsets
- Tools should be reusable across contexts
- Security boundaries must be enforced
- LLMs need to discover available tools dynamically
- New capabilities should be addable as plugins

