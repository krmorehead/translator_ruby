/**
 * Domain model representing agent context (relevant code/files).
 * 
 * Strict OOP principles:
 * - Immutable with Object.freeze()
 * - Validation in constructor
 * - Transformation methods return NEW instances
 */
import { ContextEntry } from './ContextEntry';

export class Context {
  /**
   * Create a new Context
   * @param {Object} params Context parameters
   * @param {string} params.sessionId Session identifier
   * @param {Array<ContextEntry>} params.entries Array of ContextEntry instances
   * @param {number} params.maxSize Maximum number of entries
   */
  constructor({ sessionId, entries = [], maxSize = 100 }) {
    // Validation
    if (!sessionId || typeof sessionId !== 'string') {
      throw new Error(`Context: sessionId is required and must be a string, got ${typeof sessionId}`);
    }
    if (!Array.isArray(entries)) {
      throw new Error(`Context: entries must be an array, got ${typeof entries}`);
    }
    if (typeof maxSize !== 'number' || maxSize < 1) {
      throw new Error(`Context: maxSize must be a positive number, got ${maxSize}`);
    }

    // Validate all entries are ContextEntry instances
    entries.forEach((entry, index) => {
      if (!(entry instanceof ContextEntry)) {
        throw new Error(`Context: entries[${index}] must be a ContextEntry instance, got ${entry?.constructor?.name}`);
      }
    });

    this._sessionId = sessionId;
    this._entries = Object.freeze([...entries]);
    this._maxSize = maxSize;

    Object.freeze(this);
  }

  // Getters
  get sessionId() { return this._sessionId; }
  get entries() { return this._entries; }
  get maxSize() { return this._maxSize; }

  /**
   * Get number of entries
   * @returns {number}
   */
  get length() {
    return this._entries.length;
  }

  /**
   * Check if context is empty
   * @returns {boolean}
   */
  isEmpty() {
    return this._entries.length === 0;
  }

  /**
   * Check if context is full
   * @returns {boolean}
   */
  isFull() {
    return this._entries.length >= this._maxSize;
  }

  /**
   * Get entry by ID
   * @param {string} entryId Entry ID
   * @returns {ContextEntry|null}
   */
  getEntryById(entryId) {
    return this._entries.find(e => e.id === entryId) || null;
  }

  /**
   * Get entries by type
   * @param {string} type Entry type
   * @returns {Array<ContextEntry>}
   */
  getEntriesByType(type) {
    return this._entries.filter(e => e.type === type);
  }

  /**
   * Get entries by path
   * @param {string} path File path
   * @returns {Array<ContextEntry>}
   */
  getEntriesByPath(path) {
    return this._entries.filter(e => e.path === path);
  }

  /**
   * Get unique paths
   * @returns {Array<string>}
   */
  getUniquePaths() {
    const paths = this._entries
      .map(e => e.path)
      .filter(p => p !== null);
    return [...new Set(paths)];
  }

  /**
   * Get unique types
   * @returns {Array<string>}
   */
  getUniqueTypes() {
    const types = this._entries.map(e => e.type);
    return [...new Set(types)];
  }

  /**
   * Get entries with content
   * @returns {Array<ContextEntry>}
   */
  getEntriesWithContent() {
    return this._entries.filter(e => e.hasContent());
  }

  /**
   * Get total content size (characters)
   * @returns {number}
   */
  getTotalContentSize() {
    return this._entries.reduce((sum, entry) => {
      return sum + (entry.content ? entry.content.length : 0);
    }, 0);
  }

  /**
   * Add entry to context
   * Returns NEW instance
   * @param {ContextEntry} entry Entry to add
   * @returns {Context}
   */
  addEntry(entry) {
    if (!(entry instanceof ContextEntry)) {
      throw new Error(`Context.addEntry: entry must be a ContextEntry instance, got ${entry?.constructor?.name}`);
    }

    // If already exists, update it instead
    const existingIndex = this._entries.findIndex(e => e.id === entry.id);
    if (existingIndex >= 0) {
      return this.updateEntry(entry);
    }

    let newEntries = [...this._entries, entry];
    
    // Enforce max size (remove oldest if needed)
    if (newEntries.length > this._maxSize) {
      newEntries = newEntries.slice(-this._maxSize);
    }

    return new Context({
      sessionId: this._sessionId,
      entries: newEntries,
      maxSize: this._maxSize
    });
  }

  /**
   * Add multiple entries
   * Returns NEW instance
   * @param {Array<ContextEntry>} entries Entries to add
   * @returns {Context}
   */
  addEntries(entries) {
    if (!Array.isArray(entries)) {
      throw new Error(`Context.addEntries: entries must be an array, got ${typeof entries}`);
    }

    let newContext = this;
    for (const entry of entries) {
      newContext = newContext.addEntry(entry);
    }
    return newContext;
  }

  /**
   * Update entry
   * Returns NEW instance
   * @param {ContextEntry} entry Entry to update
   * @returns {Context}
   */
  updateEntry(entry) {
    if (!(entry instanceof ContextEntry)) {
      throw new Error(`Context.updateEntry: entry must be a ContextEntry instance, got ${entry?.constructor?.name}`);
    }

    const existingIndex = this._entries.findIndex(e => e.id === entry.id);
    if (existingIndex < 0) {
      // Entry doesn't exist, add it instead
      return this.addEntry(entry);
    }

    const newEntries = [...this._entries];
    newEntries[existingIndex] = entry;

    return new Context({
      sessionId: this._sessionId,
      entries: newEntries,
      maxSize: this._maxSize
    });
  }

  /**
   * Remove entry by ID
   * Returns NEW instance
   * @param {string} entryId Entry ID to remove
   * @returns {Context}
   */
  removeEntry(entryId) {
    const newEntries = this._entries.filter(e => e.id !== entryId);

    return new Context({
      sessionId: this._sessionId,
      entries: newEntries,
      maxSize: this._maxSize
    });
  }

  /**
   * Clear all entries
   * Returns NEW instance
   * @returns {Context}
   */
  clear() {
    return new Context({
      sessionId: this._sessionId,
      entries: [],
      maxSize: this._maxSize
    });
  }

  /**
   * Serialize to JSON
   * @returns {Object}
   */
  toJSON() {
    return {
      session_id: this._sessionId,
      entries: this._entries.map(e => e.toJSON()),
      max_size: this._maxSize,
      count: this._entries.length,
      total_content_size: this.getTotalContentSize(),
      unique_paths: this.getUniquePaths(),
      unique_types: this.getUniqueTypes()
    };
  }

  /**
   * Create Context from JSON
   * @param {Object} json JSON data
   * @returns {Context}
   */
  static fromJSON(json) {
    const entries = (json.entries || []).map(e => ContextEntry.fromJSON(e));

    return new Context({
      sessionId: json.session_id || json.sessionId,
      entries,
      maxSize: json.max_size || json.maxSize || 100
    });
  }

  /**
   * Create empty context
   * @param {string} sessionId Session ID
   * @param {number} maxSize Maximum size
   * @returns {Context}
   */
  static empty(sessionId, maxSize = 100) {
    return new Context({
      sessionId,
      entries: [],
      maxSize
    });
  }
}








