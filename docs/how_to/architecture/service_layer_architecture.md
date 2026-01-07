---
description: Service layer architecture and composition patterns
globs: app/services/**/*.rb
alwaysApply: false
---

# Service Layer Architecture

**Tags**: [architecture, design, coding]  
**Applies To**: Any MVC application (Ruby/Rails as reference)  
**Date**: 2026-01-05

## Overview

The service layer sits between controllers and models, encapsulating business logic, coordinating multiple models, and orchestrating complex operations. Services keep controllers thin and models focused on data and persistence.

**When to use services:**
- Business logic spans multiple models
- Complex operations require coordination
- External service integration (APIs, LLMs)
- Operations need to be reused across controllers
- Workflow orchestration beyond CRUD

## Service Layer Pattern

```
Layered Architecture
│
├── Controller Layer (HTTP/API concerns)
│   ├── Parse request parameters
│   ├── Authenticate & authorize
│   ├── Delegate to service layer
│   ├── Serialize response
│   └── Handle HTTP errors
│
├── Service Layer (Business logic)
│   │
│   ├── Configuration Services (read-only)
│   │   ├── Load and cache configuration
│   │   ├── Provide query methods
│   │   └── No side effects
│   │
│   ├── Operation Services (execute actions)
│   │   ├── Create/update/delete entities
│   │   ├── Coordinate multiple operations
│   │   ├── Call external APIs
│   │   └── Return standardized responses
│   │
│   ├── Orchestration Services (coordinate)
│   │   ├── Compose multiple services
│   │   ├── Manage complex workflows
│   │   └── Handle error propagation
│   │
│   ├── Storage Services (persistence)
│   │   ├── Abstract storage mechanism
│   │   ├── Could be: DB, cache, memory, file
│   │   └── Consistent interface
│   │
│   └── Communication Services (pub/sub)
│       ├── Publish events
│       ├── Broadcast updates
│       └── Message broker integration
│
├── Worker/Job Layer (background processing)
│   ├── Asynchronous execution
│   ├── Long-running operations
│   └── Delegates to service layer
│
└── Model Layer (data & domain logic)
    ├── Domain entities
    ├── Value objects
    ├── Validation
    └── Simple queries

Service Naming Patterns:
├── *Service → Operations (UserRegistrationService)
├── *Store → Storage/Persistence (ConfigStore)
├── *Publisher → Events (EventPublisher)
├── *Factory → Object creation (WorkerFactory)
└── *Repository → Data access (UserRepository)
```

---

## Rules

### [ARCH][!CONTROLLER-TO-SERVICE-DELEGATION]

**Rule**: Controllers delegate business logic to services, handling only HTTP concerns (params, responses, auth).

**Bad Example:**

```ruby
# ❌ Fat controller with business logic
class AgentSessionsController < ApplicationController
  def create_and_process
    # Parameter extraction
    agent_type = params["agent_type"]
    content = params["message"]
    owner_id = current_user.id
    
    # Business logic in controller - BAD!
    session_id = SecureRandom.uuid
    session = AgentSession.new(
      session_id: session_id,
      owner_id: owner_id,
      agent_type: agent_type,
      status: "active",
      started_at: Time.now
    )
    session.save!
    
    # More business logic
    context = build_context_for_agent(agent_type, owner_id)
    
    # External service call
    llm_client = GenericLlmClient.new
    response = llm_client.chat(
      model: get_model_for_agent(agent_type),
      messages: build_messages(content, context)
    )
    
    # Data transformation
    result = {
      content: response[:content],
      tool_calls: extract_tool_calls(response),
      file_changes: []
    }
    
    render json: result
  end
end
```

**Good Example:**

```ruby
# ✅ Thin controller delegates to service
class Api::AgentSessionsController < ApplicationController
  def create_and_process
    # Only HTTP concerns
    agent_type = params["agent_type"]
    content = params["message"]
    
    # Delegate to service
    service = AgentSessionService.new(owner_id: current_user.id)
    session = service.create_session(agent_type: agent_type)
    
    chat_service = AgentChatService.new(session: session, context: build_context)
    result = chat_service.process_message(content: content)
    
    # Return response
    render json: AgentChatSerializer.show(result: result)
  end
end

# ✅ Service encapsulates business logic
class AgentSessionService
  def initialize(owner_id:)
    @id = SecureRandom.uuid
    @owner_id = owner_id
    freeze
  end
  
  def create_session(agent_type:)
    validate_agent_type!(agent_type)
    
    session_id = SecureRandom.uuid
    session = AgentSession.new(
      session_id: session_id,
      owner_id: @owner_id,
      agent_type: agent_type,
      status: AgentSession::STATUS_ACTIVE,
      started_at: Time.now.utc
    )
    
    persist_session(session)
    session
  end
end
```

