import { BaseRequest } from "./BaseRequest";

/**
 * ApprovalRequest - Domain model for approval requests
 * 
 * Represents an approval request from the Sisyphus execution system.
 * Inherits from BaseRequest for common request functionality.
 * 
 * Mirrors the backend Execution::ApprovalRequest model.
 * 
 * STRICT OOP:
 * - Immutable (frozen after construction)
 * - Validates all inputs
 * - Fails fast with descriptive errors
 * - NO hash/JSON support - must use fromJSON()
 */
export class ApprovalRequest extends BaseRequest {
  // Approval types
  static TYPE_STEP = "step";
  static TYPE_MILESTONE = "milestone";

  // Approval statuses (extends base statuses)
  static STATUS_PENDING = "pending";
  static STATUS_APPROVED = "approved";
  static STATUS_REJECTED = "rejected";
  static STATUS_TIMEOUT = "timeout";

  constructor({
    id,
    executionId,
    type,
    status,
    subjectId,
    subjectTitle,
    plannedActions = [],
    estimatedChanges = {},
    createdAt,
    resolvedAt = null,
    resolvedBy = null,
    timeoutSeconds = 300
  }) {
    // Call parent constructor with base params
    super({ id, status, createdAt, resolvedAt, resolvedBy });

    // Validate approval-specific params
    this.validateApprovalParams(executionId, type, subjectId, subjectTitle, timeoutSeconds);

    // Set properties with underscore prefix for immutability
    this._executionId = executionId;
    this._type = type;
    this._subjectId = subjectId;
    this._subjectTitle = subjectTitle;
    this._plannedActions = Object.freeze([...plannedActions]);
    this._estimatedChanges = Object.freeze({ ...estimatedChanges });
    this._timeoutSeconds = timeoutSeconds;

    // Freeze the entire object - NO mutation allowed
    this.freeze();
  }

  validateApprovalParams(executionId, type, subjectId, subjectTitle, timeoutSeconds) {
    if (!executionId || typeof executionId !== "string") {
      throw new TypeError("ApprovalRequest: executionId must be a non-empty string");
    }
    if (!type || typeof type !== "string") {
      throw new TypeError("ApprovalRequest: type must be a non-empty string");
    }
    if (type !== ApprovalRequest.TYPE_STEP && type !== ApprovalRequest.TYPE_MILESTONE) {
      throw new TypeError(`ApprovalRequest: type must be '${ApprovalRequest.TYPE_STEP}' or '${ApprovalRequest.TYPE_MILESTONE}', got: ${type}`);
    }
    if (!subjectId || typeof subjectId !== "string") {
      throw new TypeError("ApprovalRequest: subjectId must be a non-empty string");
    }
    if (!subjectTitle || typeof subjectTitle !== "string") {
      throw new TypeError("ApprovalRequest: subjectTitle must be a non-empty string");
    }
    if (!Number.isInteger(timeoutSeconds) || timeoutSeconds <= 0) {
      throw new TypeError("ApprovalRequest: timeoutSeconds must be a positive integer");
    }
  }

  // Getters for read-only access
  get executionId() {
    return this._executionId;
  }

  get type() {
    return this._type;
  }

  get subjectId() {
    return this._subjectId;
  }

  get subjectTitle() {
    return this._subjectTitle;
  }

  get plannedActions() {
    return this._plannedActions; // Already frozen
  }

  get estimatedChanges() {
    return this._estimatedChanges; // Already frozen
  }

  get timeoutSeconds() {
    return this._timeoutSeconds;
  }

  // Override base query methods
  isPending() {
    return this._status === ApprovalRequest.STATUS_PENDING;
  }

  isApproved() {
    return this._status === ApprovalRequest.STATUS_APPROVED;
  }

  isRejected() {
    return this._status === ApprovalRequest.STATUS_REJECTED;
  }

  isTimeout() {
    return this._status === ApprovalRequest.STATUS_TIMEOUT;
  }

  isResolved() {
    return !this.isPending();
  }

  isExpired() {
    if (!this.isPending()) return false;
    
    const createdTime = new Date(this._createdAt).getTime();
    const timeoutTime = createdTime + (this._timeoutSeconds * 1000);
    return Date.now() > timeoutTime;
  }

  isStep() {
    return this._type === ApprovalRequest.TYPE_STEP;
  }

  isMilestone() {
    return this._type === ApprovalRequest.TYPE_MILESTONE;
  }

