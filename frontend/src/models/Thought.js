/**
 * Domain model representing a single thought entry (extracted reasoning).
 * 
 * Strict OOP principles:
 * - Immutable with Object.freeze()
 * - Validation in constructor
 */
export class Thought {
  /**
   * Create a new Thought
   * @param {Object} params Thought parameters
   * @param {string} params.id Unique identifier
   * @param {string} params.messageId Associated message ID
   * @param {string} params.content Thought content
   * @param {string|Date} params.timestamp When thought was created
   * @param {Object} params.metadata Additional metadata
   */
  constructor({ id, messageId, content, timestamp, metadata = {} }) {
    // Validation
    if (!id || typeof id !== 'string') {
      throw new Error(`Thought: id is required and must be a string, got ${typeof id}`);
    }
    if (!messageId || typeof messageId !== 'string') {
      throw new Error(`Thought: messageId is required and must be a string, got ${typeof messageId}`);
    }
    if (!content || typeof content !== 'string') {
      throw new Error(`Thought: content is required and must be a string, got ${typeof content}`);
    }
    if (!timestamp) {
      throw new Error('Thought: timestamp is required');
    }
    if (metadata && typeof metadata !== 'object') {
      throw new Error(`Thought: metadata must be an object, got ${typeof metadata}`);
    }

    this._id = id;
    this._messageId = messageId;
    this._content = content;
    this._timestamp = this._parseTimestamp(timestamp);
    this._metadata = Object.freeze({ ...metadata });

    Object.freeze(this);
  }

  // Getters
  get id() { return this._id; }
  get messageId() { return this._messageId; }
  get content() { return this._content; }
  get timestamp() { return this._timestamp; }
  get metadata() { return this._metadata; }

  /**
   * Get formatted timestamp
   * @returns {string}
   */
  getFormattedTimestamp() {
    return this._timestamp.toLocaleTimeString();
  }

  /**
   * Get content preview (first N characters)
   * @param {number} length Preview length
   * @returns {string}
   */
  getPreview(length = 100) {
    if (this._content.length <= length) {
      return this._content;
    }
    return this._content.substring(0, length) + '...';
  }

  /**
   * Serialize to JSON
   * @returns {Object}
   */
  toJSON() {
    return {
      id: this._id,
      message_id: this._messageId,
      content: this._content,
      timestamp: this._timestamp.toISOString(),
      metadata: { ...this._metadata }
    };
  }

  /**
   * Create Thought from JSON
   * @param {Object} json JSON data
   * @returns {Thought}
   */
  static fromJSON(json) {
    if (!json || typeof json !== 'object') {
      throw new Error('Thought.fromJSON: json must be an object');
    }

    return new Thought({
      id: json.id,
      messageId: json.message_id || json.messageId,
      content: json.content || json.thoughts,
      timestamp: json.timestamp,
      metadata: json.metadata || {}
    });
  }

  /**
   * Parse timestamp from various formats
   * @private
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
        throw new Error(`Thought: Invalid timestamp '${value}'`);
      }
      return parsed;
    }
    throw new Error(`Thought: Invalid timestamp type ${typeof value}`);
  }
}








