# Approval Mode Feature

## Overview

Approval mode allows users to control Sisyphus execution by requiring manual approval before executing steps or milestones. This provides safety and oversight for autonomous execution.

## Approval Modes

### 1. Autonomous (Default)
No approvals required. Sisyphus executes the entire plan automatically.

```ruby
config = Configuration::SisyphusConfig.new(
  approval_mode: :autonomous,
  # ... other options
)
```

### 2. Step Mode
Approval required before executing each step.

```ruby
config = Configuration::SisyphusConfig.new(
  approval_mode: :step,
  # ... other options
)
```

### 3. Milestone Mode
Approval required before executing each milestone.

```ruby
config = Configuration::SisyphusConfig.new(
  approval_mode: :milestone,
  # ... other options
)
```

## Architecture Components

### 1. Execution::ApprovalRequest (Domain Model)
**Location**: `app/models/execution/approval_request.rb`

Represents a pending approval request with:
- `id` - Unique identifier
- `execution_id` - Associated execution
- `type` - `:step` or `:milestone`
- `status` - `:pending`, `:approved`, `:rejected`, or `:timeout`
- `subject_id` - ID of step/milestone
- `subject_title` - Title of step/milestone
- `planned_actions` - Array of planned tool calls
- `estimated_changes` - Hash of estimated file changes
- `timeout_seconds` - Approval timeout (default: 300 = 5 minutes)

**Methods**:
- `approve(resolved_by:)` - Mark as approved
- `reject(resolved_by:)` - Mark as rejected
- `mark_timeout` - Mark as timed out
- `pending?`, `approved?`, `rejected?`, `timeout?` - Status checks
- `expired?` - Check if timeout has passed

### 2. ApprovalRequestStore (Persistence)
**Location**: `app/services/approval_request_store.rb`

Redis-backed storage for approval requests.

**Key Methods**:
```ruby
store = ApprovalRequestStore.new

# Save a request
store.save(request)

# Get a request
request = store.get(request_id)

# List requests for an execution
requests = store.list_for_execution(execution_id: "exec-123", status: :pending)

# Get pending approval
pending = store.get_pending_for_execution("exec-123")

# Approve/reject
approved_request = store.approve(request_id: "req-123", resolved_by: "user")
rejected_request = store.reject(request_id: "req-123", resolved_by: "user")

# Wait for resolution (blocking)
resolved = store.wait_for_resolution("req-123", timeout: 300)
```

### 3. ApprovalGateService (Workflow Integration)
**Location**: `app/services/approval_gate_service.rb`

Service for creating approval gates in worker execution.

**Usage in Workers**:
```ruby
class SisyphusWorker
  def perform(plan_path, project_path, execution_id)
    @approval_gate = ApprovalGateService.new
    @config = load_config # Returns SisyphusConfig
    
    milestones.each do |milestone|
      # Check if milestone approval is required
      if @approval_gate.approval_required?(
        approval_mode: @config.approval_mode,
        type: :milestone
      )
        # Request and wait for approval
        result = @approval_gate.request_and_wait(
          execution_id: execution_id,
          type: :milestone,
          subject: milestone,
          planned_actions: estimate_milestone_actions(milestone),
          estimated_changes: estimate_milestone_changes(milestone),
          timeout_seconds: 300
        )
        
        # Handle result
        case result
        when :approved
          # Continue execution
        when :rejected
          # Skip milestone
          next
        when :timeout
          # Handle timeout (maybe skip or fail)
          raise "Approval timeout for milestone: #{milestone.title}"
        end
      end
      
      # Execute milestone...
      milestone.steps.each do |step|
        # Check if step approval is required
        if @approval_gate.approval_required?(
          approval_mode: @config.approval_mode,
          type: :step
        )
          result = @approval_gate.request_and_wait(
            execution_id: execution_id,
            type: :step,
            subject: step,
            planned_actions: plan_step_actions(step),
            estimated_changes: estimate_step_changes(step),
            timeout_seconds: 300
          )
          
          # Handle step approval result
          next if result == :rejected
          raise "Approval timeout for step: #{step.title}" if result == :timeout
        end
        
        # Execute step...
      end
    end
  end
end
```

## API Endpoints

### GET /api/sisyphus/approvals/pending
Get pending approval for an execution.

**Request**:
```
GET /api/sisyphus/approvals/pending?execution_id=exec-123
```

**Response**:
```json
{
  "approval": {
    "id": "req-456",
    "execution_id": "exec-123",
    "type": "step",
    "status": "pending",
    "subject_id": "step-789",
    "subject_title": "Create configuration files",
    "planned_actions": [
      { "tool": "write_file", "path": "config/app.yml" }
    ],
    "estimated_changes": {
      "files_created": 1,
      "files_modified": 0
    },
    "created_at": "2026-01-02T15:00:00Z",
    "timeout_seconds": 300
  }
}
```

### POST /api/sisyphus/approvals/:request_id/approve
Approve an approval request.

