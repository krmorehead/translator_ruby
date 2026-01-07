---
description: Parameter and options patterns for method signatures
globs: app/**/*.rb
alwaysApply: false
---

# Parameter and Options Patterns

**Tags**: [architecture, coding, back_end]  
**Applies To**: All Ruby methods  
**Date**: 2026-01-06

## Overview

Methods must have explicit parameters. Using `**params`, `**options`, `options: {}`, or `params: {}` is an anti-pattern that hides method contracts and makes code unpredictable. Every parameter should be explicitly named or wrapped in a typed class.

## Parameter Patterns

```
Explicit Parameters System
│
├── Simple Methods (1-3 parameters)
│   └── Use explicit keyword arguments
│       def method(param1:, param2:, param3: default)
│
├── Complex Methods (4+ parameters)
│   └── Use T::Struct class
│       class MethodParams < T::Struct
│         const :param1, String
│         const :param2, Integer
│       end
│       def method(params: MethodParams)
│
└── Anti-Patterns to Avoid
    ├── ❌ **params (splat operator)
    ├── ❌ **options (splat operator)
    ├── ❌ options: {} (empty hash default)
    └── ❌ params: {} (empty hash default)

Why Explicit Parameters?
├── ✅ Clear method contract
├── ✅ Type-safe with Sorbet
├── ✅ Easy to understand
├── ✅ IDE autocomplete works
└── ✅ Refactoring is safe
```

---

## Rules

### [PARAM][!NO-SPLAT-OPERATORS]

**Rule**: Never use `**params` or `**options`. Always explicit parameters or typed classes.

**Bad Example:**

```ruby
# ❌ Splat operator hides contract
def execute_tool(tool_name:, **params)
  tool = TOOL_MAP[tool_name].new
  tool.execute(**params)  # What parameters does this need?
end

# ❌ Caller doesn't know what's valid
execute_tool(tool_name: :grep, pattern: "foo", unknown_param: "bar")
```

**Good Example - Explicit Parameters:**

```ruby
# typed: strict

# ✅ Clear contract with explicit parameters
class ToolExecutionService
  extend T::Sig
  
  sig { params(tool_name: Symbol, pattern: String, path: String, case_sensitive: T::Boolean).returns(ToolResult) }
  def execute_grep(tool_name:, pattern:, path:, case_sensitive: true)
    tool = GrepTool.new
    tool.execute(
      pattern: pattern,
      path: path,
      case_sensitive: case_sensitive
    )
  end
end

# ✅ Caller knows exactly what's needed
service.execute_grep(
  tool_name: :grep,
  pattern: "foo",
  path: "/src",
  case_sensitive: false
)
```

**Good Example - T::Struct Class:**

```ruby
# typed: strict

# ✅ Typed parameter class
class GrepParams < T::Struct
  extend T::Sig
  
  const :pattern, String
  const :path, String
  const :case_sensitive, T::Boolean, default: true
  const :max_results, Integer, default: 100
end

class ToolExecutionService
  extend T::Sig
  
  sig { params(params: GrepParams).returns(ToolResult) }
  def execute_grep(params:)
    tool = GrepTool.new
    tool.execute(
      pattern: params.pattern,
      path: params.path,
      case_sensitive: params.case_sensitive,
      max_results: params.max_results
    )
  end
end

# ✅ Type-safe parameter construction
params = GrepParams.new(
  pattern: "foo",
  path: "/src",
  case_sensitive: false
)
service.execute_grep(params: params)
```

**Why**: Explicit parameters make contracts clear and enable type checking.

---

### [PARAM][!NO-EMPTY-HASH-DEFAULTS]

**Rule**: Never use `options: {}` or `params: {}`. Use explicit defaults or typed classes.

**Bad Example:**

```ruby
# ❌ Empty hash default hides what's accepted
def start_execution(plan_path:, project_path:, options: {})
  priority = options[:priority] || 1  # Hidden parameter
  timeout = options[:timeout] || 3600  # Hidden parameter
  # What other options are valid? Unknown!
end
```

