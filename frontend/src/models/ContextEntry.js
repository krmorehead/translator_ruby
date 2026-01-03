/**
 * Domain model representing a single context entry.
 * 
 * Strict OOP principles:
 * - Immutable with Object.freeze()
 * - Validation in constructor
 */
export class ContextEntry {
  /**
   * Create a new ContextEntry
   * @param {Object} params Entry parameters
   * @param {string} params.id Unique identifier
   * @param {string} params.type Entry type (file, function, class, variable, etc.)
   * @param {string} params.name Entry name/identifier
   * @param {string} params.path File path (for file-based entries)
   * @param {number} params.lineStart Starting line number
   * @param {number} params.lineEnd Ending line number
   * @param {string} params.content Entry content/code
   * @param {string} params.relevance Relevance reason
   * @param {Date|string} params.addedAt When entry was added
   * @param {Object} params.metadata Additional metadata
   */
  constructor({ id, type, name, path, lineStart, lineEnd, content, relevance, addedAt, metadata = {} }) {
    // Validation
    if (!id || typeof id !== 'string') {
      throw new Error(`ContextEntry: id is required and must be a string, got ${typeof id}`);
    }
    if (!type || typeof type !== 'string') {
      throw new Error(`ContextEntry: type is required and must be a string, got ${typeof type}`);
    }
    if (!name || typeof name !== 'string') {
      throw new Error(`ContextEntry: name is required and must be a string, got ${typeof name}`);
    }
    if (path !== null && typeof path !== 'string') {
      throw new Error(`ContextEntry: path must be a string or null, got ${typeof path}`);
    }
    if (lineStart !== null && typeof lineStart !== 'number') {
      throw new Error(`ContextEntry: lineStart must be a number or null, got ${typeof lineStart}`);
    }
    if (lineEnd !== null && typeof lineEnd !== 'number') {
      throw new Error(`ContextEntry: lineEnd must be a number or null, got ${typeof lineEnd}`);
    }
    if (content !== null && typeof content !== 'string') {
      throw new Error(`ContextEntry: content must be a string or null, got ${typeof content}`);
    }
    if (relevance !== null && typeof relevance !== 'string') {
      throw new Error(`ContextEntry: relevance must be a string or null, got ${typeof relevance}`);
    }
    if (!addedAt) {
      throw new Error('ContextEntry: addedAt is required');
    }
    if (metadata && typeof metadata !== 'object') {
      throw new Error(`ContextEntry: metadata must be an object, got ${typeof metadata}`);
    }

    this._id = id;
    this._type = type;
    this._name = name;
    this._path = path;
    this._lineStart = lineStart;
    this._lineEnd = lineEnd;
    this._content = content;
    this._relevance = relevance;
    this._addedAt = this._parseTimestamp(addedAt);
    this._metadata = Object.freeze({ ...metadata });

    Object.freeze(this);
  }

  // Getters
  get id() { return this._id; }
  get type() { return this._type; }
  get name() { return this._name; }
  get path() { return this._path; }
  get lineStart() { return this._lineStart; }
  get lineEnd() { return this._lineEnd; }
  get content() { return this._content; }
  get relevance() { return this._relevance; }
  get addedAt() { return this._addedAt; }
  get metadata() { return this._metadata; }

  /**
   * Get location string (path:lineStart-lineEnd)
   * @returns {string}
   */
  getLocation() {
    if (!this._path) return this._name;
    
    let location = this._path;
    if (this._lineStart !== null) {
      location += `:${this._lineStart}`;
      if (this._lineEnd !== null && this._lineEnd !== this._lineStart) {
        location += `-${this._lineEnd}`;
      }
    }
    return location;
  }

  /**
   * Check if entry has content
   * @returns {boolean}
   */
  hasContent() {
    return this._content !== null && this._content.length > 0;
  }

  /**
   * Check if entry has line numbers
   * @returns {boolean}
   */
  hasLineNumbers() {
    return this._lineStart !== null && this._lineEnd !== null;
  }

  /**
   * Get content preview (first N characters)
   * @param {number} maxLength Maximum length
   * @returns {string}
   */
  getContentPreview(maxLength = 100) {
    if (!this.hasContent()) return '';
    
    if (this._content.length <= maxLength) {
      return this._content;
    }
    return this._content.substring(0, maxLength) + '...';
  }

  /**
   * Get line count
   * @returns {number|null}
   */
  getLineCount() {
    if (!this.hasLineNumbers()) return null;
    return this._lineEnd - this._lineStart + 1;
  }

  /**
   * Parse timestamp string or Date to Date object
   * @private
   */
  _parseTimestamp(timestamp) {
    if (timestamp instanceof Date) return timestamp;
    if (typeof timestamp === 'string') return new Date(timestamp);
    throw new Error(`ContextEntry: Invalid timestamp type: ${typeof timestamp}`);
  }

  /**
   * Serialize to JSON
   * @returns {Object}
   */
  toJSON() {
    return {
      id: this._id,
      type: this._type,
      name: this._name,
      path: this._path,
      line_start: this._lineStart,
      line_end: this._lineEnd,
      content: this._content,
      relevance: this._relevance,
      added_at: this._addedAt.toISOString(),
      metadata: this._metadata,
      location: this.getLocation(),
      has_content: this.hasContent(),
      line_count: this.getLineCount()
    };
  }

  /**
   * Create ContextEntry from JSON
   * @param {Object} json JSON data
   * @returns {ContextEntry}
   */
  static fromJSON(json) {
    return new ContextEntry({
      id: json.id,
      type: json.type,
      name: json.name,
      path: json.path || null,
      lineStart: json.line_start !== undefined ? json.line_start : (json.lineStart !== undefined ? json.lineStart : null),
      lineEnd: json.line_end !== undefined ? json.line_end : (json.lineEnd !== undefined ? json.lineEnd : null),
      content: json.content || null,
      relevance: json.relevance || null,
      addedAt: json.added_at || json.addedAt,
      metadata: json.metadata || {}
    });
  }
}








