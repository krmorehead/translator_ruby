/**
 * Domain model representing a memory section.
 * Mirrors backend MemorySection model exactly.
 * 
 * Strict OOP principles:
 * - Immutable with Object.freeze()
 * - Deep frozen content
 * - Validation in constructor
 */
export class MemorySection {
  /**
   * Create a new MemorySection
   * @param {Object} params Section parameters
   * @param {string} params.sectionName Section name (e.g., 'findings', 'context_chain')
   * @param {*} params.content Section content (any serializable data)
   * @param {string|Date} params.timestamp Snapshot timestamp
   * @param {Object} params.metadata Additional metadata
   */
  constructor({ sectionName, content, timestamp, metadata = {} }) {
    // Validation
    if (!sectionName || typeof sectionName !== 'string') {
      throw new Error(`MemorySection: sectionName is required and must be a string, got ${typeof sectionName}`);
    }
    if (content === undefined || content === null) {
      throw new Error('MemorySection: content is required');
    }
    if (!timestamp) {
      throw new Error('MemorySection: timestamp is required');
    }
    if (metadata && typeof metadata !== 'object') {
      throw new Error(`MemorySection: metadata must be an object, got ${typeof metadata}`);
    }

    this._sectionName = sectionName;
    this._content = this._deepFreeze(content);
    this._timestamp = this._parseTimestamp(timestamp);
    this._metadata = Object.freeze({ ...metadata });

    Object.freeze(this);
  }

  // Getters
  get sectionName() { return this._sectionName; }
  get content() { return this._content; }
  get timestamp() { return this._timestamp; }
  get metadata() { return this._metadata; }

  /**
   * Check if section is empty
   * @returns {boolean}
   */
  isEmpty() {
    if (this._content === null || this._content === undefined) {
      return true;
    }
    if (Array.isArray(this._content)) {
      return this._content.length === 0;
    }
    if (typeof this._content === 'object') {
      return Object.keys(this._content).length === 0;
    }
    return false;
  }

  /**
   * Get content size
   * @returns {number|null}
   */
  getSize() {
    if (Array.isArray(this._content)) {
      return this._content.length;
    }
    if (typeof this._content === 'object' && this._content !== null) {
      return Object.keys(this._content).length;
    }
    return null;
  }

  /**
   * Get formatted timestamp
   * @returns {string}
   */
  getFormattedTimestamp() {
    return this._timestamp.toLocaleString();
  }

  /**
   * Serialize to JSON
   * @returns {Object}
   */
  toJSON() {
    return {
      section_name: this._sectionName,
      content: this._content,
      timestamp: this._timestamp.toISOString(),
      metadata: { ...this._metadata },
      size: this.getSize(),
      empty: this.isEmpty()
    };
  }

  /**
   * Create MemorySection from JSON
   * @param {Object} json JSON data
   * @returns {MemorySection}
   */
  static fromJSON(json) {
    if (!json || typeof json !== 'object') {
      throw new Error('MemorySection.fromJSON: json must be an object');
    }

    return new MemorySection({
      sectionName: json.section_name || json.sectionName,
      content: json.content,
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
        throw new Error(`MemorySection: Invalid timestamp '${value}'`);
      }
      return parsed;
    }
    throw new Error(`MemorySection: Invalid timestamp type ${typeof value}`);
  }

  /**
   * Deep freeze nested structures
   * @private
   */
  _deepFreeze(obj) {
    if (obj === null || obj === undefined) {
      return obj;
    }

    if (Array.isArray(obj)) {
      const frozen = obj.map(item => this._deepFreeze(item));
      return Object.freeze(frozen);
    }

    if (typeof obj === 'object') {
      const frozen = {};
      for (const key in obj) {
        if (obj.hasOwnProperty(key)) {
          frozen[key] = this._deepFreeze(obj[key]);
        }
      }
      return Object.freeze(frozen);
    }

    return obj;
  }
}








