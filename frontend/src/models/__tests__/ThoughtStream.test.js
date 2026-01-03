import { describe, test, expect } from "vitest";
import { speed_profile } from "../../test/speedProfile";
import { ThoughtStream } from "../ThoughtStream";
import { Thought } from "../Thought";

describe("ThoughtStream", () => {
  // ============================================================================
  // CREATION TESTS
  // ============================================================================

  speed_profile("fast")("creates empty stream", () => {
    const stream = new ThoughtStream({
      sessionId: "session-123",
      thoughts: []
    });

    expect(stream.sessionId).toBe("session-123");
    expect(stream.thoughts).toEqual([]);
    expect(stream.isEmpty()).toBe(true);
  });

  speed_profile("fast")("creates stream with thoughts", () => {
    const thoughts = [
      buildThought({ id: "t-1" }),
      buildThought({ id: "t-2" })
    ];

    const stream = new ThoughtStream({
      sessionId: "session-123",
      thoughts
    });

    expect(stream.length).toBe(2);
    expect(stream.isEmpty()).toBe(false);
  });

  speed_profile("fast")("is immutable after creation", () => {
    const stream = buildStream();

    expect(Object.isFrozen(stream)).toBe(true);
    expect(Object.isFrozen(stream.thoughts)).toBe(true);
  });

  speed_profile("fast")("stores thoughts in order", () => {
    const now = new Date();
    const thoughts = [
      buildThought({ id: "t-2", timestamp: new Date(now.getTime() + 2000) }),
      buildThought({ id: "t-1", timestamp: new Date(now.getTime() + 1000) }),
      buildThought({ id: "t-3", timestamp: new Date(now.getTime() + 3000) })
    ];

    const stream = new ThoughtStream({
      sessionId: "session-123",
      thoughts
    });

    expect(stream.thoughts[0].id).toBe("t-2");
    expect(stream.thoughts[1].id).toBe("t-1");
    expect(stream.thoughts[2].id).toBe("t-3");
  });

  // ============================================================================
  // VALIDATION TESTS
  // ============================================================================

  speed_profile("fast")("validates sessionId is required", () => {
    expect(() => {
      new ThoughtStream({
        sessionId: "",
        thoughts: []
      });
    }).toThrow(/sessionId is required/);
  });

  speed_profile("fast")("validates all thoughts are Thought instances", () => {
    expect(() => {
      new ThoughtStream({
        sessionId: "session-123",
        thoughts: [{ id: "not-a-thought" }]
      });
    }).toThrow(/must be a Thought instance/);
  });


  speed_profile("fast")("validates thoughts is array", () => {
    expect(() => {
      new ThoughtStream({
        sessionId: "session-123",
        thoughts: "not-an-array"
      });
    }).toThrow(/thoughts must be an array/);
  });

  // ============================================================================
  // MANIPULATION TESTS (immutable - return NEW instances)
  // ============================================================================

  speed_profile("fast")("addThought returns new instance with thought", () => {
    const stream = buildStream();
    const newThought = buildThought({ id: "t-new" });

    const newStream = stream.addThought(newThought);

    expect(newStream).toBeInstanceOf(ThoughtStream);
    expect(newStream).not.toBe(stream);
    expect(newStream.length).toBe(stream.length + 1);
    expect(stream.length).toBe(2); // Original unchanged
  });

  speed_profile("fast")("addThoughts returns new instance with multiple thoughts", () => {
    const stream = buildStream();
    const newThoughts = [
      buildThought({ id: "t-3" }),
      buildThought({ id: "t-4" })
    ];

    const newStream = stream.addThoughts(newThoughts);

    expect(newStream.length).toBe(4);
    expect(stream.length).toBe(2); // Original unchanged
  });

  // ============================================================================
  // QUERY TESTS
  // ============================================================================

  speed_profile("fast")("lastThoughts returns last N thoughts", () => {
    const stream = buildStream();

    const last1 = stream.lastThoughts(1);

    expect(last1).toHaveLength(1);
    expect(last1[0].id).toBe("t-2");
  });

  speed_profile("fast")("getThoughtById finds thought by id", () => {
    const stream = buildStream();

    const thought = stream.getThoughtById("t-1");

    expect(thought).not.toBeNull();
    expect(thought.id).toBe("t-1");
  });

  speed_profile("fast")("getThoughtById returns null when not found", () => {
    const stream = buildStream();

    const thought = stream.getThoughtById("nonexistent");

    expect(thought).toBeNull();
  });

  speed_profile("fast")("getThoughtsForMessage filters by messageId", () => {
    const stream = buildStream();

    const thoughts = stream.getThoughtsForMessage("msg-123");

    expect(thoughts.length).toBeGreaterThan(0);
    expect(thoughts.every(t => t.messageId === "msg-123")).toBe(true);
  });

  // ============================================================================
  // SERIALIZATION TESTS
  // ============================================================================

  speed_profile("fast")("toJSON serializes correctly", () => {
    const stream = buildStream();

    const json = stream.toJSON();

    expect(json.session_id).toBe("session-123");
    expect(json.thoughts).toHaveLength(2);
    expect(json.count).toBe(2);
  });

  speed_profile("fast")("fromJSON creates stream from JSON", () => {
    const json = {
      session_id: "session-456",
      thoughts: [
        {
          id: "t-1",
          message_id: "msg-456",
          content: "Thought",
          timestamp: new Date().toISOString()
        }
      ]
    };

    const stream = ThoughtStream.fromJSON(json);

    expect(stream.sessionId).toBe("session-456");
    expect(stream.length).toBe(1);
  });

  speed_profile("fast")("empty creates empty stream", () => {
    const stream = ThoughtStream.empty("session-789");

    expect(stream.sessionId).toBe("session-789");
    expect(stream.isEmpty()).toBe(true);
  });
});

// Helper functions
function buildThought(overrides = {}) {
  const defaults = {
    id: `t-${Date.now()}-${Math.random()}`,
    messageId: "msg-123",
    content: "Test thought",
    timestamp: new Date()
  };

  return new Thought({ ...defaults, ...overrides });
}

function buildStream(overrides = {}) {
  const defaults = {
    sessionId: "session-123",
    thoughts: [
      buildThought({ id: "t-1" }),
      buildThought({ id: "t-2" })
    ]
  };

  return new ThoughtStream({ ...defaults, ...overrides });
}

