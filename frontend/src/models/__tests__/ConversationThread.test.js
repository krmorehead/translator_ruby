import { describe, test, expect } from "vitest";
import { speed_profile } from "../../test/speedProfile";
import { ConversationThread } from "../ConversationThread";
import { Message } from "../Message";

describe("ConversationThread", () => {
  // ============================================================================
  // CREATION TESTS
  // ============================================================================

  speed_profile("fast")("creates empty thread", () => {
    const thread = new ConversationThread({
      sessionId: "session-123",
      messages: []
    });

    expect(thread.sessionId).toBe("session-123");
    expect(thread.messages).toEqual([]);
    expect(thread.isEmpty()).toBe(true);
  });

  speed_profile("fast")("creates thread with messages", () => {
    const messages = [
      buildMessage({ id: "msg-1" }),
      buildMessage({ id: "msg-2" })
    ];

    const thread = new ConversationThread({
      sessionId: "session-123",
      messages
    });

    expect(thread.length).toBe(2);
    expect(thread.isEmpty()).toBe(false);
  });

  speed_profile("fast")("is immutable after creation", () => {
    const thread = buildThread();

    expect(Object.isFrozen(thread)).toBe(true);
    expect(Object.isFrozen(thread.messages)).toBe(true);
  });

  // ============================================================================
  // VALIDATION TESTS
  // ============================================================================

  speed_profile("fast")("validates sessionId is required", () => {
    expect(() => {
      new ConversationThread({
        sessionId: "",
        messages: []
      });
    }).toThrow(/sessionId is required/);
  });

  speed_profile("fast")("validates messages is array", () => {
    expect(() => {
      new ConversationThread({
        sessionId: "session-123",
        messages: "not an array"
      });
    }).toThrow(/messages must be an array/);
  });

  speed_profile("fast")("validates all messages are Message instances", () => {
    expect(() => {
      new ConversationThread({
        sessionId: "session-123",
        messages: [{ id: "not-a-message" }]
      });
    }).toThrow(/must be a Message instance/);
  });

  speed_profile("fast")("validates message sessionIds match", () => {
    const message = buildMessage({ sessionId: "different-session" });

    expect(() => {
      new ConversationThread({
        sessionId: "session-123",
        messages: [message]
      });
    }).toThrow(/sessionId mismatch/);
  });

  // ============================================================================
  // MANIPULATION TESTS (immutable - return NEW instances)
  // ============================================================================

  speed_profile("fast")("addMessage returns new instance with message", () => {
    const thread = buildThread();
    const newMessage = buildMessage({ id: "msg-new" });

    const newThread = thread.addMessage(newMessage);

    expect(newThread).toBeInstanceOf(ConversationThread);
    expect(newThread).not.toBe(thread);
    expect(newThread.length).toBe(thread.length + 1);
    expect(thread.length).toBe(2); // Original unchanged
  });

  speed_profile("fast")("addMessages returns new instance with multiple messages", () => {
    const thread = buildThread();
    const newMessages = [
      buildMessage({ id: "msg-3" }),
      buildMessage({ id: "msg-4" })
    ];

    const newThread = thread.addMessages(newMessages);

    expect(newThread.length).toBe(4);
    expect(thread.length).toBe(2); // Original unchanged
  });

  // ============================================================================
  // QUERY TESTS
  // ============================================================================

  speed_profile("fast")("lastMessages returns last N messages", () => {
    const thread = buildThread();

    const last1 = thread.lastMessages(1);

    expect(last1).toHaveLength(1);
    expect(last1[0].id).toBe("msg-2");
  });

  speed_profile("fast")("getUserMessages filters user messages", () => {
    const messages = [
      buildMessage({ id: "msg-1", role: Message.ROLE_USER }),
      buildMessage({ id: "msg-2", role: Message.ROLE_AGENT }),
      buildMessage({ id: "msg-3", role: Message.ROLE_USER })
    ];

    const thread = new ConversationThread({
      sessionId: "session-123",
      messages
    });

    const userMessages = thread.getUserMessages();

    expect(userMessages).toHaveLength(2);
    expect(userMessages[0].id).toBe("msg-1");
    expect(userMessages[1].id).toBe("msg-3");
  });

  speed_profile("fast")("getAgentMessages filters agent messages", () => {
    const messages = [
      buildMessage({ id: "msg-1", role: Message.ROLE_USER }),
      buildMessage({ id: "msg-2", role: Message.ROLE_AGENT }),
      buildMessage({ id: "msg-3", role: Message.ROLE_AGENT })
    ];

    const thread = new ConversationThread({
      sessionId: "session-123",
      messages
    });

    const agentMessages = thread.getAgentMessages();

    expect(agentMessages).toHaveLength(2);
  });

  speed_profile("fast")("getMessagesWithThoughts filters messages with thoughts", () => {
    const messages = [
      buildMessage({ id: "msg-1", thoughts: null }),
      buildMessage({ id: "msg-2", thoughts: "Reasoning" }),
      buildMessage({ id: "msg-3", thoughts: "More reasoning" })
    ];

    const thread = new ConversationThread({
      sessionId: "session-123",
      messages
    });

    const withThoughts = thread.getMessagesWithThoughts();

    expect(withThoughts).toHaveLength(2);
  });

  speed_profile("fast")("getMessageById finds message by id", () => {
    const thread = buildThread();

    const message = thread.getMessageById("msg-1");

    expect(message).not.toBeNull();
    expect(message.id).toBe("msg-1");
  });

  speed_profile("fast")("getMessageById returns null when not found", () => {
    const thread = buildThread();

    const message = thread.getMessageById("nonexistent");

    expect(message).toBeNull();
  });

  // ============================================================================
  // SERIALIZATION TESTS
  // ============================================================================

  speed_profile("fast")("toJSON serializes correctly", () => {
    const thread = buildThread();

    const json = thread.toJSON();

    expect(json.session_id).toBe("session-123");
    expect(json.messages).toHaveLength(2);
    expect(json.count).toBe(2);
  });

  speed_profile("fast")("fromJSON creates thread from JSON", () => {
    const json = {
      session_id: "session-456",
      messages: [
        {
          id: "msg-1",
          session_id: "session-456",
          role: "user",
          content: "Hello",
          timestamp: new Date().toISOString()
        }
      ]
    };

    const thread = ConversationThread.fromJSON(json);

    expect(thread.sessionId).toBe("session-456");
    expect(thread.length).toBe(1);
  });

  speed_profile("fast")("empty creates empty thread", () => {
    const thread = ConversationThread.empty("session-789");

    expect(thread.sessionId).toBe("session-789");
    expect(thread.isEmpty()).toBe(true);
  });
});

// Helper functions
function buildMessage(overrides = {}) {
  const defaults = {
    id: `msg-${Date.now()}`,
    sessionId: "session-123",
    role: Message.ROLE_USER,
    content: "Test message",
    timestamp: new Date()
  };

  return new Message({ ...defaults, ...overrides });
}

function buildThread(overrides = {}) {
  const defaults = {
    sessionId: "session-123",
    messages: [
      buildMessage({ id: "msg-1" }),
      buildMessage({ id: "msg-2" })
    ]
  };

  return new ConversationThread({ ...defaults, ...overrides });
}








