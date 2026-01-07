---
description: LLM integration patterns for prompts, agents, and tools
globs: app/{prompts,agents,tools}/**/*.rb
alwaysApply: false
---

# LLM API Integration Patterns

**Tags**: [architecture, coding, design]  
**Applies To**: Any system integrating with LLM APIs  

## Overview

Patterns for integrating with LLM APIs including prompt construction, tool registration, response handling, and token tracking.

## LLM Integration Architecture Tree

```
LLM Integration System
│
├── Prompt Layer (message construction)
│   │
│   ├── Base Prompt Pattern
│   │   ├── Responsibilities:
│   │   │   ├── Define system_message
│   │   │   ├── Define response_schema (optional)
│   │   │   └── Build parameters for LLM call
│   │   │
│   │   ├── Core Methods:
│   │   │   ├── system_message() → String
│   │   │   ├── build_parameters(messages) → Hash
│   │   │   └── execute(...) → Hash
│   │   │
│   │   └── Subclass implements domain-specific logic
│   │
│   └── Tool-Enabled Prompt Pattern
│       ├── Responsibilities:
│       │   ├── Register tools
│       │   ├── Serialize tools to API format
│       │   ├── Multi-turn tool calling loop
│       │   └── Execute tools and add results
│       │
│       ├── initialize(tools: [])
│       │   └── @tools = Array(tools)
│       │
│       ├── serialize_tools() → Array<Hash>
│       │   └── @tools.map(&:to_schema)
│       │
│       ├── build_parameters(messages)
│       │   └── {
│       │         messages: messages,
│       │         tools: serialize_tools(),
│       │         tool_choice: "auto"
│       │       }
│       │
│       └── execute_with_tools(user_message:, max_iterations: 20)
│           ├── messages = build_messages_with_history(user_message)
│           ├── Loop (max max_iterations):
│           │   ├── response = call_llm_with_tools(messages)
│           │   ├── if response[:tool_calls].present?
│           │   │   ├── Execute each tool
│           │   │   ├── Add results to messages
│           │   │   └── Continue loop
│           │   └── else → return final response
│           └── raise if max_iterations exceeded
│
├── Concrete Prompt Implementations
│   │
│   ├── Planning Prompt (generates structured plans)
│   │   ├── initialize(goal:, available_tools:)
│   │   │
│   │   ├── system_message
│   │   │   └── "You are a planning expert..."
│   │   │
│   │   ├── response_schema
│   │   │   └── Structured JSON schema for plan format
│   │   │
│   │   └── build_user_message(goal)
│   │       └── Includes concrete JSON examples
│   │
│   ├── Chat Prompt (interactive conversation)
│   │   ├── Tools: read-only operations
│   │   ├── initialize(conversation_history:)
│   │   └── execute_tool(name, args) → tool.execute(**args)
│   │
│   └── Execution Prompt (performs actions)
│       ├── Tools: read + write operations
│       └── execute_tool(name, args) → tool.execute(**args with context)
│
├── LLM Client Layer (API communication)
│   │
│   └── GenericLlmClient
│       ├── Responsibilities:
│       │   ├── HTTP requests to LLM API
│       │   ├── Symbolize responses at boundary
│       │   ├── Track token usage
│       │   └── Error handling
│       │
│       ├── initialize(base_url:, api_key:, default_model:)
│       │
│       ├── chat(messages:, model:, temperature:, max_tokens:)
│       │   ├── 1. Build request body
│       │   │   └── {
│       │   │         model: model,
│       │   │         messages: messages,
│       │   │         temperature: options.fetch(:temperature),
│       │   │         tools: options[:tools],
│       │   │         response_format: options[:response_format]
│       │   │       }
│       │   │
│       │   ├── 2. POST to /v1/chat/completions
│       │   │
│       │   ├── 3. Parse response (string keys from API)
│       │   │   └── JSON.parse(response.body)
│       │   │
│       │   ├── 4. Symbolize at boundary
│       │   │   └── {
│       │   │         content: response["choices"][0]["message"]["content"],
│       │   │         tool_calls: symbolize_tool_calls(...),
│       │   │         usage: {
│       │   │           prompt_tokens: response["usage"]["prompt_tokens"],
│       │   │           completion_tokens: response["usage"]["completion_tokens"],
│       │   │           total_tokens: response["usage"]["total_tokens"]
│       │   │         }
│       │   │       }
│       │   │
│       │   ├── 5. Log token usage
│       │   │   └── Rails.logger.info("LLM: #{usage[:total_tokens]} tokens")
│       │   │
│       │   └── 6. Return symbolized hash
│       │
│       └── Error handling:
│           ├── HTTP errors → raise with status code
│           ├── Timeout errors → raise with timeout info
│           └── JSON parse errors → raise with raw response
│
├── Tool Integration (context-aware)
│   │
│   ├── Tool Schema Generation
│   │   │
│   │   └── BaseTool.schema() →
│   │       {
│   │         type: "function",
│   │         function: {
│   │           name: "read_file",
│   │           description: "Read complete contents of a file...",
│   │           parameters: {
│   │             type: "object",
│   │             properties: {
│   │               path: {
│   │                 type: "string",
│   │                 description: "Path to file relative to codebase"
│   │               }
│   │             },
│   │             required: ["path"]
│   │           }
│   │         }
│   │       }
│   │
│   └── Context Injection
│       │
│       ├── Prompt initialization:
│       │   └── tools = [
│       │         Sisyphus::WriteFileTool.new(codebase_path: @path),
│       │         Sisyphus::BashTool.new(working_directory: @path)
│       │       ]
│       │
│       ├── LLM receives schema (no path):
│       │   └── {
│       │         name: "write_file",
│       │         parameters: {
│       │           path: "src/app.js",    # Relative path
│       │           content: "..."
│       │         }
│       │       }
│       │
│       └── Tool execution (context injected):
│           └── tool.execute(path: "src/app.js", content: "...")
│               ├── full_path = File.join(@codebase_path, "src/app.js")
│               ├── Validate: full_path within @codebase_path
│               └── File.write(full_path, content)
│
└── Complete LLM Call Flow
    │
    ├── 1. Workflow creates prompt
    │   └── prompt = PlanGenerationPrompt.new(
    │         goal: "Add health check",
    │         path: "/project",
    │         available_tools: [file_tree_tool, grep_tool, read_file_tool]
    │       )
    │
    ├── 2. Prompt builds messages
    │   └── messages = [
    │         {role: "system", content: prompt.system_message},
    │         {role: "user", content: prompt.build_user_message(goal, path)}
    │       ]
    │
    ├── 3. Prompt calls LLM client
    │   └── response = GenericLlmClient.new.chat(
    │         messages: messages,
    │         tools: prompt.serialize_tools(),
    │         response_format: {type: "json_schema", schema: prompt.response_schema}
    │       )
    │
    ├── 4. LLM returns response (OpenAI format)
    │   └── {
    │         "choices": [{
    │           "message": {
    │             "content": "...",
    │             "tool_calls": [{
    │               "id": "call_123",
    │               "function": {
    │                 "name": "read_file",
    │                 "arguments": "{\"path\":\"src/app.js\"}"
    │               }
    │             }]
    │           }
    │         }],
    │         "usage": {"total_tokens": 150}
    │       }
    │
    ├── 5. Client symbolizes at boundary
    │   └── {
    │         content: "...",
    │         tool_calls: [{
    │           id: "call_123",
    │           name: "read_file",
    │           arguments: {path: "src/app.js"}  # Symbols!
    │         }],
    │         usage: {total_tokens: 150}
    │       }
    │
    ├── 6. Prompt executes tools
    │   └── result = execute_tool("read_file", {path: "src/app.js"})
    │       └── {success: true, result: "file contents..."}
    │
    ├── 7. Add tool result to conversation
    │   └── messages << {
    │         role: "tool",
    │         tool_call_id: "call_123",
    │         content: result[:result]
    │       }
    │
    ├── 8. Continue multi-turn loop
    │   └── If more tool calls → repeat from step 3
    │       If no tool calls → return final response
    │
    └── 9. Return to workflow
        └── {
              content: "Final response from LLM",
              tool_calls_made: 3,
              usage: {total_tokens: 450}
            }

Token Tracking Flow:
Every LLM call logs:
├── Input: prompt size, tool schemas size
├── Output: completion size
├── Total: prompt_tokens + completion_tokens
├── Duration: request/response time
└── Cost: estimated based on model pricing

Example log:
"LLM call: model=llama-70b, tokens=450 (300 prompt + 150 completion), duration=2.3s"

Prompt Example Pattern:
system_message:
  "You are a project planner. Generate execution plans in JSON format.
  
  Example output:
  {
    \"plan\": {
      \"title\": \"Add Health Check Endpoint\",
      \"milestones\": [
        {
          \"number\": 1,
          \"title\": \"Create endpoint\",
          \"steps\": [
            {\"number\": 1, \"title\": \"Define route\", \"intent\": \"Add GET /health route\"}
          ]
        }
      ]
    }
  }
  
  ALWAYS follow this exact structure."

Result: LLM follows concrete examples, not vague descriptions!
```