  getTimeoutAt() {
    const createdTime = new Date(this._createdAt).getTime();
    return new Date(createdTime + (this._timeoutSeconds * 1000));
  }

  getRemainingSeconds() {
    if (!this.isPending()) return 0;
    
    const timeoutTime = this.getTimeoutAt().getTime();
    const remaining = Math.max(0, Math.floor((timeoutTime - Date.now()) / 1000));
    return remaining;
  }

  // Transformation methods (return new instances - immutable)
  approve(resolvedBy) {
    if (!resolvedBy || typeof resolvedBy !== "string") {
      throw new TypeError("resolvedBy must be a non-empty string");
    }

    if (!this.isPending()) {
      throw new Error(`Cannot approve non-pending approval (current status: ${this._status})`);
    }

    return new ApprovalRequest({
      id: this._id,
      executionId: this._executionId,
      type: this._type,
      status: ApprovalRequest.STATUS_APPROVED,
      subjectId: this._subjectId,
      subjectTitle: this._subjectTitle,
      plannedActions: [...this._plannedActions],
      estimatedChanges: { ...this._estimatedChanges },
      createdAt: this._createdAt,
      resolvedAt: new Date().toISOString(),
      resolvedBy,
      timeoutSeconds: this._timeoutSeconds
    });
  }

  reject(resolvedBy) {
    if (!resolvedBy || typeof resolvedBy !== "string") {
      throw new TypeError("resolvedBy must be a non-empty string");
    }

    if (!this.isPending()) {
      throw new Error(`Cannot reject non-pending approval (current status: ${this._status})`);
    }

    return new ApprovalRequest({
      id: this._id,
      executionId: this._executionId,
      type: this._type,
      status: ApprovalRequest.STATUS_REJECTED,
      subjectId: this._subjectId,
      subjectTitle: this._subjectTitle,
      plannedActions: [...this._plannedActions],
      estimatedChanges: { ...this._estimatedChanges },
      createdAt: this._createdAt,
      resolvedAt: new Date().toISOString(),
      resolvedBy,
      timeoutSeconds: this._timeoutSeconds
    });
  }

  markTimeout() {
    if (!this.isPending()) {
      throw new Error(`Cannot timeout non-pending approval (current status: ${this._status})`);
    }

    return new ApprovalRequest({
      id: this._id,
      executionId: this._executionId,
      type: this._type,
      status: ApprovalRequest.STATUS_TIMEOUT,
      subjectId: this._subjectId,
      subjectTitle: this._subjectTitle,
      plannedActions: [...this._plannedActions],
      estimatedChanges: { ...this._estimatedChanges },
      createdAt: this._createdAt,
      resolvedAt: new Date().toISOString(),
      resolvedBy: "system_timeout",
      timeoutSeconds: this._timeoutSeconds
    });
  }

  // Serialization
  toJSON() {
    return {
      id: this._id,
      execution_id: this._executionId,
      type: this._type,
      status: this._status,
      subject_id: this._subjectId,
      subject_title: this._subjectTitle,
      planned_actions: this._plannedActions,
      estimated_changes: this._estimatedChanges,
      created_at: this._createdAt,
      resolved_at: this._resolvedAt,
      resolved_by: this._resolvedBy,
      timeout_seconds: this._timeoutSeconds
    };
  }

  // Deserialization - STRICT validation
  static fromJSON(json) {
    if (!json || typeof json !== "object") {
      throw new TypeError("ApprovalRequest.fromJSON: json must be a non-null object");
    }

    // NO optional fields - fail fast if data is missing
    const required = [
      "id", "execution_id", "type", "status", 
      "subject_id", "subject_title", "created_at"
    ];

    for (const field of required) {
      if (!(field in json)) {
        throw new Error(`ApprovalRequest.fromJSON: missing required field '${field}'`);
      }
    }

    return new ApprovalRequest({
      id: json.id,
      executionId: json.execution_id,
      type: json.type,
      status: json.status,
      subjectId: json.subject_id,
      subjectTitle: json.subject_title,
      plannedActions: json.planned_actions || [],
      estimatedChanges: json.estimated_changes || {},
      createdAt: json.created_at,
      resolvedAt: json.resolved_at,
      resolvedBy: json.resolved_by,
      timeoutSeconds: json.timeout_seconds || 300
    });
  }

  // Type guard
  static assertIsInstance(obj) {
    if (!(obj instanceof ApprovalRequest)) {
      throw new TypeError(`Expected ApprovalRequest instance, got: ${obj?.constructor?.name || typeof obj}`);
    }
  }
}
