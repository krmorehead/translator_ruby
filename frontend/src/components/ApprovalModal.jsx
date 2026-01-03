import React from "react";
import "./ApprovalModal.css";

/**
 * ApprovalModal - Modal dialog for approving/rejecting Sisyphus execution steps/milestones
 * 
 * Props:
 * - approval: ApprovalRequest object from backend
 * - onApprove: Callback for approve action
 * - onReject: Callback for reject action
 * - onClose: Callback to close modal
 * - loading: Boolean indicating approval action in progress
 */
function ApprovalModal({ approval, onApprove, onReject, onClose, loading = false }) {
  if (!approval) return null;

  const isStep = approval.type === "step";
  const isMilestone = approval.type === "milestone";

  const handleApprove = () => {
    if (!loading) {
      onApprove(approval.id);
    }
  };

  const handleReject = () => {
    if (!loading) {
      onReject(approval.id);
    }
  };

  const handleBackdropClick = (e) => {
    if (e.target.className === "approval-modal-backdrop" && !loading) {
      onClose();
    }
  };

  const formatTimestamp = (timestamp) => {
    if (!timestamp) return "N/A";
    const date = new Date(timestamp);
    return date.toLocaleString();
  };

  const getRemainingTime = () => {
    if (!approval.timeout_at) return null;
    const now = Date.now();
    const timeout = new Date(approval.timeout_at).getTime();
    const remaining = timeout - now;
    
    if (remaining <= 0) return "EXPIRED";
    
    const minutes = Math.floor(remaining / 60000);
    const seconds = Math.floor((remaining % 60000) / 1000);
    return `${minutes}m ${seconds}s`;
  };

  const [remainingTime, setRemainingTime] = React.useState(getRemainingTime());

  // Update remaining time every second
  React.useEffect(() => {
    const interval = setInterval(() => {
      setRemainingTime(getRemainingTime());
    }, 1000);

    return () => clearInterval(interval);
  }, [approval.timeout_at]);

  return (
    <div className="approval-modal-backdrop" onClick={handleBackdropClick}>
      <div className="approval-modal">
        {/* Header */}
        <div className="approval-modal-header">
          <h2>
            {isStep ? "⚙️" : "📁"} Approval Required
          </h2>
          <button
            className="approval-modal-close"
            onClick={onClose}
            disabled={loading}
            aria-label="Close"
          >
            ✕
          </button>
        </div>

        {/* Body */}
        <div className="approval-modal-body">
          {/* Type and Subject */}
          <div className="approval-section">
            <div className="approval-label">Type:</div>
            <div className="approval-value">
              <span className={`approval-type-badge ${approval.type}`}>
                {approval.type.toUpperCase()}
              </span>
            </div>
          </div>

          <div className="approval-section">
            <div className="approval-label">
              {isStep ? "Step:" : "Milestone:"}
            </div>
            <div className="approval-value approval-subject">
              {approval.subject_title}
            </div>
          </div>

          {/* Timing */}
          <div className="approval-section">
            <div className="approval-label">Requested:</div>
            <div className="approval-value">{formatTimestamp(approval.created_at)}</div>
          </div>

          {remainingTime && (
            <div className="approval-section">
              <div className="approval-label">Time Remaining:</div>
              <div className={`approval-value ${remainingTime === "EXPIRED" ? "expired" : ""}`}>
                {remainingTime}
              </div>
            </div>
          )}

          {/* Planned Actions */}
          {approval.planned_actions && approval.planned_actions.length > 0 && (
            <div className="approval-section approval-actions">
              <div className="approval-label">
                Planned Actions ({approval.planned_actions.length}):
              </div>
              <div className="approval-actions-list">
                {approval.planned_actions.map((action, index) => (
                  <div key={index} className="approval-action-item">
                    <span className="action-number">{index + 1}.</span>
                    <span className="action-text">{action}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Estimated Changes */}
          {approval.estimated_changes && (
            <div className="approval-section">
              <div className="approval-label">Estimated Changes:</div>
              <div className="approval-changes">
                {approval.estimated_changes.files_to_create && (
                  <div className="change-stat">
                    <span className="change-icon">📝</span>
                    <span>Create: {approval.estimated_changes.files_to_create} file(s)</span>
                  </div>
                )}
                {approval.estimated_changes.files_to_modify && (
                  <div className="change-stat">
                    <span className="change-icon">✏️</span>
                    <span>Modify: {approval.estimated_changes.files_to_modify} file(s)</span>
                  </div>
                )}
                {approval.estimated_changes.files_to_delete && (
                  <div className="change-stat">
                    <span className="change-icon">🗑️</span>
                    <span>Delete: {approval.estimated_changes.files_to_delete} file(s)</span>
                  </div>
                )}
                {approval.estimated_changes.commands_to_run && (
                  <div className="change-stat">
                    <span className="change-icon">⚡</span>
                    <span>Execute: {approval.estimated_changes.commands_to_run} command(s)</span>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Execution Context */}
          {approval.execution_id && (
            <div className="approval-section">
              <div className="approval-label">Execution ID:</div>
              <div className="approval-value approval-execution-id">
                {approval.execution_id}
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="approval-modal-footer">
          <button
            className="approval-button reject"
            onClick={handleReject}
            disabled={loading || remainingTime === "EXPIRED"}
          >
            {loading ? "Processing..." : "✗ Reject"}
          </button>
          <button
            className="approval-button approve"
            onClick={handleApprove}
            disabled={loading || remainingTime === "EXPIRED"}
          >
            {loading ? "Processing..." : "✓ Approve"}
          </button>
        </div>

        {/* Warning if expired */}
        {remainingTime === "EXPIRED" && (
          <div className="approval-expired-warning">
            ⏱️ This approval request has expired. The execution may have already timed out.
          </div>
        )}
      </div>
    </div>
  );
}

export default ApprovalModal;