**Why**: Thin controllers are easier to test, maintain, and reason about. Business logic in services can be reused across controllers, jobs, and tests.

---

### [ARCH][!SERVICE-COMPOSITION]

**Rule**: Services coordinate with other services to accomplish complex operations. Avoid deep nesting; prefer flat service composition.

**Bad Example:**

```ruby
# ❌ Deeply nested service calls
class AgentChatService
  def process_message(content:)
    # Calling services inside services inside services
    session_service = AgentSessionService.new(owner_id: @session.owner_id)
    session_data = session_service.get_full_session_data(@session.session_id)
    
    context_service = ContextBuildingService.new
    context = context_service.build_from_session(session_data)
    
    worker_service = WorkerCoordinationService.new
    worker = worker_service.create_worker_for_session(@session)
    
    llm_service = LLMInteractionService.new
    response = llm_service.send_message_to_worker(worker, content, context)
    
    response
  end
end
```

**Good Example:**

```ruby
# ✅ Flat composition with clear dependencies
class AgentChatService
  attr_reader :session, :context
  
  def initialize(session:, context:)
    @id = SecureRandom.uuid
    validate_params!(session, context)
    
    @session = session
    @context = context
    freeze
  end
  
  def process_message(content:)
    # Build worker with session data
    worker = build_worker
    
    # Extract conversation history
    conversation_history = extract_conversation_history
    
    # Worker handles message processing
    result = worker.process_message(
      content: content,
      conversation_history: conversation_history
    )
    
    standardize_response(result)
  end
  
  private
  
  def build_worker
    case @session.agent_type
    when "daedalus"
      DaedalusWorker.new(
        session_id: @session.session_id,
        context: @context
      )
    when "sisyphus"
      SisyphusWorker.new(
        session_id: @session.session_id,
        context: @context
      )
    end
  end
end
```

**Why**: Flat composition is easier to understand, test, and modify. Each service has a clear, single responsibility.

---

### [ARCH][!SERVICE-VS-WORKFLOW]

**Rule**: Use services for stateless operations and workflows for stateful, multi-step processes.

**Decision Tree:**

```
Does the operation have state that persists across steps?
├─ NO → Use a Service
│   ├─ Single responsibility
│   ├─ Stateless execution
│   └─ Returns result immediately
│
└─ YES → Use a Workflow
    ├─ State machine with transitions
    ├─ Persistent state tracking
    └─ Can be paused/resumed
```

**Bad Example:**

```ruby
# ❌ Service trying to manage state
class PlanExecutionService
  def initialize(plan_path:, project_path:)
    @plan_path = plan_path
    @project_path = project_path
    @current_milestone = nil
    @current_step = nil
    @completed_steps = []
    @state = :pending
  end
  
  def execute
    @state = :running
    plan.milestones.each do |milestone|
      @current_milestone = milestone
      execute_milestone(milestone)
    end
    @state = :complete
  end
  
  # Problem: State management is manual and error-prone
end
```

**Good Example:**

```ruby
# ✅ Stateless service for simple operations
class ToolExecutionService
  def execute_tool(tool_name:, params:)
    tool_class = TOOL_MAP[tool_name]
    raise ArgumentError, "Unknown tool: #{tool_name}" unless tool_class
    
    tool = tool_class.new
    result = tool.execute(
      pattern: params.pattern,
      path: params.path,
      case_sensitive: params.case_sensitive
    )
    
    standardize_response(result)
  end
end

# ✅ Stateful workflow for complex operations
class StepExecutionWorkflow < BaseWorkflow
  include StateMachine
  
  initial_state :pending
  
  state :pending
  state :running
  state :assembling_context
  state :planning
  state :executing
  state :complete
  state :failed
  
  def execute
    start!                    # pending → running
    initialized!              # running → assembling_context
    assemble_context
    context_assembled!        # assembling_context → planning
    plan_execution
    planned!                  # planning → executing
    execute_tools
    finish!                   # executing → complete
  end
end
```

**Why**: Services handle immediate operations while workflows manage state machines. This keeps responsibilities clear and prevents bugs from manual state tracking.

---