---

## Rules

### [LLM][!PROMPT-EXAMPLES]

**Rule**: Always provide concrete JSON examples in prompts. Show, don't tell.

**Bad Example:**

```ruby
# ❌ Vague description
def system_prompt
  "Return an array of actions with tool_name and arguments"
end
```

**Good Example:**

```ruby
# ✅ Concrete examples
def system_prompt
  <<~PROMPT
    Return an array of actions in this format:
    
    [
      {
        "tool_name": "read_file",
        "arguments": {
          "path": "src/app.js"
        }
      },
      {
        "tool_name": "write_file",
        "arguments": {
          "path": "src/utils.js",
          "content": "export function helper() { return true; }"
        }
      }
    ]
    
    Each action MUST have "tool_name" (string) and "arguments" (object).
  PROMPT
end
```

**Why**: LLMs follow examples better than descriptions. Concrete examples drive correct behavior.

---

### [LLM][!CONTEXT-INJECTION]

**Rule**: Inject context parameters (codebase_path, working_directory) automatically in workflows, not passed every LLM call.

**Good Example:**

```ruby
# Generic workflow pattern with context injection
class ExecutionWorkflow
  def initialize(context:)
    @id = SecureRandom.uuid
    @context = context
  end
  
  def execute
    # Tools get context from workflow, not LLM
    tools = [
      WriteFileTool.new(base_path: @context.base_path),
      ShellTool.new(working_directory: @context.base_path)
    ]
    
    # LLM doesn't need to know about paths
    prompt = ActionPrompt.new(tools: tools)
    result = prompt.execute(user_message: "Create config file")
  end
end
```

