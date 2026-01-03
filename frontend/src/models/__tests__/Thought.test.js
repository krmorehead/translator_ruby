import { describe, test, expect } from "vitest";
import { speed_profile } from "../../test/speedProfile";
import { Thought } from "../Thought";

describe("Thought", () => {
  // ============================================================================
  // CREATION TESTS
  // ============================================================================

  speed_profile("fast")("creates valid thought", () => {
    const thought = new Thought({
      id: "thought-123",
      messageId: "msg-456",
      content: "Let me think about this...",
      timestamp: new Date()
    });

    expect(thought.id).toBe("thought-123");
    expect(thought.messageId).toBe("msg-456");
    expect(thought.content).toBe("Let me think about this...");
  });

  speed_profile("fast")("is immutable after creation", () => {
    const thought = buildThought();

    expect(Object.isFrozen(thought)).toBe(true);
  });

  // ============================================================================
  // VALIDATION TESTS
  // ============================================================================

  speed_profile("fast")("validates id is required", () => {
    expect(() => {
      new Thought({
        id: null,
        messageId: "msg-456",
        content: "Reasoning",
        timestamp: new Date()
      });
    }).toThrow(/id is required/);
  });

  speed_profile("fast")("validates messageId is required", () => {
    expect(() => {
      new Thought({
        id: "thought-123",
        messageId: "",
        content: "Reasoning",
        timestamp: new Date()
      });
    }).toThrow(/messageId is required/);
  });

  speed_profile("fast")("validates content is required", () => {
    expect(() => {
      new Thought({
        id: "thought-123",
        messageId: "msg-456",
        content: "",
        timestamp: new Date()
      });
    }).toThrow(/content is required/);
  });

  speed_profile("fast")("validates timestamp is required", () => {
    expect(() => {
      new Thought({
        id: "thought-123",
        messageId: "msg-456",
        content: "Reasoning",
        timestamp: null
      });
    }).toThrow(/timestamp is required/);
  });

  // ============================================================================
  // METHOD TESTS
  // ============================================================================

  speed_profile("fast")("getFormattedTimestamp returns locale string", () => {
    const thought = buildThought();

    const formatted = thought.getFormattedTimestamp();

    expect(typeof formatted).toBe("string");
    expect(formatted.length).toBeGreaterThan(0);
  });

  speed_profile("fast")("getPreview returns first N characters", () => {
    const thought = buildThought({
      content: "A".repeat(200)
    });

    const preview = thought.getPreview(50);

    expect(preview).toHaveLength(53); // 50 + "..."
    expect(preview.endsWith("...")).toBe(true);
  });

  speed_profile("fast")("getPreview returns full content if short enough", () => {
    const thought = buildThought({
      content: "Short content"
    });

    const preview = thought.getPreview(100);

    expect(preview).toBe("Short content");
  });

  // ============================================================================
  // SERIALIZATION TESTS
  // ============================================================================

  speed_profile("fast")("toJSON serializes correctly", () => {
    const timestamp = new Date();
    const thought = buildThought({
      id: "thought-789",
      content: "Test reasoning",
      timestamp
    });

    const json = thought.toJSON();

    expect(json.id).toBe("thought-789");
    expect(json.message_id).toBe("msg-456");
    expect(json.content).toBe("Test reasoning");
    expect(json.timestamp).toBe(timestamp.toISOString());
  });

  speed_profile("fast")("fromJSON creates thought from JSON", () => {
    const json = {
      id: "thought-abc",
      message_id: "msg-def",
      content: "Reasoning",
      timestamp: new Date().toISOString(),
      metadata: { key: "value" }
    };

    const thought = Thought.fromJSON(json);

    expect(thought.id).toBe("thought-abc");
    expect(thought.messageId).toBe("msg-def");
    expect(thought.content).toBe("Reasoning");
  });

  speed_profile("fast")("fromJSON handles thoughts field", () => {
    const json = {
      id: "thought-abc",
      message_id: "msg-def",
      thoughts: "Reasoning from thoughts field",
      timestamp: new Date().toISOString()
    };

    const thought = Thought.fromJSON(json);

    expect(thought.content).toBe("Reasoning from thoughts field");
  });

  speed_profile("fast")("metadata is frozen", () => {
    const thought = buildThought({
      metadata: { key: "value" }
    });

    expect(Object.isFrozen(thought.metadata)).toBe(true);
  });
});

// Helper function
function buildThought(overrides = {}) {
  const defaults = {
    id: "thought-123",
    messageId: "msg-456",
    content: "Test reasoning",
    timestamp: new Date(),
    metadata: {}
  };

  return new Thought({ ...defaults, ...overrides });
}


