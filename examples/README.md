# Sisyphus Usage Examples

This directory contains practical, runnable examples demonstrating how to use Sisyphus Agent Worker.

## Quick Start

1. **Prerequisites**:
   ```bash
   # Install dependencies
   bundle install
   
   # Ensure Redis is running
   redis-server
   
   # Configure LLM API keys in .env
   cp .env.example .env
   # Edit .env and add your API keys
   ```

2. **Run the basic example**:
   ```bash
   ./examples/01_basic_execution.rb
   ```

## Examples

### 1. Basic Execution (`01_basic_execution.rb`)
**What it demonstrates**: The simplest way to start a Sisyphus execution

**Concepts covered**:
- Starting an execution via `ExecutionOrchestrationService`
- Polling for execution state
- Monitoring progress
- Detecting completion

**Run it**:
```bash
./examples/01_basic_execution.rb
```

**What it does**:
1. Creates a sample project directory
2. Initializes git repository
3. Starts Sisyphus execution
4. Polls for status updates every 2 seconds
5. Reports completion and results

**Output**:
```
================================================================================
Sisyphus Basic Execution Example
================================================================================

Plan: /path/to/plans/simple_hello_world.md
Project: /path/to/projects/sample_project

Step 1: Starting execution...
--------------------------------------------------------------------------------
✓ Execution started successfully
  Execution ID: exec-abc123
  Status: running

Step 2: Monitoring execution progress...
--------------------------------------------------------------------------------
[14:30:00] Status: running
  Progress: 0.0%
[14:30:15] Status: running
  Milestone: Project Setup
  Step: Create Hello World Script
  Progress: 50.0%
[14:30:30] Status: complete
  Files changed: 2

Execution finished: complete
✓ Execution completed successfully!

Results:
  Files changed: 2
  Checkpoints created: 1
  Duration: 32.5s
```

---

### 2. Configuration Options (`02_configuration_options.rb`)
**What it demonstrates**: All available configuration options and when to use them

**Concepts covered**:
- Approval modes (autonomous, step, milestone)
- Error handling modes (fail_fast, continue)
- Dry-run mode
- Max retries
- Configuration serialization

**Run it**:
```bash
./examples/02_configuration_options.rb
```

**Approval Modes**:

| Mode | Description | Use Case |
|------|-------------|----------|
| **autonomous** | No approvals, fully automated | CI/CD, trusted environments |
| **step** | Approve each step individually | Maximum control, learning |
| **milestone** | Approve groups of steps | Balanced control, staged deployments |

**Example configurations**:
```ruby
# Fully automated (CI/CD)
config = Configuration::SisyphusConfig.new(
  approval_mode: :autonomous,
  max_retries: 3,
  error_mode: :fail_fast,
  dry_run: false
)

# Maximum control (production changes)
config = Configuration::SisyphusConfig.new(
  approval_mode: :step,
  max_retries: 2,
  error_mode: :fail_fast,
  dry_run: false
)

# Preview only (no changes)
config = Configuration::SisyphusConfig.new(
  approval_mode: :autonomous,
  dry_run: true
)
```

---

### 3. Real-Time Monitoring (`05_realtime_monitoring.rb`)
**What it demonstrates**: Monitoring execution progress in real-time using Redis pub/sub

**Concepts covered**:
- Subscribing to progress events
- Event types and handling
- Progress statistics
- Real-time updates

**Run it**:
```bash
./examples/05_realtime_monitoring.rb
```

**Event Types**:
- `started` - Execution began
- `milestone_started` / `milestone_completed` - Milestone progress
- `step_started` / `step_completed` - Step progress
- `file_changed` - File modification
- `checkpoint_created` - Git checkpoint
- `approval_required` - Waiting for approval
- `completed` / `failed` / `cancelled` - Terminal events

**For Web Applications**:

Instead of Redis pub/sub directly, use Server-Sent Events (SSE):

```javascript
// Frontend (React/Vue/etc.)
import { subscribeToWorkerProgress } from './utils/workerProgressStream';

const eventSource = subscribeToWorkerProgress({
  streamUrl: `/api/sisyphus/executions/${executionId}/stream`,
  onEvent: (event) => {
    switch (event.event_type) {
      case 'step_completed':
        updateProgress(event.data.progress_percentage);
        break;
      case 'file_changed':
        addFileToList(event.data.file_path);
        break;
      // ... handle other events
    }
  },
  onComplete: (data) => {
    showSuccessMessage(`Completed! ${data.total_files_changed} files changed`);
  }
});

// Remember to close when component unmounts
return () => eventSource.close();
```

