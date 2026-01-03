import { ApprovalRequest } from "../models/ApprovalRequest";

/**
 * ApprovalRequestFactory - Factory for creating ApprovalRequest instances
 * 
 * Follows the FactoryBot pattern from the backend.
 * Provides convenient methods for creating test instances with sensible defaults.
 */
export class ApprovalRequestFactory {
  static defaultAttributes() {
    return {
      id: `approval-${this.generateId()}`,
      executionId: `exec-${this.generateId()}`,
      type: ApprovalRequest.TYPE_STEP,
      status: ApprovalRequest.STATUS_PENDING,
      subjectId: `step-${this.generateId()}`,
      subjectTitle: "Test Step",
      plannedActions: [],
      estimatedChanges: {},
      createdAt: new Date().toISOString(),
      resolvedAt: null,
      resolvedBy: null,
      timeoutSeconds: 300
    };
  }

  static generateId() {
    return Math.random().toString(36).substring(2, 10);
  }

  /**
   * Build a new ApprovalRequest with custom attributes
   * @param {Object} attributes - Attributes to override defaults
   * @returns {ApprovalRequest}
   */
  static build(attributes = {}) {
    const attrs = { ...this.defaultAttributes(), ...attributes };
    return new ApprovalRequest(attrs);
  }

  /**
   * Build a step approval request
   * @param {Object} attributes - Additional attributes
   * @returns {ApprovalRequest}
   */
  static buildStep(attributes = {}) {
    return this.build({
      type: ApprovalRequest.TYPE_STEP,
      subjectTitle: "Execute Test Step",
      ...attributes
    });
  }

  /**
   * Build a milestone approval request
   * @param {Object} attributes - Additional attributes
   * @returns {ApprovalRequest}
   */
  static buildMilestone(attributes = {}) {
    return this.build({
      type: ApprovalRequest.TYPE_MILESTONE,
      subjectId: `milestone-${this.generateId()}`,
      subjectTitle: "Complete Test Milestone",
      ...attributes
    });
  }

  /**
   * Build an approval with planned actions
   * @param {Object} attributes - Additional attributes
   * @returns {ApprovalRequest}
   */
  static buildWithActions(attributes = {}) {
    return this.build({
      plannedActions: [
        "Create new file: hello.rb",
        "Write Hello World code",
        "Make file executable"
      ],
      ...attributes
    });
  }

  /**
   * Build an approval with estimated changes
   * @param {Object} attributes - Additional attributes
   * @returns {ApprovalRequest}
   */
  static buildWithChanges(attributes = {}) {
    return this.build({
      estimatedChanges: {
        files_to_create: 2,
        files_to_modify: 1,
        files_to_delete: 0,
        commands_to_run: 1
      },
      ...attributes
    });
  }

  /**
   * Build an approval with full details (actions + changes)
   * @param {Object} attributes - Additional attributes
   * @returns {ApprovalRequest}
   */
  static buildWithFullDetails(attributes = {}) {
    return this.build({
      plannedActions: [
        "Create new file: hello.rb",
        "Write Hello World code",
        "Make file executable"
      ],
      estimatedChanges: {
        files_to_create: 2,
        files_to_modify: 1,
        files_to_delete: 0,
        commands_to_run: 1
      },
      ...attributes
    });
  }

  /**
   * Build an expired approval request
   * @param {Object} attributes - Additional attributes
   * @returns {ApprovalRequest}
   */
  static buildExpired(attributes = {}) {
    const expiredTime = new Date(Date.now() - 400000).toISOString(); // 400s ago
    return this.build({
      createdAt: expiredTime,
      timeoutSeconds: 300, // 5 minutes, so it's expired
      ...attributes
    });
  }

  /**
   * Build an approval about to expire
   * @param {Object} attributes - Additional attributes
   * @returns {ApprovalRequest}
   */
  static buildAboutToExpire(attributes = {}) {
    const recentTime = new Date(Date.now() - 280000).toISOString(); // 280s ago (20s remaining)
    return this.build({
      createdAt: recentTime,
      timeoutSeconds: 300,
      ...attributes
    });
  }

  /**
   * Build an approved request
   * @param {Object} attributes - Additional attributes
   * @returns {ApprovalRequest}
   */
  static buildApproved(attributes = {}) {
    const approval = this.build(attributes);
    return approval.approve("test_user");
  }

  /**
   * Build a rejected request
   * @param {Object} attributes - Additional attributes
   * @returns {ApprovalRequest}
   */
  static buildRejected(attributes = {}) {
    const approval = this.build(attributes);
    return approval.reject("test_user");
  }

  /**
   * Build a timed out request
   * @param {Object} attributes - Additional attributes
   * @returns {ApprovalRequest}
   */
  static buildTimeout(attributes = {}) {
    const approval = this.build(attributes);
    return approval.markTimeout();
  }
}

