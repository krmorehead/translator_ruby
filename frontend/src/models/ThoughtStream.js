/**
 * Domain model representing a collection of thoughts (thought stream).
 * 
 * Strict OOP principles:
 * - Immutable with Object.freeze()
 * - Validation in constructor
 * - Transformation methods return NEW instances
 */
import { Thought } from './Thought';

export class ThoughtStream {
  /**
   * Create a new ThoughtStream
   * @param {Object} params Stream parameters
   * @param {string} params.sessionId Session identifier
   * @param {Array<Thought>} params.thoughts Array of Thought instances
   */
  constructor({ sessionId, thoughts = [] }) {
    // Validation
    if (!sessionId || typeof sessionId !== 'string') {
      throw new Error(`ThoughtStream: sessionId is required and must be a string, got ${typeof sessionId}`);
    }
    if (!Array.isArray(thoughts)) {
      throw new Error(`ThoughtStream: thoughts must be an array, got ${typeof thoughts}`);
    }

    // Validate all thoughts are Thought instances
    thoughts.forEach((thought, index) => {
      if (!(thought instanceof Thought)) {
        throw new Error(`ThoughtStream: thoughts[${index}] must be a Thought instance, got ${thought?.constructor?.name}`);
      }
    });

    this._sessionId = sessionId;
    this._thoughts = Object.freeze([...thoughts]);

    Object.freeze(this);
  }

  // Getters
  get sessionId() { return this._sessionId; }
  get thoughts() { return this._thoughts; }

  /**
   * Get number of thoughts
   * @returns {number}
   */
  get length() {
    return this._thoughts.length;
  }

  /**
   * Check if stream is empty
   * @returns {boolean}
   */
  isEmpty() {
    return this._thoughts.length === 0;
  }

  /**
   * Add thought to stream
   * Returns NEW instance
   * @param {Thought} thought Thought to add
   * @returns {ThoughtStream}
   */
  addThought(thought) {
    if (!(thought instanceof Thought)) {
      throw new Error(`ThoughtStream.addThought: thought must be a Thought instance, got ${thought?.constructor?.name}`);
    }

    return new ThoughtStream({
      sessionId: this._sessionId,
      thoughts: [...this._thoughts, thought]
    });
  }

  /**
   * Add multiple thoughts
   * Returns NEW instance
   * @param {Array<Thought>} thoughts Thoughts to add
   * @returns {ThoughtStream}
   */
  addThoughts(thoughts) {
    if (!Array.isArray(thoughts)) {
      throw new Error(`ThoughtStream.addThoughts: thoughts must be an array, got ${typeof thoughts}`);
    }

    return new ThoughtStream({
      sessionId: this._sessionId,
      thoughts: [...this._thoughts, ...thoughts]
    });
  }

  /**
   * Get last N thoughts
   * @param {number} count Number of thoughts
   * @returns {Array<Thought>}
   */
  lastThoughts(count) {
    if (typeof count !== 'number' || count < 0) {
      throw new Error(`ThoughtStream.lastThoughts: count must be a non-negative number, got ${count}`);
    }
    return this._thoughts.slice(-count);
  }

  /**
   * Get thought by ID
   * @param {string} thoughtId Thought ID
   * @returns {Thought|null}
   */
  getThoughtById(thoughtId) {
    return this._thoughts.find(t => t.id === thoughtId) || null;
  }

  /**
   * Get thoughts for a specific message
   * @param {string} messageId Message ID
   * @returns {Array<Thought>}
   */
  getThoughtsForMessage(messageId) {
    return this._thoughts.filter(t => t.messageId === messageId);
  }

  /**
   * Serialize to JSON
   * @returns {Object}
   */
  toJSON() {
    return {
      session_id: this._sessionId,
      thoughts: this._thoughts.map(t => t.toJSON()),
      count: this._thoughts.length
    };
  }

  /**
   * Create ThoughtStream from JSON
   * @param {Object} json JSON data
   * @returns {ThoughtStream}
   */
  static fromJSON(json) {
    if (!json || typeof json !== 'object') {
      throw new Error('ThoughtStream.fromJSON: json must be an object');
    }

    const sessionId = json.session_id || json.sessionId;
    const thoughts = (json.thoughts || []).map(tJson => Thought.fromJSON(tJson));

    return new ThoughtStream({
      sessionId,
      thoughts
    });
  }

  /**
   * Create empty stream
   * @param {string} sessionId Session ID
   * @returns {ThoughtStream}
   */
  static empty(sessionId) {
    return new ThoughtStream({
      sessionId,
      thoughts: []
    });
  }
}