See: `app/javascript/utils/workerProgressStream.js` for the complete utility.

---

## Sample Plans

The `plans/` directory contains example execution plans:

### `simple_hello_world.md`
**Goal**: Create a basic Ruby "Hello World" program

**Structure**:
```markdown
# Plan Title

**Goal**: Clear description of what to achieve

## Milestone 1: Milestone Title

### Step 1: Step Title
**Intent**: What this step accomplishes

**Details**:
- Specific actions to take
- Files to create/modify
- Commands to run

**Tests**:
- How to verify success
- Expected outcomes
```

### Creating Your Own Plans

Follow this structure for best results:

1. **Clear Goal**: State what you want to achieve
2. **Logical Milestones**: Group related steps together
3. **Specific Steps**: Each step should be focused and achievable
4. **Testable**: Include clear success criteria
5. **Context**: Provide enough detail for the LLM to understand

**Example**:
```markdown
# Add User Authentication

**Goal**: Add basic username/password authentication to the Rails app

## Milestone 1: Database Setup

### Step 1: Create User Model
**Intent**: Create a User model with authentication fields

**Details**:
- Generate User model with email and password_digest fields
- Add has_secure_password to the model
- Run migrations

**Tests**:
- User model exists
- User can be created with email and password
- Password is encrypted in database

## Milestone 2: Authentication Flow

### Step 2: Add Login Controller
**Intent**: Create controller to handle login/logout

**Details**:
- Generate SessionsController
- Add login and logout actions
- Set up session management

**Tests**:
- Can POST to /login with credentials
- Session is created on successful login
- Logout clears the session
```

---

## API Usage Examples

### Starting an Execution

**Via Service (Ruby)**:
```ruby
service = ExecutionOrchestrationService.new
result = service.start_execution(
  plan_path: "/path/to/plan.md",
  project_path: "/path/to/project",
  options: {
    approval_mode: :autonomous,
    dry_run: false
  }
)

if result[:success]
  execution_id = result[:execution_id]
  puts "Started: #{execution_id}"
else
  puts "Error: #{result[:error]}"
end
```

**Via HTTP API (JavaScript)**:
```javascript
const response = await fetch('/api/sisyphus/executions', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    plan_path: '/path/to/plan.md',
    project_path: '/path/to/project',
    options: {
      approval_mode: 'autonomous',
      dry_run: false
    }
  })
});

const { success, execution_id, state } = await response.json();
```

### Getting Execution State

**Via Service (Ruby)**:
```ruby
service = ExecutionOrchestrationService.new
result = service.get_execution_state(execution_id: "exec-123")

if result[:success]
  state = result[:state]
  puts "Status: #{state[:status]}"
  puts "Progress: #{state[:progress_percentage]}%"
  puts "Files changed: #{state[:files_changed].size}"
end
```

**Via HTTP API (JavaScript)**:
```javascript
const response = await fetch(`/api/sisyphus/executions/${executionId}`);
const { success, state } = await response.json();

console.log(`Status: ${state.status}`);
console.log(`Progress: ${state.progress_percentage}%`);
```

### Listing Executions

**Via Service (Ruby)**:
```ruby
service = ExecutionOrchestrationService.new
result = service.list_executions(limit: 10)

if result[:success]
  result[:executions].each do |exec|
    puts "#{exec[:execution_id]}: #{exec[:status]} (#{exec[:started_at]})"
  end
end
```

**Via HTTP API (JavaScript)**:
```javascript
const response = await fetch('/api/sisyphus/executions?limit=10');
const { success, executions } = await response.json();

executions.forEach(exec => {
  console.log(`${exec.execution_id}: ${exec.status}`);
});
```

### Approval Workflow

**Get Pending Approval**:
```javascript
const response = await fetch(
  `/api/sisyphus/approvals/pending?execution_id=${executionId}`
);
const { approval } = await response.json();

if (approval) {
  console.log(`Approval needed for: ${approval.subject_title}`);
  console.log(`Planned actions: ${approval.planned_actions.length}`);
}
```

**Approve a Request**:
```javascript
await fetch(`/api/sisyphus/approvals/${approvalId}/approve`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ resolved_by: 'user@example.com' })
});
```

