import { describe, test, expect } from "vitest";
import { speed_profile } from "../../test/speedProfile";
import { Context } from "../Context";
import { ContextEntry } from "../ContextEntry";

describe("Context", () => {
  // ============================================================================
  // CREATION TESTS
  // ============================================================================

  speed_profile("fast")("creates empty context", () => {
    const context = new Context({
      sessionId: "session-123",
      entries: []
    });

    expect(context.sessionId).toBe("session-123");
    expect(context.entries).toEqual([]);
    expect(context.isEmpty()).toBe(true);
  });

  speed_profile("fast")("creates context with entries", () => {
    const entries = [
      buildEntry({ id: "e-1" }),
      buildEntry({ id: "e-2" })
    ];

    const context = new Context({
      sessionId: "session-123",
      entries
    });

    expect(context.length).toBe(2);
    expect(context.isEmpty()).toBe(false);
  });

  speed_profile("fast")("is immutable after creation", () => {
    const context = buildContext();

    expect(Object.isFrozen(context)).toBe(true);
    expect(Object.isFrozen(context.entries)).toBe(true);
  });

  // ============================================================================
  // VALIDATION TESTS
  // ============================================================================

  speed_profile("fast")("validates sessionId is required", () => {
    expect(() => {
      new Context({
        sessionId: "",
        entries: []
      });
    }).toThrow(/sessionId is required/);
  });

  speed_profile("fast")("validates entries is array", () => {
    expect(() => {
      new Context({
        sessionId: "session-123",
        entries: {}
      });
    }).toThrow(/entries must be an array/);
  });

  speed_profile("fast")("validates all entries are ContextEntry instances", () => {
    expect(() => {
      new Context({
        sessionId: "session-123",
        entries: [{ id: "not-an-entry" }]
      });
    }).toThrow(/must be a ContextEntry instance/);
  });

  speed_profile("fast")("validates maxSize is positive number", () => {
    expect(() => {
      new Context({
        sessionId: "session-123",
        entries: [],
        maxSize: 0
      });
    }).toThrow(/maxSize must be a positive number/);
  });

  // ============================================================================
  // QUERY TESTS
  // ============================================================================

  speed_profile("fast")("getEntryById finds entry", () => {
    const context = buildContext();

    const entry = context.getEntryById("e-1");

    expect(entry).not.toBeNull();
    expect(entry.id).toBe("e-1");
  });

  speed_profile("fast")("getEntryById returns null when not found", () => {
    const context = buildContext();

    const entry = context.getEntryById("nonexistent");

    expect(entry).toBeNull();
  });

  speed_profile("fast")("getEntriesByType filters by type", () => {
    const entries = [
      buildEntry({ id: "e-1", type: "function" }),
      buildEntry({ id: "e-2", type: "class" }),
      buildEntry({ id: "e-3", type: "function" })
    ];

    const context = new Context({
      sessionId: "session-123",
      entries
    });

    const functions = context.getEntriesByType("function");

    expect(functions).toHaveLength(2);
    expect(functions.every(e => e.type === "function")).toBe(true);
  });

  speed_profile("fast")("getEntriesByPath filters by path", () => {
    const entries = [
      buildEntry({ id: "e-1", path: "/app/models/user.rb" }),
      buildEntry({ id: "e-2", path: "/app/models/post.rb" }),
      buildEntry({ id: "e-3", path: "/app/models/user.rb" })
    ];

    const context = new Context({
      sessionId: "session-123",
      entries
    });

    const userEntries = context.getEntriesByPath("/app/models/user.rb");

    expect(userEntries).toHaveLength(2);
  });

  speed_profile("fast")("getUniquePaths returns unique paths", () => {
    const entries = [
      buildEntry({ id: "e-1", path: "/app/models/user.rb" }),
      buildEntry({ id: "e-2", path: "/app/models/post.rb" }),
      buildEntry({ id: "e-3", path: "/app/models/user.rb" }),
      buildEntry({ id: "e-4", path: null })
    ];

    const context = new Context({
      sessionId: "session-123",
      entries
    });

    const paths = context.getUniquePaths();

    expect(paths).toHaveLength(2);
    expect(paths).toContain("/app/models/user.rb");
    expect(paths).toContain("/app/models/post.rb");
  });

  speed_profile("fast")("getUniqueTypes returns unique types", () => {
    const entries = [
      buildEntry({ id: "e-1", type: "function" }),
      buildEntry({ id: "e-2", type: "class" }),
      buildEntry({ id: "e-3", type: "function" })
    ];

    const context = new Context({
      sessionId: "session-123",
      entries
    });

    const types = context.getUniqueTypes();

    expect(types).toHaveLength(2);
    expect(types).toContain("function");
    expect(types).toContain("class");
  });

  speed_profile("fast")("getEntriesWithContent filters entries with content", () => {
    const entries = [
      buildEntry({ id: "e-1", content: "code" }),
      buildEntry({ id: "e-2", content: null }),
      buildEntry({ id: "e-3", content: "more code" })
    ];

    const context = new Context({
      sessionId: "session-123",
      entries
    });

    const withContent = context.getEntriesWithContent();

    expect(withContent).toHaveLength(2);
  });

  speed_profile("fast")("getTotalContentSize returns sum of content lengths", () => {
    const entries = [
      buildEntry({ id: "e-1", content: "12345" }), // 5 chars
      buildEntry({ id: "e-2", content: "123" }),   // 3 chars
      buildEntry({ id: "e-3", content: null })     // 0 chars
    ];

    const context = new Context({
      sessionId: "session-123",
      entries
    });

    expect(context.getTotalContentSize()).toBe(8);
  });

  speed_profile("fast")("isFull returns true when at max size", () => {
    const entries = Array.from({ length: 10 }, (_, i) => buildEntry({ id: `e-${i}` }));

    const context = new Context({
      sessionId: "session-123",
      entries,
      maxSize: 10
    });

    expect(context.isFull()).toBe(true);
  });

  // ============================================================================
  // MANIPULATION TESTS (immutable - return NEW instances)
  // ============================================================================

  speed_profile("fast")("addEntry returns new instance with entry", () => {
    const context = buildContext();
    const newEntry = buildEntry({ id: "e-new" });

    const newContext = context.addEntry(newEntry);

    expect(newContext).toBeInstanceOf(Context);
    expect(newContext).not.toBe(context);
    expect(newContext.length).toBe(context.length + 1);
    expect(context.length).toBe(2); // Original unchanged
  });

  speed_profile("fast")("addEntry enforces max size", () => {
    const entries = Array.from({ length: 5 }, (_, i) => buildEntry({ id: `e-${i}` }));
    const context = new Context({
      sessionId: "session-123",
      entries,
      maxSize: 5
    });

    const newEntry = buildEntry({ id: "e-new" });
    const newContext = context.addEntry(newEntry);

    expect(newContext.length).toBe(5); // Still at max
    expect(newContext.getEntryById("e-0")).toBeNull(); // Oldest removed
    expect(newContext.getEntryById("e-new")).not.toBeNull(); // New added
  });

  speed_profile("fast")("addEntry updates existing entry if same ID", () => {
    const context = buildContext();
    const updatedEntry = buildEntry({
      id: "e-1",
      name: "updated_name"
    });

    const newContext = context.addEntry(updatedEntry);

    expect(newContext.length).toBe(2); // Same length
    expect(newContext.getEntryById("e-1").name).toBe("updated_name");
  });

  speed_profile("fast")("addEntries adds multiple entries", () => {
    const context = buildContext();
    const newEntries = [
      buildEntry({ id: "e-3" }),
      buildEntry({ id: "e-4" })
    ];

    const newContext = context.addEntries(newEntries);

    expect(newContext.length).toBe(4);
  });

  speed_profile("fast")("updateEntry returns new instance with updated entry", () => {
    const context = buildContext();
    const updatedEntry = buildEntry({
      id: "e-1",
      name: "updated_function"
    });

    const newContext = context.updateEntry(updatedEntry);

    expect(newContext.getEntryById("e-1").name).toBe("updated_function");
    expect(context.getEntryById("e-1").name).toBe("test_function"); // Original unchanged
  });

  speed_profile("fast")("removeEntry returns new instance without entry", () => {
    const context = buildContext();

    const newContext = context.removeEntry("e-1");

    expect(newContext.length).toBe(1);
    expect(newContext.getEntryById("e-1")).toBeNull();
    expect(context.length).toBe(2); // Original unchanged
  });

  speed_profile("fast")("clear returns empty context", () => {
    const context = buildContext();

    const newContext = context.clear();

    expect(newContext.isEmpty()).toBe(true);
    expect(newContext.sessionId).toBe(context.sessionId);
    expect(context.length).toBe(2); // Original unchanged
  });

  // ============================================================================
  // SERIALIZATION TESTS
  // ============================================================================

  speed_profile("fast")("toJSON serializes correctly", () => {
    const context = buildContext();

    const json = context.toJSON();

    expect(json.session_id).toBe("session-123");
    expect(json.entries).toHaveLength(2);
    expect(json.max_size).toBe(100);
    expect(json.count).toBe(2);
    expect(json.total_content_size).toBeGreaterThan(0);
    expect(json.unique_paths).toBeDefined();
    expect(json.unique_types).toBeDefined();
  });

  speed_profile("fast")("fromJSON creates context from JSON", () => {
    const json = {
      session_id: "session-456",
      max_size: 50,
      entries: [
        {
          id: "e-1",
          type: "function",
          name: "test",
          path: "/test.rb",
          line_start: 1,
          line_end: 10,
          content: "code",
          relevance: "test",
          added_at: new Date().toISOString()
        }
      ]
    };

    const context = Context.fromJSON(json);

    expect(context.sessionId).toBe("session-456");
    expect(context.maxSize).toBe(50);
    expect(context.length).toBe(1);
  });

  speed_profile("fast")("empty creates empty context", () => {
    const context = Context.empty("session-789", 50);

    expect(context.sessionId).toBe("session-789");
    expect(context.maxSize).toBe(50);
    expect(context.isEmpty()).toBe(true);
  });
});

// Helper functions
function buildEntry(overrides = {}) {
  const defaults = {
    id: `entry-${Date.now()}-${Math.random()}`,
    type: "function",
    name: "test_function",
    path: "/app/models/test.rb",
    lineStart: 10,
    lineEnd: 20,
    content: "def test\nend",
    relevance: "Test",
    addedAt: new Date()
  };

  return new ContextEntry({ ...defaults, ...overrides });
}

function buildContext(overrides = {}) {
  const defaults = {
    sessionId: "session-123",
    entries: [
      buildEntry({ id: "e-1" }),
      buildEntry({ id: "e-2" })
    ],
    maxSize: 100
  };

  return new Context({ ...defaults, ...overrides });
}