### [ARCH][!DEPENDENCY-INJECTION]

**Rule**: Inject dependencies in service constructors, not hardcoded references. Enables testing and flexibility.

**Bad Example:**

```ruby
# ❌ Hardcoded dependencies
class ExecutionOrchestrationService
  def start_execution(plan_path:, project_path:)
    # Hardcoded store - can't test!
    @state_store = ExecutionStateStore.new
    
    # Hardcoded broadcaster - can't mock!
    @broadcaster = ExecutionProgressBroadcaster.new
    
    # Hardcoded Redis - can't test!
    @redis = Redis.new(url: ENV['REDIS_URL'])
    
    # ... execution logic
  end
end
```

**Good Example:**

```ruby
# ✅ Dependency injection with defaults
class EntityOrchestrationService
  def initialize(state_store:, broadcaster:)
    @id = SecureRandom.uuid
    @state_store = state_store
    @broadcaster = broadcaster
    freeze
  end

  def start_execution(plan_path:, project_path:)
    execution_id = SecureRandom.uuid
    
    state = Execution::ExecutionState.new(
      execution_id: execution_id,
      plan_path: plan_path,
      project_path: project_path,
      status: Execution::ExecutionState::PENDING
    )
    
    @state_store.save(state)
    @broadcaster.broadcast_started(
      execution_id: execution_id,
      plan_path: plan_path,
      project_path: project_path
    )
    
    {success: true, execution_id: execution_id}
  end
end

# Testing is easy
RSpec.describe ExecutionOrchestrationService do
  it "broadcasts execution start" do
    mock_broadcaster = double("broadcaster")
    expect(mock_broadcaster).to receive(:broadcast_started)
    
    service = ExecutionOrchestrationService.new(broadcaster: mock_broadcaster)
    service.start_execution(plan_path: "plan.md", project_path: "/path")
  end
end
```

**Why**: Dependency injection makes services testable, flexible, and easier to refactor. Production code uses defaults, tests inject mocks.

---

### [ARCH][!SERVICE-NAMING-CONVENTIONS]

**Rule**: Name services based on their purpose: `*Service` for operations, `*Store` for storage, `*Broadcaster` for pub/sub.

**Bad Example:**

```ruby
# ❌ Vague names
class AgentManager  # What does it manage?
class ExecutionHandler  # What does it handle?
class DataProcessor  # What data?
class Helper  # Helper for what?
```

**Good Example:**

```ruby
# ✅ Clear, purpose-driven names
class AgentSessionService      # Manages agent sessions
class ExecutionOrchestrationService  # Orchestrates executions
class ExecutionProgressBroadcaster   # Broadcasts execution events
class ExecutionStateStore      # Stores execution state
class ToolExecutionService     # Executes tools
class AgentChatService         # Handles agent chat
class ToolCallService          # Manages tool calls
```

**Why**: Clear naming makes code self-documenting and helps developers find the right service quickly.

---

### [ARCH][!CONFIGURATION-VS-EXECUTION-SERVICES]

**Rule**: Separate configuration services (read-only) from execution services (performs operations).

**Bad Example:**

```ruby
# ❌ Mixed responsibilities
class AgentConfigService
  def self.get_config
    # Load configuration
  end
  
  def self.execute_agent_action(action)
    # Execution logic doesn't belong here!
  end
  
  def self.update_config(new_config)
    # Mutation doesn't belong here!
  end
end
```

**Good Example:**

```ruby
# ✅ Configuration service (read-only)
class ConfigService
  def initialize
    @id = SecureRandom.uuid
    @config = load_config_from_file
    freeze
  end
  
  def get_config
    @config
  end
  
  def self.capability?(name)
    get_config.capabilities.key?(name.to_sym)
  end
  
  private
  
  def self.load_config_from_file
    path = Rails.root.join("config", "agent_config.yml")
    config_data = YAML.load_file(path)
    AgentConfig.new(**config_data)
  end
end

# ✅ Execution service (performs operations)
class AgentExecutionService
  def initialize(agent_type:, config:)
    @id = SecureRandom.uuid
    @agent_type = agent_type
    @config = config
    freeze
  end
  
  def execute_action(action)
    validate_action!(action)
    perform_execution(action)
  end
end
```

**Why**: Separating configuration from execution makes responsibilities clear, enables caching, and simplifies testing.

---

## Patterns

### Pattern: Service Object Structure

