import { describe, test, expect } from "vitest";
import { speed_profile } from "../../test/speedProfile";
import { Message } from "../Message";

describe("Message", () => {
  // ============================================================================
  // CREATION TESTS
  // ============================================================================

  speed_profile("fast")("creates valid message with all required fields", () => {
    const message = new Message({
      id: "msg-123",
      sessionId: "session-456",
      role: "user",
      content: "Hello, agent!",
      timestamp: new Date()
    });

    expect(message.id).toBe("msg-123");
    expect(message.sessionId).toBe("session-456");
    expect(message.role).toBe("user");
    expect(message.content).toBe("Hello, agent!");
    expect(message.thoughts).toBeNull();
  });

  speed_profile("fast")("creates message with thoughts", () => {
    const message = new Message({
      id: "msg-123",
      sessionId: "session-456",
      role: "agent",
      content: "Response",
      thoughts: "Let me think...",
      timestamp: new Date()
    });

    expect(message.thoughts).toBe("Let me think...");
    expect(message.hasThoughts()).toBe(true);
  });

  speed_profile("fast")("is immutable after creation", () => {
    const message = buildMessage();

    expect(Object.isFrozen(message)).toBe(true);
  });

  // ============================================================================
  // VALIDATION TESTS
  // ============================================================================

  speed_profile("fast")("validates id is required", () => {
    expect(() => {
      new Message({
        id: null,
        sessionId: "session-456",
        role: "user",
        content: "Hello",
        timestamp: new Date()
      });
    }).toThrow(/id is required/);
  });

  speed_profile("fast")("validates sessionId is required", () => {
    expect(() => {
      new Message({
        id: "msg-123",
        sessionId: "",
        role: "user",
        content: "Hello",
        timestamp: new Date()
      });
    }).toThrow(/sessionId is required/);
  });

  speed_profile("fast")("validates role is valid", () => {
    expect(() => {
      new Message({
        id: "msg-123",
        sessionId: "session-456",
        role: "invalid_role",
        content: "Hello",
        timestamp: new Date()
      });
    }).toThrow(/Invalid role/);
  });

  speed_profile("fast")("validates content is required", () => {
    expect(() => {
      new Message({
        id: "msg-123",
        sessionId: "session-456",
        role: "user",
        content: null,
        timestamp: new Date()
      });
    }).toThrow(/content is required/);
  });

  // ============================================================================
  // ROLE TESTS
  // ============================================================================

  speed_profile("fast")("isUser returns true for user role", () => {
    const message = buildMessage({ role: Message.ROLE_USER });

    expect(message.isUser()).toBe(true);
    expect(message.isAgent()).toBe(false);
    expect(message.isSystem()).toBe(false);
  });

  speed_profile("fast")("isAgent returns true for agent role", () => {
    const message = buildMessage({ role: Message.ROLE_AGENT });

    expect(message.isAgent()).toBe(true);
    expect(message.isUser()).toBe(false);
    expect(message.isSystem()).toBe(false);
  });

  speed_profile("fast")("isSystem returns true for system role", () => {
    const message = buildMessage({ role: Message.ROLE_SYSTEM });

    expect(message.isSystem()).toBe(true);
    expect(message.isUser()).toBe(false);
    expect(message.isAgent()).toBe(false);
  });

  // ============================================================================
  // THOUGHTS TESTS
  // ============================================================================

  speed_profile("fast")("hasThoughts returns false when no thoughts", () => {
    const message = buildMessage({ thoughts: null });

    expect(message.hasThoughts()).toBe(false);
  });

  speed_profile("fast")("hasThoughts returns false for empty string", () => {
    const message = buildMessage({ thoughts: "" });

    expect(message.hasThoughts()).toBe(false);
  });

  speed_profile("fast")("hasThoughts returns true when thoughts present", () => {
    const message = buildMessage({ thoughts: "Some reasoning" });

    expect(message.hasThoughts()).toBe(true);
  });

  // ============================================================================
  // SERIALIZATION TESTS
  // ============================================================================

  speed_profile("fast")("toJSON serializes correctly", () => {
    const timestamp = new Date();
    const message = buildMessage({
      id: "msg-789",
      content: "Test content",
      thoughts: "Test thoughts",
      timestamp
    });

    const json = message.toJSON();

    expect(json.id).toBe("msg-789");
    expect(json.content).toBe("Test content");
    expect(json.thoughts).toBe("Test thoughts");
    expect(json.timestamp).toBe(timestamp.toISOString());
  });

  speed_profile("fast")("fromJSON creates message from JSON", () => {
    const json = {
      id: "msg-abc",
      session_id: "session-def",
      role: "agent",
      content: "Response",
      thoughts: "Reasoning",
      timestamp: new Date().toISOString(),
      metadata: { key: "value" }
    };

    const message = Message.fromJSON(json);

    expect(message.id).toBe("msg-abc");
    expect(message.sessionId).toBe("session-def");
    expect(message.content).toBe("Response");
    expect(message.thoughts).toBe("Reasoning");
  });

  speed_profile("fast")("fromJSON handles camelCase keys", () => {
    const json = {
      id: "msg-abc",
      sessionId: "session-def",  // camelCase
      role: "agent",
      content: "Response",
      timestamp: new Date().toISOString()
    };

    const message = Message.fromJSON(json);

    expect(message.sessionId).toBe("session-def");
  });

  // ============================================================================
  // IMMUTABILITY TESTS
  // ============================================================================

  speed_profile("fast")("metadata is frozen and immutable", () => {
    const message = buildMessage({ metadata: { key: "value" } });

    expect(Object.isFrozen(message.metadata)).toBe(true);
  });

  speed_profile("fast")("cannot modify properties after creation", () => {
    const message = buildMessage();

    expect(() => {
      message.content = "modified";
    }).toThrow();
  });

  speed_profile("fast")("getFormattedTimestamp returns locale string", () => {
    const message = buildMessage();
    const formatted = message.getFormattedTimestamp();

    expect(typeof formatted).toBe("string");
    expect(formatted.length).toBeGreaterThan(0);
  });
});

// Helper function
function buildMessage(overrides = {}) {
  const defaults = {
    id: "msg-123",
    sessionId: "session-456",
    role: Message.ROLE_USER,
    content: "Test message",
    thoughts: null,
    timestamp: new Date(),
    metadata: {}
  };

  return new Message({ ...defaults, ...overrides });
}


