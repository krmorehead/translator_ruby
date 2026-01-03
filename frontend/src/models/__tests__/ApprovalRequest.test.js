import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { ApprovalRequest } from '../ApprovalRequest.js';
import { BaseRequest } from '../BaseRequest.js';
import { speedProfile, resetProfile } from '../../utils/testProfile.js';

describe('ApprovalRequest', () => {
  beforeEach(() => {
    resetProfile();
  });

  afterEach(() => {
    resetProfile();
  });

  const validParams = () => ({
    id: 'approval-123',
    executionId: 'exec-456',
    type: 'step',
    status: 'pending',
    subjectId: 'step-1',
    subjectTitle: 'Test Step',
    plannedActions: ['action1', 'action2'],
    estimatedChanges: { files_to_create: 1 },
    createdAt: new Date().toISOString(),
    timeoutSeconds: 300
  });

  describe('inheritance', () => {
    speedProfile('fast'); // instanceof check

    it('extends BaseRequest', () => {
      const approval = new ApprovalRequest(validParams());
      expect(approval instanceof BaseRequest).toBe(true);
      expect(approval instanceof ApprovalRequest).toBe(true);
    });
  });

  describe('construction', () => {
    speedProfile('fast'); // Pure validation, no I/O

    it('creates valid approval with all params', () => {
      const params = validParams();
      const approval = new ApprovalRequest(params);

      expect(approval.id).toBe(params.id);
      expect(approval.executionId).toBe(params.executionId);
      expect(approval.type).toBe(params.type);
      expect(approval.status).toBe(params.status);
      expect(approval.subjectId).toBe(params.subjectId);
      expect(approval.subjectTitle).toBe(params.subjectTitle);
    });

    it('throws TypeError for missing executionId', () => {
      const params = validParams();
      delete params.executionId;

      expect(() => new ApprovalRequest(params))
        .toThrow(TypeError);
      expect(() => new ApprovalRequest(params))
        .toThrow('executionId must be a non-empty string');
    });

    it('throws TypeError for missing type', () => {
      const params = validParams();
      delete params.type;

      expect(() => new ApprovalRequest(params))
        .toThrow(TypeError);
      expect(() => new ApprovalRequest(params))
        .toThrow('type must be a non-empty string');
    });

    it('throws TypeError for invalid type', () => {
      const params = validParams();
      params.type = 'invalid';

      expect(() => new ApprovalRequest(params))
        .toThrow(TypeError);
      expect(() => new ApprovalRequest(params))
        .toThrow(/type must be 'step' or 'milestone'/);
    });

    it('throws TypeError for missing subjectId', () => {
      const params = validParams();
      delete params.subjectId;

      expect(() => new ApprovalRequest(params))
        .toThrow(TypeError);
      expect(() => new ApprovalRequest(params))
        .toThrow('subjectId must be a non-empty string');
    });

    it('throws TypeError for missing subjectTitle', () => {
      const params = validParams();
      delete params.subjectTitle;

      expect(() => new ApprovalRequest(params))
        .toThrow(TypeError);
      expect(() => new ApprovalRequest(params))
        .toThrow('subjectTitle must be a non-empty string');
    });

    it('throws TypeError for invalid timeoutSeconds', () => {
      const params = validParams();
      params.timeoutSeconds = -1;

      expect(() => new ApprovalRequest(params))
        .toThrow(TypeError);
      expect(() => new ApprovalRequest(params))
        .toThrow('timeoutSeconds must be a positive integer');
    });

    it('throws TypeError for non-integer timeoutSeconds', () => {
      const params = validParams();
      params.timeoutSeconds = 3.14;

      expect(() => new ApprovalRequest(params))
        .toThrow(TypeError);
    });
  });

  describe('immutability', () => {
    speedProfile('fast'); // Object.freeze checks

    it('freezes the object', () => {
      const approval = new ApprovalRequest(validParams());
      expect(Object.isFrozen(approval)).toBe(true);
    });

    it('freezes plannedActions array', () => {
      const approval = new ApprovalRequest(validParams());
      expect(Object.isFrozen(approval.plannedActions)).toBe(true);
      
      expect(() => {
        approval.plannedActions.push('new action');
      }).toThrow();
    });

    it('freezes estimatedChanges object', () => {
      const approval = new ApprovalRequest(validParams());
      expect(Object.isFrozen(approval.estimatedChanges)).toBe(true);
      
      expect(() => {
        approval.estimatedChanges.newField = 'value';
      }).toThrow();
    });

    it('prevents property modification', () => {
      const approval = new ApprovalRequest(validParams());
      
      expect(() => {
        approval._status = 'modified';
      }).toThrow();
    });
  });

  describe('query methods', () => {
    speedProfile('fast'); // Boolean checks, no I/O

    it('isPending returns true for pending status', () => {
      const approval = new ApprovalRequest(validParams());
      expect(approval.isPending()).toBe(true);
    });

    it('isApproved returns true for approved status', () => {
      const params = validParams();
      params.status = 'approved';
      const approval = new ApprovalRequest(params);
      expect(approval.isApproved()).toBe(true);
    });

    it('isRejected returns true for rejected status', () => {
      const params = validParams();
      params.status = 'rejected';
      const approval = new ApprovalRequest(params);
      expect(approval.isRejected()).toBe(true);
    });

    it('isTimeout returns true for timeout status', () => {
      const params = validParams();
      params.status = 'timeout';
      const approval = new ApprovalRequest(params);
      expect(approval.isTimeout()).toBe(true);
    });

    it('isResolved returns true for non-pending status', () => {
      const params = validParams();
      params.status = 'approved';
      const approval = new ApprovalRequest(params);
      expect(approval.isResolved()).toBe(true);
    });

    it('isStep returns true for step type', () => {
      const approval = new ApprovalRequest(validParams());
      expect(approval.isStep()).toBe(true);
    });

    it('isMilestone returns true for milestone type', () => {
      const params = validParams();
      params.type = 'milestone';
      const approval = new ApprovalRequest(params);
      expect(approval.isMilestone()).toBe(true);
    });

    it('isExpired returns true when past timeout', () => {
      const params = validParams();
      params.createdAt = new Date(Date.now() - 400000).toISOString(); // 400s ago
      params.timeoutSeconds = 300; // 5 min timeout
      
      const approval = new ApprovalRequest(params);
      expect(approval.isExpired()).toBe(true);
    });

    it('isExpired returns false when within timeout', () => {
      const approval = new ApprovalRequest(validParams());
      expect(approval.isExpired()).toBe(false);
    });
  });

  describe('transformation methods', () => {
    speedProfile('fast'); // Object creation, no I/O

    describe('approve()', () => {
      it('creates new approved instance', () => {
        const approval = new ApprovalRequest(validParams());
        const approved = approval.approve('test_user');

        expect(approved).not.toBe(approval); // Different instance
        expect(approved.isApproved()).toBe(true);
        expect(approved.resolvedBy).toBe('test_user');
        expect(approved.resolvedAt).toBeDefined();
      });

      it('throws TypeError for missing resolvedBy', () => {
        const approval = new ApprovalRequest(validParams());
        
        expect(() => approval.approve())
          .toThrow(TypeError);
        expect(() => approval.approve())
          .toThrow('resolvedBy must be a non-empty string');
      });

      it('throws Error for non-pending approval', () => {
        const params = validParams();
        params.status = 'approved';
        const approval = new ApprovalRequest(params);

        expect(() => approval.approve('user'))
          .toThrow(Error);
        expect(() => approval.approve('user'))
          .toThrow('Cannot approve non-pending approval');
      });

      it('preserves all other properties', () => {
        const approval = new ApprovalRequest(validParams());
        const approved = approval.approve('test_user');

        expect(approved.id).toBe(approval.id);
        expect(approved.executionId).toBe(approval.executionId);
        expect(approved.type).toBe(approval.type);
        expect(approved.subjectId).toBe(approval.subjectId);
        expect(approved.subjectTitle).toBe(approval.subjectTitle);
      });
    });

    describe('reject()', () => {
      it('creates new rejected instance', () => {
        const approval = new ApprovalRequest(validParams());
        const rejected = approval.reject('test_user');

        expect(rejected).not.toBe(approval);
        expect(rejected.isRejected()).toBe(true);
        expect(rejected.resolvedBy).toBe('test_user');
        expect(rejected.resolvedAt).toBeDefined();
      });

      it('throws TypeError for missing resolvedBy', () => {
        const approval = new ApprovalRequest(validParams());
        
        expect(() => approval.reject())
          .toThrow(TypeError);
      });

      it('throws Error for non-pending approval', () => {
        const params = validParams();
        params.status = 'rejected';
        const approval = new ApprovalRequest(params);

        expect(() => approval.reject('user'))
          .toThrow(Error);
        expect(() => approval.reject('user'))
          .toThrow('Cannot reject non-pending approval');
      });
    });

    describe('markTimeout()', () => {
      it('creates new timeout instance', () => {
        const approval = new ApprovalRequest(validParams());
        const timeout = approval.markTimeout();

        expect(timeout).not.toBe(approval);
        expect(timeout.isTimeout()).toBe(true);
        expect(timeout.resolvedBy).toBe('system_timeout');
        expect(timeout.resolvedAt).toBeDefined();
      });

      it('throws Error for non-pending approval', () => {
        const params = validParams();
        params.status = 'timeout';
        const approval = new ApprovalRequest(params);

        expect(() => approval.markTimeout())
          .toThrow(Error);
        expect(() => approval.markTimeout())
          .toThrow('Cannot timeout non-pending approval');
      });
    });
  });

  describe('serialization', () => {
    speedProfile('fast'); // JSON operations, no I/O

    it('toJSON converts to plain object with snake_case', () => {
      const params = validParams();
      const approval = new ApprovalRequest(params);
      const json = approval.toJSON();

      expect(json.id).toBe(params.id);
      expect(json.execution_id).toBe(params.executionId);
      expect(json.type).toBe(params.type);
      expect(json.status).toBe(params.status);
      expect(json.subject_id).toBe(params.subjectId);
      expect(json.subject_title).toBe(params.subjectTitle);
      expect(json.planned_actions).toEqual(params.plannedActions);
      expect(json.estimated_changes).toEqual(params.estimatedChanges);
      expect(json.created_at).toBe(params.createdAt);
      expect(json.timeout_seconds).toBe(params.timeoutSeconds);
    });

    describe('fromJSON', () => {
      it('creates instance from valid JSON', () => {
        const json = {
          id: 'approval-123',
          execution_id: 'exec-456',
          type: 'step',
          status: 'pending',
          subject_id: 'step-1',
          subject_title: 'Test Step',
          planned_actions: ['action1'],
          estimated_changes: { files_to_create: 1 },
          created_at: new Date().toISOString(),
          timeout_seconds: 300
        };

        const approval = ApprovalRequest.fromJSON(json);
        expect(approval).toBeInstanceOf(ApprovalRequest);
        expect(approval.id).toBe(json.id);
        expect(approval.executionId).toBe(json.execution_id);
      });

      it('throws TypeError for non-object input', () => {
        expect(() => ApprovalRequest.fromJSON(null))
          .toThrow(TypeError);
        expect(() => ApprovalRequest.fromJSON(null))
          .toThrow('json must be a non-null object');

        expect(() => ApprovalRequest.fromJSON('string'))
          .toThrow(TypeError);
      });

      it('throws Error for missing required fields', () => {
        const json = { id: 'test' }; // Missing required fields

        expect(() => ApprovalRequest.fromJSON(json))
          .toThrow(Error);
        expect(() => ApprovalRequest.fromJSON(json))
          .toThrow('missing required field');
      });

      it('round-trips through toJSON/fromJSON', () => {
        const original = new ApprovalRequest(validParams());
        const json = original.toJSON();
        const restored = ApprovalRequest.fromJSON(json);

        expect(restored.id).toBe(original.id);
        expect(restored.executionId).toBe(original.executionId);
        expect(restored.type).toBe(original.type);
        expect(restored.status).toBe(original.status);
        expect(restored.subjectId).toBe(original.subjectId);
        expect(restored.subjectTitle).toBe(original.subjectTitle);
      });
    });
  });

  describe('type assertions', () => {
    speedProfile('fast'); // Type checking, no I/O

    it('assertIsInstance passes for valid instance', () => {
      const approval = new ApprovalRequest(validParams());
      expect(() => ApprovalRequest.assertIsInstance(approval)).not.toThrow();
    });

    it('assertIsInstance throws for non-instance', () => {
      expect(() => ApprovalRequest.assertIsInstance({}))
        .toThrow(TypeError);
      expect(() => ApprovalRequest.assertIsInstance({}))
        .toThrow('Expected ApprovalRequest instance');
    });

    it('assertIsInstance throws for null', () => {
      expect(() => ApprovalRequest.assertIsInstance(null))
        .toThrow(TypeError);
    });
  });

  describe('timeout calculations', () => {
    speedProfile('fast'); // Date math, no I/O

    it('getTimeoutAt returns correct timeout date', () => {
      const now = Date.now();
      const params = validParams();
      params.createdAt = new Date(now).toISOString();
      params.timeoutSeconds = 300;

      const approval = new ApprovalRequest(params);
      const timeoutAt = approval.getTimeoutAt();

      expect(timeoutAt.getTime()).toBeGreaterThanOrEqual(now + 299000);
      expect(timeoutAt.getTime()).toBeLessThanOrEqual(now + 301000);
    });

    it('getRemainingSeconds returns correct value', () => {
      const params = validParams();
      params.timeoutSeconds = 300;
      params.createdAt = new Date(Date.now() - 100000).toISOString(); // 100s ago

      const approval = new ApprovalRequest(params);
      const remaining = approval.getRemainingSeconds();

      expect(remaining).toBeGreaterThan(195); // ~200s remaining
      expect(remaining).toBeLessThan(205);
    });

    it('getRemainingSeconds returns 0 for expired approval', () => {
      const params = validParams();
      params.createdAt = new Date(Date.now() - 400000).toISOString();
      params.timeoutSeconds = 300;

      const approval = new ApprovalRequest(params);
      expect(approval.getRemainingSeconds()).toBe(0);
    });

    it('getRemainingSeconds returns 0 for resolved approval', () => {
      const params = validParams();
      params.status = 'approved';

      const approval = new ApprovalRequest(params);
      expect(approval.getRemainingSeconds()).toBe(0);
    });
  });
});