```ruby
class EntityService
  def initialize(store:)
    @id = SecureRandom.uuid
    @store = store
    freeze
  end
  
  # Explicit named parameters
  def create_entity(name:, entity_type:)
    raise TypeError unless name.is_a?(String)
    raise TypeError unless entity_type.is_a?(String)
    
    entity = Entity.new(name: name, entity_type: entity_type)
    @store.save(entity)
    entity
    # No rescue - let errors bubble up
  end
  
  # 2. Secondary public methods
  def another_operation
    # ...
  end
  
  # 3. Private helpers below
  private
  
  def validate_params!(params)
    # Fail fast with descriptive errors
    raise ArgumentError, "param_name is required" unless params["param_name"]
  end
  
  def perform_operation(params)
    # Core business logic
  end
  
  def standardize_response(result)
    {
      success: true,
      data: result
    }
  end
  
  def error_response(message)
    {
      success: false,
      error: message
    }
  end
end
```

---

### Pattern: Service with Dependency Injection

```ruby
class ExecutionOrchestrationService
  # Explicit dependencies, no defaults
  def initialize(state_store:, broadcaster:, agent_class:)
    @id = SecureRandom.uuid
    @state_store = state_store
    @broadcaster = broadcaster
    @agent_class = agent_class
    freeze
  end
  
  sig { params(plan_path: String, project_path: String, priority: Integer, timeout: Integer).returns(T::Hash[String, String]) }
  def start_execution(plan_path:, project_path:, priority: 1, timeout: 3600)
    validate_start_params!(plan_path, project_path)
    
    execution_id = UUID.generate.to_s
    
    # Use injected dependencies
    state = create_initial_state(execution_id, plan_path, project_path)
    @state_store.save(state)
    
    @broadcaster.broadcast_started(
      execution_id: execution_id,
      plan_path: plan_path,
      project_path: project_path
    )
    
    # Start worker asynchronously
    @worker_class.perform_async(plan_path, project_path, execution_id)
    
    {success: true, execution_id: execution_id}
  end
end

# Production usage
service = ExecutionOrchestrationService.new
result = service.start_execution(plan_path: "plan.md", project_path: "/project")

# Testing usage
mock_broadcaster = double("broadcaster", broadcast_started: true)
mock_store = double("store", save: true)
mock_worker = double("worker", perform_async: true)

service = ExecutionOrchestrationService.new(
  broadcaster: mock_broadcaster,
  state_store: mock_store,
  worker_class: mock_worker
)
```

---

### Pattern: Service Composition (Orchestration)

```ruby
# High-level orchestrator service
class AgentChatService
  def initialize(session:, context:)
    @id = SecureRandom.uuid
    @session = session
    @context = context
    freeze
  end
  
  def process_message(content:)
    # 1. Build worker
    worker = build_worker
    
    # 2. Extract conversation
    conversation_history = extract_conversation_history
    
    # 3. Delegate to worker
    result = worker.process_message(
      content: content,
      conversation_history: conversation_history
    )
    
    # 4. Standardize response
    standardize_response(result)
  end
  
  private
  
  def build_worker
    WorkerFactory.create(
      agent_type: @session.agent_type,
      session: @session,
      context: @context
    )
  end
  
  def extract_conversation_history
    MessageHistoryService.new(session_id: @session.session_id).get_history
  end
end

# Low-level services
class WorkerFactory
  def self.create(agent_type:, session:, context:)
    case agent_type
    when "daedalus"
      DaedalusWorker.new(session: session, context: context)
    when "sisyphus"
      SisyphusWorker.new(session: session, context: context)
    else
      raise ArgumentError, "Unknown agent_type: #{agent_type}"
    end
  end
end

class MessageHistoryService
  def initialize(session_id:)
    @id = SecureRandom.uuid
    @session_id = session_id
    freeze
  end
  
  def get_history(limit: 10)
    Message.where(session_id: @session_id)
           .order(created_at: :desc)
           .limit(limit)
           .reverse
  end
end
```

---

## Real-World Examples

### Example 1: Tool Execution Service (Wrapper Pattern)