**Reject a Request**:
```javascript
await fetch(`/api/sisyphus/approvals/${approvalId}/reject`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ resolved_by: 'user@example.com' })
});
```

---

## Common Patterns

### Pattern 1: Start and Monitor Until Complete

```ruby
service = ExecutionOrchestrationService.new

# Start execution
result = service.start_execution(
  plan_path: plan_path,
  project_path: project_path
)

execution_id = result[:execution_id]

# Poll until complete
loop do
  state_result = service.get_execution_state(execution_id: execution_id)
  state = state_result[:state]
  
  puts "Progress: #{state[:progress_percentage]}%"
  
  break if %i[complete failed].include?(state[:status])
  
  sleep 2
end
```

### Pattern 2: Real-Time Updates with SSE (Frontend)

```javascript
import { subscribeToWorkerProgress } from './utils/workerProgressStream';

function startExecution(planPath, projectPath) {
  // Start execution
  const { execution_id } = await createExecution({ planPath, projectPath });
  
  // Subscribe to progress
  const eventSource = subscribeToWorkerProgress({
    streamUrl: `/api/sisyphus/executions/${execution_id}/stream`,
    onEvent: (event) => {
      // Update UI based on event type
      handleProgressEvent(event);
    },
    onComplete: (data) => {
      showCompletionMessage(data);
    },
    onError: (error) => {
      showErrorMessage(error);
    }
  });
  
  return eventSource;
}
```

### Pattern 3: Step-by-Step Approval Workflow

```ruby
# This would typically be in a worker or service
gate = ApprovalGateService.new

if gate.approval_required?(approval_mode: config.approval_mode, type: :step)
  # Request approval
  result = gate.request_and_wait(
    execution_id: execution_id,
    type: :step,
    subject: step,
    planned_actions: planned_actions,
    estimated_changes: estimated_changes,
    timeout_seconds: 300
  )
  
  case result
  when :approved
    # Continue with execution
    execute_step(step)
  when :rejected
    # Skip this step
    log_info "Step #{step.title} was rejected by user"
    next
  when :timeout
    # Handle timeout
    raise "Approval timeout for step: #{step.title}"
  end
else
  # No approval needed, execute directly
  execute_step(step)
end
```

---

## Troubleshooting

### Redis Connection Error
```
Error: Redis::CannotConnectError
```

**Solution**: Make sure Redis is running:
```bash
redis-server
```

### LLM API Error
```
Error: OpenAI::AuthenticationError
```

**Solution**: Check your API keys in `.env`:
```bash
# .env
OPENAI_API_KEY=your_key_here
```

### Plan File Not Found
```
Error: Plan file not found: /path/to/plan.md
```

**Solution**: Ensure the plan file exists and the path is correct:
```bash
ls -la examples/plans/
```

### Execution Timeout
If execution takes longer than expected:

1. Check execution state manually:
   ```ruby
   service = ExecutionOrchestrationService.new
   result = service.get_execution_state(execution_id: "your-exec-id")
   puts result[:state].inspect
   ```

2. Check Redis for execution state:
   ```bash
   redis-cli KEYS "sisyphus:execution:*"
   redis-cli GET "sisyphus:execution:your-exec-id"
   ```

3. Check worker logs for errors

---

## Next Steps

1. **Try the basic example**: `./examples/01_basic_execution.rb`
2. **Explore configurations**: `./examples/02_configuration_options.rb`
3. **Test real-time monitoring**: `./examples/05_realtime_monitoring.rb`
4. **Create your own plan**: Add a plan to `examples/plans/`
5. **Read the documentation**:
   - `docs/architecture/streaming_progress.md` - Real-time streaming guide
   - `docs/features/approval_mode.md` - Approval mode guide
   - `docs/projects/01-01-2026_act_agent_worker/README.md` - Project overview

---

## Additional Resources

- **API Documentation**: See `app/controllers/sisyphus_controller.rb` for all available endpoints
- **Frontend Integration**: See `frontend/src/api/sisyphusApi.js` for JavaScript API
- **Real-Time Utilities**: See `app/javascript/utils/workerProgressStream.js` for SSE helpers
- **Test Examples**: See `test/integration/sisyphus_*_test.rb` for test patterns

---

**Have questions?** Check the main project documentation in `docs/` or review the test files for more examples.