**Request**:
```
POST /api/sisyphus/approvals/req-456/approve
Content-Type: application/json

{
  "resolved_by": "user@example.com"
}
```

**Response**:
```json
{
  "success": true,
  "approval": {
    "id": "req-456",
    "status": "approved",
    "resolved_at": "2026-01-02T15:01:00Z",
    "resolved_by": "user@example.com"
  }
}
```

### POST /api/sisyphus/approvals/:request_id/reject
Reject an approval request.

**Request**:
```
POST /api/sisyphus/approvals/req-456/reject
Content-Type: application/json

{
  "resolved_by": "user@example.com"
}
```

**Response**:
```json
{
  "success": true,
  "approval": {
    "id": "req-456",
    "status": "rejected",
    "resolved_at": "2026-01-02T15:01:00Z",
    "resolved_by": "user@example.com"
  }
}
```

### GET /api/sisyphus/approvals/:request_id
Get approval request status.

**Response**:
```json
{
  "approval": {
    "id": "req-456",
    "status": "pending",
    ...
  }
}
```

## Frontend Integration

### JavaScript API
**Location**: `frontend/src/api/sisyphusApi.js`

```javascript
import { 
  getPendingApproval, 
  approveRequest, 
  rejectRequest,
  getApprovalStatus
} from '../api/sisyphusApi';

// Get pending approval
const { approval } = await getPendingApproval(executionId);

// Approve
await approveRequest(approval.id, "user@example.com");

// Reject
await rejectRequest(approval.id, "user@example.com");

// Check status
const { approval: status } = await getApprovalStatus(approval.id);
```

### Real-Time Events (SSE)

Approval events are broadcast via SSE:

```javascript
eventSource.addEventListener('approval_required', (event) => {
  const data = JSON.parse(event.data);
  // Show approval modal
  showApprovalModal({
    approvalId: data.approval_id,
    type: data.type,
    title: data.subject_title,
    actions: data.planned_actions,
    changes: data.estimated_changes
  });
});

eventSource.addEventListener('approval_approved', (event) => {
  const data = JSON.parse(event.data);
  // Hide modal, show success
});

eventSource.addEventListener('approval_rejected', (event) => {
  const data = JSON.parse(event.data);
  // Hide modal, show rejection
});

eventSource.addEventListener('approval_timeout', (event) => {
  const data = JSON.parse(event.data);
  // Show timeout message
});
```

## UI Implementation (Future)

The approval UI modal should display:

1. **Request Information**
   - Execution ID
   - Type (Step or Milestone)
   - Subject title
   - Timestamp

2. **Planned Actions**
   - List of tools to be executed
   - Parameters for each tool
   - Estimated duration

3. **Estimated Changes**
   - Files to be created
   - Files to be modified
   - Files to be deleted
   - Preview of changes (if available)

4. **Actions**
   - Approve button (green)
   - Reject button (red)
   - Countdown timer showing timeout

5. **Safety Features**
   - Require confirmation for destructive operations
   - Show diff preview for file modifications
   - Display warning for high-risk actions

## Testing

### Unit Tests
```ruby
# test/models/execution/approval_request_test.rb
test "approval request can be approved" do
  request = Execution::ApprovalRequest.new(...)
  approved = request.approve(resolved_by: "user")
  
  assert approved.approved?
  assert_equal "user", approved.resolved_by
end

# test/services/approval_gate_service_test.rb
test "request_and_wait returns approved" do
  service = ApprovalGateService.new
  
  # In parallel, approve the request
  Thread.new do
    sleep 0.1
    store.approve(request_id: request.id, resolved_by: "user")
  end
  
  result = service.wait_for_approval(request.id, timeout_seconds: 5)
  assert_equal :approved, result
end
```

### Integration Tests
```ruby
# test/integration/sisyphus_approval_mode_test.rb
test "step approval mode requires approval for each step" do
  config = Configuration::SisyphusConfig.new(approval_mode: :step, ...)
  
  # Start execution
  # Verify approval request is created
  # Approve the request
  # Verify step executes
end
```

## Security Considerations

1. **Authentication**: Verify user identity before approving/rejecting
2. **Authorization**: Check user has permission to approve for this execution
3. **Audit Trail**: Log all approval decisions with timestamps and user IDs
4. **Timeout**: Prevent indefinite waiting with reasonable timeouts
5. **Rate Limiting**: Limit approval requests per execution
6. **Validation**: Validate approval request IDs to prevent injection

## Future Enhancements

- [ ] Granular permissions (who can approve what)
- [ ] Multi-level approval (require N approvers)
- [ ] Approval templates (pre-approve common patterns)
- [ ] Diff preview in approval UI
- [ ] Approval history and audit log
- [ ] Email/Slack notifications for approval requests
- [ ] Mobile-friendly approval interface
- [ ] Batch approval for multiple steps
- [ ] Conditional auto-approval based on rules
- [ ] Integration with external approval systems (JIRA, ServiceNow, etc.)