```ruby
# typed: strict

# Tool execution parameters class
class FileTreeParams < T::Struct
  extend T::Sig
  
  const :path, String
  const :max_depth, Integer, default: 3
  const :include_hidden, T::Boolean, default: false
end

class GrepParams < T::Struct
  extend T::Sig
  
  const :pattern, String
  const :path, String
  const :case_sensitive, T::Boolean, default: true
end

# Service wraps existing tools with consistent interface
class ToolExecutionService
  extend T::Sig
  
  TOOL_MAP = T.let({
    file_tree: FileTreeTool,
    read_file: ReadFileTool,
    grep: GrepTool
  }.freeze, T::Hash[Symbol, T.class_of(BaseTool)])

  sig { void }
  def initialize
    @id = T.let(UUID.generate, UUID)
  end

  sig { params(path: String, max_depth: Integer, include_hidden: T::Boolean).returns(T::Hash[String, T.untyped]) }
  def list_directory(path:, max_depth: 3, include_hidden: false)
    tool = FileTreeTool.new
    result = tool.execute(
      path: path,
      max_depth: max_depth,
      include_hidden: include_hidden
    )
  end

  def read_file(path:)
    execute_tool(
      tool_name: :read_file,
      params: {path: path}
    )
  end

  private

  def validate_params!(tool_name, params)
    raise ArgumentError, "tool_name must be a Symbol" unless tool_name.is_a?(Symbol)
    raise ArgumentError, "params must be a Hash" unless params.is_a?(Hash)
  end

  def standardize_response(result)
    {success: true, data: result}
  end

  def error_response(message)
    {success: false, error: message}
  end
end
```

### Example 2: Execution Orchestration Service (Coordinator Pattern)

```ruby
# Service coordinates workers, state, and broadcasting
class EntityOrchestrationService
  def initialize(state_store:, broadcaster:)
    @id = SecureRandom.uuid
    @state_store = state_store
    @broadcaster = broadcaster
    freeze
  end

  sig { params(plan_path: String, project_path: String, priority: Integer, timeout: Integer).returns(T::Hash[String, String]) }
  def start_execution(plan_path:, project_path:, priority: 1, timeout: 3600)
    validate_start_params!(plan_path, project_path)

    execution_id = UUID.generate.to_s

    # 1. Create execution state
    state = Execution::ExecutionState.new(
      execution_id: execution_id,
      plan_path: plan_path,
      project_path: project_path,
      status: Execution::ExecutionState::PENDING,
      started_at: Time.now.utc.iso8601
    )

    # 2. Persist state
    unless @state_store.save(state)
      return {success: false, error: "Failed to persist execution state"}
    end

    # 3. Broadcast start event
    @broadcaster.broadcast_started(
      execution_id: execution_id,
      plan_path: plan_path,
      project_path: project_path
    )

    # 4. Start worker asynchronously
    SisyphusWorker.perform_async(plan_path, project_path, execution_id)

    {success: true, execution_id: execution_id}
  rescue => e
    Rails.logger.error("Failed to start execution: #{e.message}")
    {success: false, error: e.message}
  end

  def get_execution(execution_id:)
    state = @state_store.get(execution_id)
    
    if state
      {success: true, status: state.status}
    else
      {success: false, error: "Execution not found: #{execution_id}"}
    end
  end

  private

  def validate_start_params!(plan_path, project_path)
    # Type validation only
    raise TypeError unless plan_path.is_a?(String)
    raise TypeError unless project_path.is_a?(String)
    # Let File.exist? and Dir.exist? fail naturally when used
  end
end
```

---

## Checklist

When creating services:

- [ ] Named clearly with purpose suffix (*Service, *Store, *Broadcaster)
- [ ] Single responsibility - does one thing well
- [ ] Dependencies injected in constructor
- [ ] Public interface at top, private helpers below
- [ ] Parameter validation with fail-fast errors
- [ ] Standardized response format
- [ ] Error handling with rescue blocks
- [ ] No hardcoded external dependencies (Redis, databases)
- [ ] Stateless (or use workflow for stateful operations)
- [ ] Tested in isolation with mocked dependencies
- [ ] Controller only handles HTTP concerns, delegates logic to service
- [ ] Serializer used for JSON responses

---

## Summary

**Key Principles:**

1. **Controller → Service → Model** layering
2. **Single responsibility** per service
3. **Dependency injection** for flexibility
4. **Service composition** for complex operations
5. **Services = stateless, Workflows = stateful**
6. **Clear naming** indicates purpose

**Benefits:**

- Thin controllers easy to test
- Business logic reused across controllers/jobs
- Services testable in isolation
- Easy to refactor and modify
- Clear separation of concerns

**When to Use Services:**

- Business logic spans multiple models
- Complex coordination required
- External service integration
- Operations reused across controllers
- Immediate, stateless operations (not multi-step state machines)

