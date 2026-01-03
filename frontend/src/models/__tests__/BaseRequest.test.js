import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { BaseRequest } from '../BaseRequest.js';
import { speedProfile, resetProfile } from '../../utils/testProfile.js';

describe('BaseRequest', () => {
  beforeEach(() => {
    resetProfile();
  });

  afterEach(() => {
    resetProfile();
  });

  describe('construction', () => {
    speedProfile('fast'); // Pure validation, no I/O

    it('throws error when instantiated directly', () => {
      expect(() => {
        new BaseRequest({
          id: 'test-123',
          status: 'pending',
          createdAt: new Date().toISOString()
        });
      }).toThrow('BaseRequest is abstract and cannot be instantiated directly');
    });

    it('requires id parameter', () => {
      class TestRequest extends BaseRequest {
        isPending() { return true; }
        isResolved() { return false; }
        toJSON() { return {}; }
      }

      expect(() => {
        new TestRequest({
          status: 'pending',
          createdAt: new Date().toISOString()
        });
      }).toThrow('id must be a non-empty string');
    });

    it('requires status parameter', () => {
      class TestRequest extends BaseRequest {
        isPending() { return true; }
        isResolved() { return false; }
        toJSON() { return {}; }
      }

      expect(() => {
        new TestRequest({
          id: 'test-123',
          createdAt: new Date().toISOString()
        });
      }).toThrow('status must be a non-empty string');
    });

    it('requires createdAt parameter', () => {
      class TestRequest extends BaseRequest {
        isPending() { return true; }
        isResolved() { return false; }
        toJSON() { return {}; }
      }

      expect(() => {
        new TestRequest({
          id: 'test-123',
          status: 'pending'
        });
      }).toThrow('createdAt must be a non-empty string');
    });

    it('validates createdAt is ISO8601 format', () => {
      class TestRequest extends BaseRequest {
        isPending() { return true; }
        isResolved() { return false; }
        toJSON() { return {}; }
      }

      expect(() => {
        new TestRequest({
          id: 'test-123',
          status: 'pending',
          createdAt: 'invalid-date'
        });
      }).toThrow('must be a valid ISO8601 timestamp');
    });
  });

  describe('getters', () => {
    speedProfile('fast'); // Property access, no computation

    class TestRequest extends BaseRequest {
      constructor(params) {
        super(params);
        this.freeze();
      }
      isPending() { return this.status === 'pending'; }
      isResolved() { return !this.isPending(); }
      toJSON() { return { id: this.id, status: this.status }; }
    }

    it('provides read-only access to id', () => {
      const request = new TestRequest({
        id: 'test-123',
        status: 'pending',
        createdAt: new Date().toISOString()
      });

      expect(request.id).toBe('test-123');
      
      // Should throw when trying to modify (frozen object)
      expect(() => {
        request._id = 'modified';
      }).toThrow();
    });

    it('provides read-only access to status', () => {
      const request = new TestRequest({
        id: 'test-123',
        status: 'pending',
        createdAt: new Date().toISOString()
      });

      expect(request.status).toBe('pending');
    });

    it('provides read-only access to timestamps', () => {
      const now = new Date().toISOString();
      const request = new TestRequest({
        id: 'test-123',
        status: 'pending',
        createdAt: now,
        resolvedAt: now,
        resolvedBy: 'user'
      });

      expect(request.createdAt).toBe(now);
      expect(request.resolvedAt).toBe(now);
      expect(request.resolvedBy).toBe('user');
    });
  });

  describe('age calculations', () => {
    speedProfile('fast'); // Simple math operations

    class TestRequest extends BaseRequest {
      constructor(params) {
        super(params);
        this.freeze();
      }
      isPending() { return true; }
      isResolved() { return false; }
      toJSON() { return {}; }
    }

    it('calculates age in milliseconds', () => {
      const oneSecondAgo = new Date(Date.now() - 1000).toISOString();
      const request = new TestRequest({
        id: 'test-123',
        status: 'pending',
        createdAt: oneSecondAgo
      });

      const age = request.getAge();
      expect(age).toBeGreaterThanOrEqual(1000);
      expect(age).toBeLessThan(2000);
    });

    it('calculates age in seconds', () => {
      const twoSecondsAgo = new Date(Date.now() - 2000).toISOString();
      const request = new TestRequest({
        id: 'test-123',
        status: 'pending',
        createdAt: twoSecondsAgo
      });

      const ageSeconds = request.getAgeInSeconds();
      expect(ageSeconds).toBeGreaterThanOrEqual(2);
      expect(ageSeconds).toBeLessThan(3);
    });
  });

  describe('abstract methods', () => {
    speedProfile('fast'); // Error throwing, no I/O

    class IncompleteRequest extends BaseRequest {
      constructor(params) {
        super(params);
        this.freeze();
      }
    }

    it('throws error if isPending not implemented', () => {
      const request = new IncompleteRequest({
        id: 'test-123',
        status: 'pending',
        createdAt: new Date().toISOString()
      });

      expect(() => request.isPending()).toThrow('must implement isPending()');
    });

    it('throws error if isResolved not implemented', () => {
      const request = new IncompleteRequest({
        id: 'test-123',
        status: 'pending',
        createdAt: new Date().toISOString()
      });

      expect(() => request.isResolved()).toThrow('must implement isResolved()');
    });

    it('throws error if toJSON not implemented', () => {
      const request = new IncompleteRequest({
        id: 'test-123',
        status: 'pending',
        createdAt: new Date().toISOString()
      });

      expect(() => request.toJSON()).toThrow('must implement toJSON()');
    });

    it('throws error if fromJSON not implemented', () => {
      expect(() => {
        IncompleteRequest.fromJSON({});
      }).toThrow('must implement static fromJSON()');
    });
  });

  describe('immutability', () => {
    speedProfile('fast'); // Object.freeze checks

    class TestRequest extends BaseRequest {
      constructor(params) {
        super(params);
        this.freeze();
      }
      isPending() { return true; }
      isResolved() { return false; }
      toJSON() { return {}; }
    }

    it('freezes object after construction', () => {
      const request = new TestRequest({
        id: 'test-123',
        status: 'pending',
        createdAt: new Date().toISOString()
      });

      expect(Object.isFrozen(request)).toBe(true);
    });

    it('prevents modification of properties', () => {
      const request = new TestRequest({
        id: 'test-123',
        status: 'pending',
        createdAt: new Date().toISOString()
      });

      expect(() => {
        request._status = 'modified';
      }).toThrow();
    });

    it('prevents addition of new properties', () => {
      const request = new TestRequest({
        id: 'test-123',
        status: 'pending',
        createdAt: new Date().toISOString()
      });

      expect(() => {
        request.newProperty = 'value';
      }).toThrow();
    });
  });

  describe('type checking', () => {
    speedProfile('fast'); // instanceof checks

    class TestRequest extends BaseRequest {
      constructor(params) {
        super(params);
        this.freeze();
      }
      isPending() { return true; }
      isResolved() { return false; }
      toJSON() { return {}; }
    }

    it('identifies instances correctly', () => {
      const request = new TestRequest({
        id: 'test-123',
        status: 'pending',
        createdAt: new Date().toISOString()
      });

      expect(BaseRequest.isInstance(request)).toBe(true);
      expect(TestRequest.isInstance(request)).toBe(true);
    });

    it('rejects non-instances', () => {
      expect(BaseRequest.isInstance({})).toBe(false);
      expect(BaseRequest.isInstance(null)).toBe(false);
      expect(BaseRequest.isInstance('string')).toBe(false);
    });
  });

  describe('string representation', () => {
    speedProfile('fast'); // String formatting

    class TestRequest extends BaseRequest {
      constructor(params) {
        super(params);
        this.freeze();
      }
      isPending() { return true; }
      isResolved() { return false; }
      toJSON() { return {}; }
    }

    it('provides meaningful toString', () => {
      const request = new TestRequest({
        id: 'test-123',
        status: 'pending',
        createdAt: new Date().toISOString()
      });

      const str = request.toString();
      expect(str).toContain('TestRequest');
      expect(str).toContain('test-123');
      expect(str).toContain('pending');
    });
  });
});

