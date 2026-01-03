# Approval UI Integration

## Overview

The Approval UI provides a visual interface for users to approve or reject execution steps/milestones when approval mode is enabled in Sisyphus. This document covers the frontend implementation.

## Components

### ApprovalModal Component

**Location**: `frontend/src/components/ApprovalModal.jsx`

A modal dialog that displays approval requests with detailed information about planned actions and estimated changes.

**Props**:
- `approval` (Object): ApprovalRequest object from backend
- `onApprove` (Function): Callback when user approves
- `onReject` (Function): Callback when user rejects
- `onClose` (Function): Callback to close modal without action
- `loading` (Boolean): Indicates approval action in progress

**Features**:
- Real-time countdown timer showing time remaining
- Display of planned actions (bulleted list)
- Estimated changes breakdown (files to create/modify/delete, commands to run)
- Type indicator (Step vs. Milestone)
- Subject title prominently displayed
- Expired state handling
- Responsive design

**Example Usage**:
```jsx
import ApprovalModal from './ApprovalModal';

function MyComponent() {
  const [approval, setApproval] = useState(null);
  
  return (
    <ApprovalModal
      approval={approval}
      onApprove={(id) => handleApprove(id)}
      onReject={(id) => handleReject(id)}
      onClose={() => setApproval(null)}
      loading={false}
    />
  );
}
```

## Store Integration

### Sisyphus Store Updates

**Location**: `frontend/src/store/sisyphusStore.js`

**New State Fields**:
```javascript
{
  pendingApproval: null,           // Current ApprovalRequest object
  approvalLoading: false,          // Approval action in progress
  approvalError: "",               // Error message from approval API
  approvalPollingInterval: null    // Interval ID for polling
}
```

**New Actions**:

#### `fetchPendingApproval(executionId)`
Fetches the pending approval request for an execution.

**Returns**: `ApprovalRequest` object or `null`

```javascript
const approval = await fetchPendingApproval(executionId);
if (approval) {
  console.log(`Approval required for: ${approval.subject_title}`);
}
```

#### `approveRequest(requestId)`
Approves a pending approval request.

**Returns**: `true` on success, `false` on error

```javascript
const success = await approveRequest(requestId);
if (success) {
  console.log('Approved!');
}
```

#### `rejectRequest(requestId)`
Rejects a pending approval request.

**Returns**: `true` on success, `false` on error

```javascript
const success = await rejectRequest(requestId);
if (success) {
  console.log('Rejected');
}
```

#### `startApprovalPolling(executionId, intervalMs = 2000)`
Starts polling for pending approval requests at regular intervals.

```javascript
// Start polling when execution begins
startApprovalPolling(executionId, 2000); // Poll every 2 seconds
```

**Behavior**:
- Polls the approval endpoint every `intervalMs` milliseconds
- Automatically stops when execution completes/fails/cancels
- Clears any existing polling interval before starting new one

#### `stopApprovalPolling()`
Stops the approval polling interval.

```javascript
// Stop polling manually
stopApprovalPolling();
```

#### `clearApproval()`
Clears the pending approval state.

```javascript
// Clear approval when modal is closed
clearApproval();
```

## SisyphusPage Integration

**Location**: `frontend/src/components/SisyphusPage.jsx`

### Changes Made

1. **Import ApprovalModal**:
```jsx
import ApprovalModal from "./ApprovalModal";
```

2. **Access approval state**:
```jsx
const {
  pendingApproval,
  approvalLoading,
  approvalError,
  fetchPendingApproval,
  approveRequest,
  rejectRequest,
  startApprovalPolling,
  stopApprovalPolling,
  clearApproval
} = useSisyphusStore();
```

3. **Start polling on execution start**:
```jsx
const handleStartExecution = async () => {
  try {
    const result = await startExecution(planPath, projectPath);
    if (result && result.execution_id) {
      startApprovalPolling(result.execution_id); // <-- Start polling
    }
  } catch (error) {
    console.error("Failed to start execution:", error);
  }
};
```

4. **Render modal when approval pending**:
```jsx
{pendingApproval && (
  <ApprovalModal
    approval={pendingApproval}
    onApprove={handleApprove}
    onReject={handleReject}
    onClose={handleCloseApprovalModal}
    loading={approvalLoading}
  />
)}
```

5. **Show "AWAITING APPROVAL" badge in status**:
```jsx
{pendingApproval && (
  <div style={{
    display: "inline-block",
    marginLeft: "0.5rem",
    padding: "0.25rem 0.75rem",
    background: "#FF9800",
    color: "white",
    borderRadius: "12px",
    fontSize: "0.85rem",
    fontWeight: "bold"
  }}>
    ⏸️ AWAITING APPROVAL
  </div>
)}
```

6. **Cleanup polling on unmount**:
```jsx
React.useEffect(() => {
  return () => {
    stopApprovalPolling();
  };
}, [stopApprovalPolling]);
```

## User Flow

