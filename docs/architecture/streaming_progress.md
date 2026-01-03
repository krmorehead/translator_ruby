# Worker Progress Streaming Architecture

## Overview

The streaming progress system provides real-time updates for all worker executions (Sisyphus, Daedalus, ProjectPlanner, etc.) using Server-Sent Events (SSE) over Redis pub/sub.

## Architecture Components

### 1. ExecutionProgressBroadcaster (Backend Service)

**Location**: `app/services/execution_progress_broadcaster.rb`

**Purpose**: General-purpose service for publishing worker progress events to Redis pub/sub channels.

**Key Features**:
- Worker-agnostic (not tied to any specific worker)
- Uses Redis pub/sub for real-time event distribution
- Supports 12 standard event types
- Type-safe with strict validation

**Usage Example**:
```ruby
broadcaster = ExecutionProgressBroadcaster.new

# Broadcast step started event
broadcaster.broadcast_step_started(
  execution_id: "exec-123",
  step_number: 1,
  step_title: "Initialize project"
)

# Broadcast step completed with progress
broadcaster.broadcast_step_completed(
  execution_id: "exec-123",
  step_number: 1,
  files_changed: ["README.md"],
  progress_percentage: 25.0
)
```

**Event Types**:
- `started` - Execution began
- `milestone_started` - Milestone phase started
- `milestone_completed` - Milestone phase completed
- `step_started` - Individual step started
- `step_completed` - Individual step completed
- `step_failed` - Step failed with error
- `file_changed` - File was modified
- `checkpoint_created` - Git checkpoint created
- `completed` - Execution completed successfully
- `failed` - Execution failed
- `cancelled` - Execution cancelled by user

### 2. StreamableExecution (Controller Concern)

**Location**: `app/controllers/concerns/streamable_execution.rb`

**Purpose**: Reusable concern for controllers that need to stream execution progress via SSE.

**Key Features**:
- Encapsulates SSE setup and error handling
- Automatic connection management
- Graceful client disconnection handling
- Terminal event detection (auto-close on completion/failure/cancellation)

**Usage in Controllers**:
```ruby
class MyWorkerController < ApplicationController
  include ActionController::Live
  include StreamableExecution

  def stream_progress
    stream_execution_progress(params[:execution_id])
  end
end
```

**What it handles**:
- SSE headers configuration
- Initial connection event
- Event subscription and forwarding
- Client disconnection (IOError, ClientDisconnected)
- Error handling and logging
- Stream cleanup

### 3. Worker Integration

**How Workers Use the Broadcaster**:

```ruby
class SisyphusWorker
  def perform(plan_path, project_path, execution_id)
    @broadcaster = ExecutionProgressBroadcaster.new
    
    # Notify start
    @broadcaster.broadcast_started(
      execution_id: execution_id,
      plan_path: plan_path,
      project_path: project_path
    )
    
    # During execution
    milestones.each do |milestone|
      @broadcaster.broadcast_milestone_started(
        execution_id: execution_id,
        milestone_number: milestone.number,
        milestone_title: milestone.title
      )
      
      # Execute milestone...
      
      @broadcaster.broadcast_milestone_completed(
        execution_id: execution_id,
        milestone_number: milestone.number,
        checkpoint_id: checkpoint.id
      )
    end
    
    # Notify completion
    @broadcaster.broadcast_completed(
      execution_id: execution_id,
      total_files_changed: execution_record.total_files_changed,
      total_steps: execution_record.total_steps
    )
  end
end
```

### 4. Frontend Integration

#### JavaScript Utility (General Purpose)

**Location**: `app/javascript/utils/workerProgressStream.js`

**Purpose**: Reusable client-side utility for subscribing to any worker's progress.

**Usage**:
```javascript
import { subscribeToWorkerProgress, createStoreProgressHandler } from './utils/workerProgressStream';

// Subscribe to progress
const eventSource = subscribeToWorkerProgress({
  streamUrl: `/api/sisyphus/executions/${executionId}/stream`,
  onEvent: (event) => {
    console.log('Progress:', event);
  },
  onError: (error) => {
    console.error('Stream error:', error);
  },
  onComplete: (data) => {
    console.log('Execution complete:', data);
  }
});

// Later, unsubscribe
eventSource.close();
```

**With Zustand Store**:
```javascript
import { createStoreProgressHandler } from './utils/workerProgressStream';

const progressHandler = createStoreProgressHandler(
  useSisyphusStore.setState,
  'currentExecution'
);

const eventSource = subscribeToWorkerProgress({
  streamUrl: `/api/sisyphus/executions/${executionId}/stream`,
  onEvent: progressHandler,
  onComplete: (data) => {
    console.log('Done:', data);
  }
});
```

#### API-Specific Wrapper

**Location**: `frontend/src/api/sisyphusApi.js`