**Why**: Reduces LLM token usage, eliminates repetition, enforces security boundaries automatically.

---

### [LLM][!SYMBOLIZE-AT-BOUNDARY]

**Rule**: Symbolize all LLM responses at the boundary in GenericLlmClient.

**Good Example:**

```ruby
# typed: strict

class GenericLlmClient
  extend T::Sig
  
  sig { params(messages: T::Array[Message], model: String, temperature: Float, max_tokens: Integer).returns(ChatResponse) }
  def chat(messages:, model:, temperature: 0.7, max_tokens: 1000)
    response = http_client.post("/chat/completions", body: build_body(messages, model, temperature, max_tokens))
    json = JSON.parse(response.body)
    
    # Symbolize at boundary - application always uses symbols
    symbolize_response(json)
  end
  
  private
  
  def symbolize_response(response)
    {
      content: response["choices"][0]["message"]["content"],
      tool_calls: symbolize_tool_calls(response["choices"][0]["message"]["tool_calls"]),
      usage: {
        prompt_tokens: response["usage"]["prompt_tokens"],
        completion_tokens: response["usage"]["completion_tokens"],
        total_tokens: response["usage"]["total_tokens"]
      }
    }
  end
  
  def symbolize_tool_calls(tool_calls)
    return [] unless tool_calls
    
    tool_calls.map do |tc|
      {
        id: tc["id"],
        name: tc["function"]["name"],
        arguments: JSON.parse(tc["function"]["arguments"], symbolize_names: true)
      }
    end
  end
end
```

**Why**: Consistent symbol usage throughout application. Boundary enforcement prevents string/symbol mixing.

---

### [LLM][!TOOL-SCHEMA-GENERATION]

**Rule**: Tools generate their own OpenAI-compatible schemas. No manual schema maintenance.

**Good Example:**

```ruby
class BaseTool
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
    raise NotImplementedError
  end
  
  def self.description
    raise NotImplementedError
  end
  
  def self.parameters_schema
    raise NotImplementedError
  end
end

class ReadFileTool < BaseTool
  def self.name_identifier
    "read_file"
  end
  
  def self.description
    "Read the complete contents of a file. Returns file content as string."
  end
  
  def self.parameters_schema
    {
      type: "object",
      properties: {
        path: {
          type: "string",
          description: "Path to file relative to codebase root"
        }
      },
      required: ["path"]
    }
  end
  
  def execute(path:)
    content = File.read(path)
    success_result(content)
  end
end

# Schema always in sync with implementation
```

**Why**: Self-generating schemas eliminate sync issues. Add a parameter once, it's automatically in the schema.

---

### [LLM][!PROMPT-BUILDERS]

**Rule**: Prompts encapsulate their own message building via build_user_message methods.

**Good Example:**

```ruby
# Generic pattern for prompt message building
class ActionPrompt
  def build_user_message(task:, context:)
    <<~MESSAGE
      Execute this task:
      
      Task #{task.id}: #{task.description}
      Goal: #{task.goal}
      
      Context:
      #{format_context(context)}
      
      Use available tools to accomplish the task. Return tool calls in sequence.
    MESSAGE
  end
  
  def execute(task:, context:)
    messages = [
      {role: "system", content: system_prompt},
      {role: "user", content: build_user_message(task: task, context: context)}
    ]
    
    call_llm(messages)
  end
end
```

