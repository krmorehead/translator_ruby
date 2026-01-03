/**
 * Domain model representing a chat message in an agent conversation.
 * Mirrors backend ChatMessage model exactly.
 * 
 * Strict OOP principles:
 * - Immutable with Object.freeze()
 * - Validation in constructor (fail fast)
 * - No hash/object literal support
 * - Transformation methods return NEW instances
 */
export class Message {
  static ROLE_USER = "user";
  static ROLE_AGENT = "agent";
  static ROLE_SYSTEM = "system";

  static VALID_ROLES = [Message.ROLE_USER, Message.ROLE_AGENT, Message.ROLE_SYSTEM];

  /**
   * Create a new Message
   * @param {Object} params Message parameters
   * @param {string} params.id Unique message identifier
   * @param {string} params.sessionId Session this message belongs to
   * @param {string} params.role Message role (user, agent, system)
   * @param {string} params.content Message content
   * @param {string|null} params.thoughts Agent's reasoning (optional)
   * @param {string|Date} params.timestamp Message timestamp
   * @param {Object} params.metadata Additional metadata (optional)
   */
  constructor({ id, sessionId, role, content, thoughts = null, timestamp, metadata = {} }) {
    // Validation - fail fast
    if (!id || typeof id !== 'string') {
      throw new Error(`Message: id is required and must be a string, got ${typeof id}`);
    }
    if (!sessionId || typeof sessionId !== 'string') {
      throw new Error(`Message: sessionId is required and must be a string, got ${typeof sessionId}`);
    }
    if (!role || typeof role !== 'string') {
      throw new Error(`Message: role is required and must be a string, got ${typeof role}`);
    }
    if (!Message.VALID_ROLES.includes(role)) {
      throw new Error(`Message: Invalid role '${role}'. Must be one of: ${Message.VALID_ROLES.join(', ')}`);
    }
    if (content === null || content === undefined) {
      throw new Error('Message: content is required');
    }
    if (!timestamp) {
      throw new Error('Message: timestamp is required');
    }
    if (metadata && typeof metadata !== 'object') {
      throw new Error(`Message: metadata must be an object, got ${typeof metadata}`);
    }

    // Assign immutable properties
    this._id = id;
    this._sessionId = sessionId;
    this._role = role;
    this._content = String(content);
    this._thoughts = thoughts ? String(thoughts) : null;
    this._timestamp = this._parseTimestamp(timestamp);
    this._metadata = Object.freeze({ ...metadata });

    // Freeze instance
    Object.freeze(this);
  }

  // Getters
  get id() { return this._id; }
  get sessionId() { return this._sessionId; }
  get role() { return this._role; }
  get content() { return this._content; }
  get thoughts() { return this._thoughts; }
  get timestamp() { return this._timestamp; }
  get metadata() { return this._metadata; }

  /**
   * Check if message is from user
   * @returns {boolean}
   */
  isUser() {
    return this._role === Message.ROLE_USER;
  }

  /**
   * Check if message is from agent
   * @returns {boolean}
   */
  isAgent() {
    return this._role === Message.ROLE_AGENT;
  }

  /**
   * Check if message is system message
   * @returns {boolean}
   */
  isSystem() {
    return this._role === Message.ROLE_SYSTEM;
  }

  /**
   * Check if message has thoughts
   * @returns {boolean}
   */
  hasThoughts() {
    return this._thoughts !== null && this._thoughts.length > 0;
  }

  /**
   * Get formatted timestamp
   * @returns {string}
   */
  getFormattedTimestamp() {
    return this._timestamp.toLocaleTimeString();
  }

  /**
   * Serialize to JSON for API calls
   * @returns {Object}
   */
  toJSON() {
    return {
      id: this._id,
      session_id: this._sessionId,
      role: this._role,
      content: this._content,
      thoughts: this._thoughts,
      timestamp: this._timestamp.toISOString(),
      metadata: { ...this._metadata }
    };
  }

  /**
   * Create Message from JSON response
   * @param {Object} json JSON data
   * @returns {Message}
   */
  static fromJSON(json) {
    if (!json || typeof json !== 'object') {
      throw new Error('Message.fromJSON: json must be an object');
    }

    return new Message({
      id: json.id,
      sessionId: json.session_id || json.sessionId,
      role: json.role,
      content: json.content,
      thoughts: json.thoughts || null,
      timestamp: json.timestamp,
      metadata: json.metadata || {}
    });
  }

  /**
   * Parse timestamp from various formats
   * @private
   * @param {string|Date|number} value Timestamp value
   * @returns {Date}
   */
  _parseTimestamp(value) {
    if (value instanceof Date) {
      return value;
    }
    if (typeof value === 'number') {
      return new Date(value);
    }
    if (typeof value === 'string') {
      const parsed = new Date(value);
      if (isNaN(parsed.getTime())) {
        throw new Error(`Message: Invalid timestamp '${value}'`);
      }
      return parsed;
    }
    throw new Error(`Message: Invalid timestamp type ${typeof value}`);
  }
}