**Purpose**: Convenience wrapper for Sisyphus-specific usage.

```javascript
import { subscribeToExecutionProgress } from '../api/sisyphusApi';

const eventSource = subscribeToExecutionProgress(executionId, {
  onEvent: (event) => updateUI(event),
  onError: (error) => showError(error),
  onComplete: (data) => showComplete(data)
});
```

## Data Flow

```
Worker (Backend)
  ↓
ExecutionProgressBroadcaster
  ↓
Redis Pub/Sub Channel: "worker:progress:{execution_id}"
  ↓
Controller (StreamableExecution concern)
  ↓
SSE Stream (HTTP)
  ↓
Frontend EventSource
  ↓
React Component / Zustand Store
```

## Redis Channel Structure

**Channel Pattern**: `worker:progress:{execution_id}`

**Examples**:
- `worker:progress:sisyphus-abc123`
- `worker:progress:daedalus-def456`
- `worker:progress:planner-ghi789`

**Event Format**:
```json
{
  "execution_id": "sisyphus-abc123",
  "event_type": "step_completed",
  "timestamp": "2026-01-02T14:30:00Z",
  "data": {
    "step_number": 3,
    "files_changed": ["src/app.js", "src/utils.js"],
    "progress_percentage": 60.0
  }
}
```

## Adding Streaming to a New Worker

### Step 1: Add Route
```ruby
# config/routes.rb
get "/api/my_worker/executions/:execution_id/stream", to: "my_worker#stream_execution"
```

### Step 2: Include Concern in Controller
```ruby
# app/controllers/my_worker_controller.rb
class MyWorkerController < ApplicationController
  include ActionController::Live
  include StreamableExecution

  def stream_execution
    stream_execution_progress(params[:execution_id])
  end
end
```

### Step 3: Broadcast from Worker
```ruby
# app/workers/my_worker.rb
class MyWorker
  def perform(execution_id)
    broadcaster = ExecutionProgressBroadcaster.new
    
    broadcaster.broadcast_started(
      execution_id: execution_id,
      plan_path: @plan_path,
      project_path: @project_path
    )
    
    # ... do work and broadcast progress ...
    
    broadcaster.broadcast_completed(
      execution_id: execution_id,
      total_files_changed: 10,
      total_steps: 5
    )
  end
end
```

### Step 4: Subscribe in Frontend
```javascript
import { subscribeToWorkerProgress } from './utils/workerProgressStream';

const eventSource = subscribeToWorkerProgress({
  streamUrl: `/api/my_worker/executions/${executionId}/stream`,
  onEvent: handleProgressEvent,
  onComplete: handleComplete
});
```

## Benefits of This Architecture

1. **Reusable**: One broadcaster, one concern, one utility - works for all workers
2. **Scalable**: Redis pub/sub handles multiple subscribers efficiently
3. **Type-Safe**: Strict validation on event types and parameters
4. **Fault-Tolerant**: Graceful handling of disconnections and errors
5. **Consistent**: All workers emit the same event types
6. **Testable**: Each component can be tested independently
7. **Maintainable**: Changes to streaming logic happen in one place

## Testing

### Backend Tests
```ruby
# test/services/execution_progress_broadcaster_test.rb
test "broadcasts step completed event" do
  broadcaster = ExecutionProgressBroadcaster.new(redis: @redis)
  
  result = broadcaster.broadcast_step_completed(
    execution_id: "test-123",
    step_number: 1,
    progress_percentage: 50.0
  )
  
  assert result > 0, "Should have subscribers"
end
```

### Frontend Tests
```javascript
// test/utils/workerProgressStream.test.js
test('subscribes to progress events', () => {
  const mockEventSource = subscribeToWorkerProgress({
    streamUrl: '/api/test/stream',
    onEvent: jest.fn(),
    onComplete: jest.fn()
  });
  
  expect(mockEventSource).toBeDefined();
});
```

## Performance Considerations

- **Redis Pub/Sub**: Minimal overhead, handles thousands of subscribers
- **SSE**: More efficient than polling, maintains single HTTP connection
- **Event Size**: Keep event payloads small (< 1KB recommended)
- **Cleanup**: Always close EventSource when component unmounts
- **Reconnection**: Frontend handles automatic reconnection on network issues

## Security

- **Authentication**: Verify execution_id ownership before streaming
- **Authorization**: Check user has permission to view execution
- **Rate Limiting**: Consider rate limits on SSE endpoints
- **Validation**: Validate execution_id format to prevent injection

## Future Enhancements

- [ ] Add authentication/authorization to SSE endpoints
- [ ] Implement event replay for reconnecting clients
- [ ] Add metrics/monitoring for stream health
- [ ] Support filtering events by type on frontend
- [ ] Add compression for large event payloads
- [ ] Implement backpressure handling for slow clients