**Good Example - Explicit Defaults:**

```ruby
# typed: strict

# ✅ Explicit parameters with defaults
class ExecutionService
  extend T::Sig
  
  sig { params(plan_path: String, project_path: String, priority: Integer, timeout: Integer).returns(Execution) }
  def start_execution(plan_path:, project_path:, priority: 1, timeout: 3600)
    # Clear what parameters exist and their defaults
    execution = Execution.new(
      plan_path: plan_path,
      project_path: project_path,
      priority: priority,
      timeout: timeout
    )
    execution.start
    execution
  end
end
```

**Good Example - Options Class:**

```ruby
# typed: strict

# ✅ Explicit options class
class ExecutionOptions < T::Struct
  extend T::Sig
  
  const :priority, Integer, default: 1
  const :timeout, Integer, default: 3600
  const :max_retries, Integer, default: 3
  const :notification_email, T.nilable(String), default: nil
end

class ExecutionService
  extend T::Sig
  
  sig { params(plan_path: String, project_path: String, options: ExecutionOptions).returns(Execution) }
  def start_execution(plan_path:, project_path:, options:)
    execution = Execution.new(
      plan_path: plan_path,
      project_path: project_path,
      priority: options.priority,
      timeout: options.timeout,
      max_retries: options.max_retries,
      notification_email: options.notification_email
    )
    execution.start
    execution
  end
end

# Usage
options = ExecutionOptions.new(priority: 2, timeout: 7200)
service.start_execution(
  plan_path: "/plans/plan.md",
  project_path: "/projects/my-project",
  options: options
)
```

**Why**: Explicit options classes document all available options and their types.

---

### [PARAM][!WHEN-TO-USE-STRUCT]

**Rule**: Use T::Struct for 4+ parameters or when parameters form a logical group.

**Good Example:**

```ruby
# typed: strict

# ✅ Logical grouping with T::Struct
class DatabaseConfig < T::Struct
  const :host, String
  const :port, Integer, default: 5432
  const :database, String
  const :username, String
  const :password, String
  const :pool_size, Integer, default: 5
  const :timeout, Integer, default: 5000
end

class DatabaseConnection
  extend T::Sig
  
  sig { params(config: DatabaseConfig).void }
  def initialize(config:)
    @id = T.let(UUID.generate, UUID)
    @config = T.let(config, DatabaseConfig)
  end
  
  sig { returns(Connection) }
  def connect
    PG.connect(
      host: @config.host,
      port: @config.port,
      dbname: @config.database,
      user: @config.username,
      password: @config.password,
      pool: @config.pool_size,
      connect_timeout: @config.timeout
    )
  end
end
```

**Why**: T::Struct groups related parameters and provides type safety.

---

### [PARAM][!SORBET-SIGNATURES]

**Rule**: Every method must have a Sorbet signature. No exceptions.

**Good Example:**

```ruby
# typed: strict

class UserService
  extend T::Sig
  
  sig { params(email: String, password: String, name: String, role: String).returns(User) }
  def create_user(email:, password:, name:, role: "member")
    raise ArgumentError, "email must be a String" unless email.is_a?(String)
    raise ArgumentError, "password must be a String" unless password.is_a?(String)
    
    user = User.new(
      email: email,
      password: encrypt_password(password),
      name: name,
      role: role
    )
    user.save
    user
  end
  
  sig { params(user_id: UUID).returns(T.nilable(User)) }
  def find_user(user_id:)
    User.find_by(id: user_id.to_s)
  end
  
  private
  
  sig { params(password: String).returns(String) }
  def encrypt_password(password)
    BCrypt::Password.create(password)
  end
end
```

**Why**: Sorbet signatures provide type safety and documentation.

---

## Patterns

### Pattern: Simple Method (1-3 parameters)

