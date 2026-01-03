/**
 * BaseRequest - Abstract base class for all request domain models
 * 
 * Provides common functionality for request objects including:
 * - ID management and validation
 * - Status tracking
 * - Timestamps
 * - Immutability
 * - Serialization
 * 
 * All request subclasses MUST inherit from this class.
 * NO raw JSON objects allowed - everything must be a proper class instance.
 */
export class BaseRequest {
  // Common request statuses - subclasses can extend
  static STATUS_PENDING = "pending";
  static STATUS_COMPLETE = "complete";
  static STATUS_FAILED = "failed";

  constructor({ id, status, createdAt, resolvedAt = null, resolvedBy = null }) {
    // Prevent direct instantiation of abstract base class
    if (new.target === BaseRequest) {
      throw new Error("BaseRequest is abstract and cannot be instantiated directly");
    }

    this.validateBaseParams(id, status, createdAt);

    this._id = id;
    this._status = status;
    this._createdAt = createdAt;
    this._resolvedAt = resolvedAt;
    this._resolvedBy = resolvedBy;

    // Make immutable - subclasses must call this after setting their properties
    // Subclasses should call freeze() at the end of their constructor
  }

  validateBaseParams(id, status, createdAt) {
    if (!id || typeof id !== "string") {
      throw new TypeError(`${this.constructor.name}: id must be a non-empty string, got: ${typeof id}`);
    }
    if (!status || typeof status !== "string") {
      throw new TypeError(`${this.constructor.name}: status must be a non-empty string, got: ${typeof status}`);
    }
    if (!createdAt || typeof createdAt !== "string") {
      throw new TypeError(`${this.constructor.name}: createdAt must be a non-empty string, got: ${typeof createdAt}`);
    }

    // Validate ISO8601 format
    if (isNaN(Date.parse(createdAt))) {
      throw new TypeError(`${this.constructor.name}: createdAt must be a valid ISO8601 timestamp: ${createdAt}`);
    }
  }

  // Getters - read-only access
  get id() {
    return this._id;
  }

  get status() {
    return this._status;
  }

  get createdAt() {
    return this._createdAt;
  }

  get resolvedAt() {
    return this._resolvedAt;
  }

  get resolvedBy() {
    return this._resolvedBy;
  }

  // Query methods
  isPending() {
    throw new Error(`${this.constructor.name} must implement isPending()`);
  }

  isResolved() {
    throw new Error(`${this.constructor.name} must implement isResolved()`);
  }

  getAge() {
    const created = new Date(this._createdAt).getTime();
    return Date.now() - created;
  }

  getAgeInSeconds() {
    return Math.floor(this.getAge() / 1000);
  }

  // Serialization - must be implemented by subclasses
  toJSON() {
    throw new Error(`${this.constructor.name} must implement toJSON()`);
  }

  static fromJSON(json) {
    throw new Error(`${this.name} must implement static fromJSON()`);
  }

  // Type checking
  static isInstance(obj) {
    return obj instanceof this;
  }

  assertIsInstance() {
    if (!(this instanceof BaseRequest)) {
      throw new TypeError(`Object must be an instance of BaseRequest, got: ${this.constructor.name}`);
    }
  }

  // String representation
  toString() {
    return `${this.constructor.name}(id=${this._id}, status=${this._status})`;
  }

  // Freeze helper for subclasses
  freeze() {
    Object.freeze(this);
    return this;
  }
}