**Why**: Consistent message building, easier to test prompts, changes localized to prompt classes.

---

### [LLM][!TOKEN-TRACKING]

**Rule**: Track token usage for all LLM calls. Log and return usage data.

**Good Example:**

```ruby
# typed: strict

class GenericLlmClient
  extend T::Sig
  
  sig { params(messages: T::Array[Message], model: String, temperature: Float, max_tokens: Integer).returns(ChatResponse) }
  def chat(messages:, model:, temperature: 0.7, max_tokens: 1000)
    start_time = Time.now
    
    response = http_client.post("/chat/completions", body: build_body(messages, model, temperature, max_tokens))
    json = JSON.parse(response.body)
    
    duration = Time.now - start_time
    
    usage = {
      prompt_tokens: json.dig("usage", "prompt_tokens"),
      completion_tokens: json.dig("usage", "completion_tokens"),
      total_tokens: json.dig("usage", "total_tokens"),
      duration_seconds: duration
    }
    
    # Log usage
    Rails.logger.info("LLM call: #{usage[:total_tokens]} tokens in #{duration}s")
    
    # Return with usage
    {
      content: json.dig("choices", 0, "message", "content"),
      tool_calls: extract_tool_calls(json),
      usage: usage
    }
  end
end
```

**Why**: Token tracking enables cost monitoring, performance optimization, and debugging.

---

## Pattern: Multi-Turn Tool Calling

```ruby
class ToolEnabledPrompt
  def execute_with_tools(user_message:, max_iterations: 20)
    messages = build_messages_with_history(user_message)
    iteration = 0
    
    loop do
      break if iteration >= max_iterations
      
      # Call LLM with tools
      response = call_llm_with_tools(messages)
      
      # Check if LLM wants to use tools
      if response[:tool_calls].present?
        # Execute each tool
        tool_results = response[:tool_calls].map do |tc|
          execute_tool(tc[:name], tc[:arguments])
        end
        
        # Add tool results to conversation
        messages << {
          role: "assistant",
          content: response[:content],
          tool_calls: response[:tool_calls]
        }
        
        tool_results.each_with_index do |result, idx|
          messages << {
            role: "tool",
            tool_call_id: response[:tool_calls][idx][:id],
            content: result[:result]
          }
        end
        
        iteration += 1
      else
        # No more tool calls - return final response
        return {
          content: response[:content],
          tool_calls_made: iteration,
          usage: response[:usage]
        }
      end
    end
    
    raise "Exceeded max iterations (#{max_iterations})"
  end
  
  private
  
  def call_llm_with_tools(messages)
    llm_client.chat(
      messages: messages,
      tools: serialize_tools,
      tool_choice: "auto"
    )
  end
  
  def serialize_tools
    @tools.map(&:to_schema)
  end
  
  def execute_tool(name, args)
    tool = find_tool_by_name(name)
    tool.execute(**args)
  end
end
```

---

## Pattern: Prompt with Response Schema

```ruby
class StructuredOutputPrompt
  def response_schema
    {
      type: "object",
      properties: {
        plan: {
          type: "object",
          properties: {
            title: { type: "string" },
            milestones: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  number: { type: "integer" },
                  title: { type: "string" },
                  description: { type: "string" },
                  steps: {
                    type: "array",
                    items: {
                      type: "object",
                      properties: {
                        number: { type: "integer" },
                        title: { type: "string" },
                        intent: { type: "string" }
                      },
                      required: ["number", "title", "intent"]
                    }
                  }
                },
                required: ["number", "title", "description", "steps"]
              }
            }
          },
          required: ["title", "milestones"]
        }
      },
      required: ["plan"]
    }
  end
  
  def execute(goal:, path:)
    messages = build_messages(goal, path)
    
    response = client.chat(
      messages: messages,
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "plan_response",
          schema: response_schema
        }
      }
    )
    
    JSON.parse(response[:content], symbolize_names: true)
  end
end
```

---

## Summary

**Key Principles:**

1. Concrete JSON examples in prompts
2. Context injection in workflows
3. Symbolize responses at boundary
4. Self-generating tool schemas
5. Prompts encapsulate message building
6. Track token usage

**Benefits:**

- LLMs follow examples accurately
- Reduced token usage
- Consistent symbol usage
- Schemas always in sync
- Easy prompt testing
- Cost monitoring

**When to Use:**

- Any LLM integration
- Tool calling systems
- Multi-turn conversations
- Structured output generation
- Cost-sensitive applications