### Autonomous Mode (No Approvals)
1. User starts execution
2. Execution runs to completion
3. No approval modals appear

### Step Approval Mode
1. User starts execution with `approval_mode: :step`
2. Execution begins
3. Frontend polls for pending approval every 2 seconds
4. When step is planned, backend creates `ApprovalRequest`
5. Frontend detects approval and shows modal
6. Modal displays:
   - Step title
   - Planned actions
   - Estimated changes
   - Time remaining (5 minutes default)
7. User clicks "Approve" or "Reject"
8. Frontend sends approval decision to backend
9. Backend resumes/skips step based on decision
10. Modal closes, execution continues
11. Process repeats for each step

### Milestone Approval Mode
Same as step mode, but approval is requested once per milestone (group of steps).

### Timeout Handling
1. If user doesn't respond within timeout period (default 5 minutes):
2. Modal shows "EXPIRED" warning
3. Approve/Reject buttons are disabled
4. Backend automatically times out the approval
5. Execution may continue with default behavior or fail, depending on configuration

## Styling

### ApprovalModal.css

**Key Styles**:
- **Backdrop**: Semi-transparent black overlay (`rgba(0, 0, 0, 0.6)`)
- **Modal**: White, rounded corners, centered, max-width 600px
- **Animations**: Fade-in backdrop, slide-up modal
- **Colors**:
  - Approve button: Green (`#4CAF50`)
  - Reject button: Red (`#f44336`)
  - Step badge: Green (`#4CAF50`)
  - Milestone badge: Orange (`#FF9800`)
  - Expired text: Red (`#f44336`) with pulse animation
- **Responsive**: Mobile-friendly with stacked buttons on small screens

**Accessibility**:
- Close button has `aria-label="Close"`
- Keyboard navigation supported
- Focus management
- Disabled states clearly indicated

## API Integration

### Backend Endpoints Used

**Get Pending Approval**:
```javascript
GET /api/sisyphus/approvals/pending?execution_id={id}

Response:
{
  "approval": {
    "id": "approval-123",
    "type": "step",
    "status": "pending",
    "subject_title": "Create hello.rb",
    "planned_actions": ["Create file hello.rb", "Make executable"],
    "estimated_changes": {
      "files_to_create": 1,
      "files_to_modify": 0
    },
    "timeout_at": "2026-01-02T15:05:00Z",
    "created_at": "2026-01-02T15:00:00Z"
  }
}
```

**Approve Request**:
```javascript
POST /api/sisyphus/approvals/{id}/approve
Body: { "resolved_by": "user@example.com" }

Response:
{
  "success": true,
  "message": "Approval request approved"
}
```

**Reject Request**:
```javascript
POST /api/sisyphus/approvals/{id}/reject
Body: { "resolved_by": "user@example.com" }

Response:
{
  "success": true,
  "message": "Approval request rejected"
}
```

## Testing

### Manual Testing Checklist

- [ ] Start execution with `approval_mode: :step`
- [ ] Verify modal appears when approval required
- [ ] Verify planned actions display correctly
- [ ] Verify estimated changes display correctly
- [ ] Verify countdown timer updates every second
- [ ] Click "Approve" and verify execution continues
- [ ] Click "Reject" and verify execution skips step
- [ ] Close modal without action and verify it can be reopened
- [ ] Wait for timeout and verify expired state
- [ ] Test with milestone approval mode
- [ ] Test responsive design on mobile
- [ ] Test keyboard navigation

### Integration Testing

See `examples/03_approval_mode.rb` for backend testing examples.

For frontend E2E tests with Playwright (TODO), see:
- `frontend/e2e/approval.spec.js` (planned)

## Troubleshooting

### Modal doesn't appear
**Possible causes**:
1. Approval mode is set to `:autonomous`
2. Polling hasn't started (check console for errors)
3. Backend approval service not running
4. Redis connection issue

**Solution**: Check execution configuration and backend logs.

### Timeout happens too quickly
**Solution**: Increase timeout in backend configuration:
```ruby
ApprovalGateService.new(
  timeout_seconds: 600  # 10 minutes instead of default 5
)
```

### Multiple modals appear
**Issue**: Rapid polling or multiple executions running.

**Solution**: Ensure `clearApproval()` is called after approval actions and polling is stopped when execution completes.

## Future Enhancements

1. **Approval History**: Show list of past approvals/rejections
2. **Batch Approval**: Approve multiple steps at once
3. **Custom Timeout**: User-configurable timeout per request
4. **Approval Comments**: Allow users to add notes when approving/rejecting
5. **Approval Notifications**: Browser notifications when approval required
6. **Approval Queue**: Show all pending approvals across multiple executions
7. **Approval Templates**: Save common approval patterns for reuse

## Related Documentation

- Backend: `docs/features/approval_mode.md`
- Examples: `examples/03_approval_mode.rb` (TODO)
- API: `app/controllers/sisyphus_controller.rb`
- Service: `app/services/approval_gate_service.rb`








