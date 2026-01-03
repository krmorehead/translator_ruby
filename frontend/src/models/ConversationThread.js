/**
 * Domain model representing a collection of messages (conversation).
 * Provides methods for managing and querying message collections.
 * 
 * Strict OOP principles:
 * - Immutable with Object.freeze()
 * - Validation in constructor
 * - Transformation methods return NEW instances
 */
import { Message } from './Message';

export class ConversationThread {
  /**
   * Create a new ConversationThread
   * @param {Object} params Thread parameters
   * @param {string} params.sessionId Session identifier
   * @param {Array<Message>} params.messages Array of Message instances
   */
  constructor({ sessionId, messages = [] }) {
    // Validation
    if (!sessionId || typeof sessionId !== 'string') {
      throw new Error(`ConversationThread: sessionId is required and must be a string, got ${typeof sessionId}`);
    }
    if (!Array.isArray(messages)) {
      throw new Error(`ConversationThread: messages must be an array, got ${typeof messages}`);
    }

    // Validate all messages are Message instances
    messages.forEach((msg, index) => {
      if (!(msg instanceof Message)) {
        throw new Error(`ConversationThread: messages[${index}] must be a Message instance, got ${msg?.constructor?.name}`);
      }
      if (msg.sessionId !== sessionId) {
        throw new Error(`ConversationThread: messages[${index}] sessionId mismatch. Expected ${sessionId}, got ${msg.sessionId}`);
      }
    });

    this._sessionId = sessionId;
    this._messages = Object.freeze([...messages]);

    Object.freeze(this);
  }

  // Getters
  get sessionId() { return this._sessionId; }
  get messages() { return this._messages; }

  /**
   * Get number of messages
   * @returns {number}
   */
  get length() {
    return this._messages.length;
  }

  /**
   * Check if thread is empty
   * @returns {boolean}
   */
  isEmpty() {
    return this._messages.length === 0;
  }

  /**
   * Add message to thread
   * Returns NEW instance with added message
   * @param {Message} message Message to add
   * @returns {ConversationThread}
   */
  addMessage(message) {
    if (!(message instanceof Message)) {
      throw new Error(`ConversationThread.addMessage: message must be a Message instance, got ${message?.constructor?.name}`);
    }
    if (message.sessionId !== this._sessionId) {
      throw new Error(`ConversationThread.addMessage: message sessionId mismatch. Expected ${this._sessionId}, got ${message.sessionId}`);
    }

    return new ConversationThread({
      sessionId: this._sessionId,
      messages: [...this._messages, message]
    });
  }

  /**
   * Add multiple messages to thread
   * Returns NEW instance with added messages
   * @param {Array<Message>} messages Messages to add
   * @returns {ConversationThread}
   */
  addMessages(messages) {
    if (!Array.isArray(messages)) {
      throw new Error(`ConversationThread.addMessages: messages must be an array, got ${typeof messages}`);
    }

    return new ConversationThread({
      sessionId: this._sessionId,
      messages: [...this._messages, ...messages]
    });
  }

  /**
   * Get last N messages
   * @param {number} count Number of messages to get
   * @returns {Array<Message>}
   */
  lastMessages(count) {
    if (typeof count !== 'number' || count < 0) {
      throw new Error(`ConversationThread.lastMessages: count must be a non-negative number, got ${count}`);
    }
    return this._messages.slice(-count);
  }

  /**
   * Get messages from user
   * @returns {Array<Message>}
   */
  getUserMessages() {
    return this._messages.filter(msg => msg.isUser());
  }

  /**
   * Get messages from agent
   * @returns {Array<Message>}
   */
  getAgentMessages() {
    return this._messages.filter(msg => msg.isAgent());
  }

  /**
   * Get messages with thoughts
   * @returns {Array<Message>}
   */
  getMessagesWithThoughts() {
    return this._messages.filter(msg => msg.hasThoughts());
  }

  /**
   * Get message by ID
   * @param {string} messageId Message ID
   * @returns {Message|null}
   */
  getMessageById(messageId) {
    return this._messages.find(msg => msg.id === messageId) || null;
  }

  /**
   * Serialize to JSON
   * @returns {Object}
   */
  toJSON() {
    return {
      session_id: this._sessionId,
      messages: this._messages.map(msg => msg.toJSON()),
      count: this._messages.length
    };
  }

  /**
   * Create ConversationThread from JSON
   * @param {Object} json JSON data
   * @returns {ConversationThread}
   */
  static fromJSON(json) {
    if (!json || typeof json !== 'object') {
      throw new Error('ConversationThread.fromJSON: json must be an object');
    }

    const sessionId = json.session_id || json.sessionId;
    const messages = (json.messages || []).map(msgJson => Message.fromJSON(msgJson));

    return new ConversationThread({
      sessionId,
      messages
    });
  }

  /**
   * Create empty thread
   * @param {string} sessionId Session ID
   * @returns {ConversationThread}
   */
  static empty(sessionId) {
    return new ConversationThread({
      sessionId,
      messages: []
    });
  }
}