```ruby
# typed: strict

class FileService
  extend T::Sig
  
  sig { params(path: String, content: String, mode: String).void }
  def write_file(path:, content:, mode: "w")
    File.write(path, content, mode: mode)
  end
end
```

---

### Pattern: Complex Method with T::Struct

```ruby
# typed: strict

class LlmRequestParams < T::Struct
  const :messages, T::Array[Message]
  const :model, String, default: "gpt-4"
  const :temperature, Float, default: 0.7
  const :max_tokens, Integer, default: 1000
  const :top_p, Float, default: 1.0
  const :frequency_penalty, Float, default: 0.0
  const :presence_penalty, Float, default: 0.0
end

class LlmClient
  extend T::Sig
  
  sig { params(params: LlmRequestParams).returns(ChatResponse) }
  def chat(params:)
    request_body = {
      "model" => params.model,
      "messages" => params.messages.map { |m| serialize_message(m) },
      "temperature" => params.temperature,
      "max_tokens" => params.max_tokens,
      "top_p" => params.top_p,
      "frequency_penalty" => params.frequency_penalty,
      "presence_penalty" => params.presence_penalty
    }
    
    response = http_client.post("/chat/completions", body: request_body.to_json)
    deserialize_response(JSON.parse(response.body))
  end
  
  private
  
  sig { params(message: Message).returns(T::Hash[String, String]) }
  def serialize_message(message)
    { "role" => message.role, "content" => message.content }
  end
  
  sig { params(json: T::Hash[String, T.untyped]).returns(ChatResponse) }
  def deserialize_response(json)
    # Deserialization logic
  end
end

# Usage
params = LlmRequestParams.new(
  messages: [Message.new(role: "user", content: "Hello")],
  temperature: 0.8,
  max_tokens: 500
)
response = client.chat(params: params)
```

---

### Pattern: Method Evolution

```ruby
# typed: strict

# Start: Simple method
sig { params(email: String).returns(User) }
def create_user(email:)
  User.new(email: email)
end

# Grows: Add parameters
sig { params(email: String, name: String, role: String).returns(User) }
def create_user(email:, name:, role: "member")
  User.new(email: email, name: name, role: role)
end

# Gets complex: Extract to T::Struct
class UserParams < T::Struct
  const :email, String
  const :name, String
  const :role, String, default: "member"
  const :notification_preferences, NotificationPreferences
  const :timezone, String, default: "UTC"
  const :locale, String, default: "en"
end

sig { params(params: UserParams).returns(User) }
def create_user(params:)
  User.new(
    email: params.email,
    name: params.name,
    role: params.role,
    notification_preferences: params.notification_preferences,
    timezone: params.timezone,
    locale: params.locale
  )
end
```

---

## Checklist

- [ ] No `**params` or `**options` anywhere
- [ ] No `options: {}` or `params: {}` defaults
- [ ] All parameters explicitly named
- [ ] T::Struct for 4+ parameters
- [ ] Sorbet signature on every method
- [ ] Default values use `param: default` syntax
- [ ] Parameter validation in method body
- [ ] T::Struct classes have `const` not `prop`
- [ ] Every T::Struct extends T::Sig
- [ ] Clear parameter names

---

## Summary

**Key Principles:**

1. **Explicit parameters** - Name every parameter
2. **No splat operators** - Never `**params` or `**options`
3. **No empty hashes** - Never `options: {}` or `params: {}`
4. **T::Struct for complexity** - 4+ parameters use classes
5. **Sorbet everywhere** - Every method has signature
6. **Type safety** - Leverage Sorbet fully

**Benefits:**

- Clear method contracts
- IDE autocomplete works
- Refactoring is safe
- Type checking catches errors
- Easy to understand
- No hidden parameters

**When to Use T::Struct:**

- 4 or more parameters
- Logically grouped parameters
- Parameters shared across methods
- Complex configuration objects

