import { describe, test, expect } from "vitest";
import { speed_profile } from "../../test/speedProfile";
import { ContextEntry } from "../ContextEntry";

describe("ContextEntry", () => {
  // ============================================================================
  // CREATION TESTS
  // ============================================================================

  speed_profile("fast")("creates valid context entry", () => {
    const entry = new ContextEntry({
      id: "entry-123",
      type: "function",
      name: "calculateTotal",
      path: "/app/services/calculator.rb",
      lineStart: 10,
      lineEnd: 25,
      content: "def calculate_total\n  # ...\nend",
      relevance: "Used for order calculations",
      addedAt: new Date()
    });

    expect(entry.id).toBe("entry-123");
    expect(entry.type).toBe("function");
    expect(entry.name).toBe("calculateTotal");
    expect(entry.path).toBe("/app/services/calculator.rb");
    expect(entry.lineStart).toBe(10);
    expect(entry.lineEnd).toBe(25);
  });

  speed_profile("fast")("is immutable after creation", () => {
    const entry = buildEntry();

    expect(Object.isFrozen(entry)).toBe(true);
    expect(Object.isFrozen(entry.metadata)).toBe(true);
  });

  speed_profile("fast")("allows null values for optional fields", () => {
    const entry = new ContextEntry({
      id: "entry-123",
      type: "file",
      name: "README.md",
      path: null,
      lineStart: null,
      lineEnd: null,
      content: null,
      relevance: null,
      addedAt: new Date()
    });

    expect(entry.path).toBeNull();
    expect(entry.content).toBeNull();
  });

  // ============================================================================
  // VALIDATION TESTS
  // ============================================================================

  speed_profile("fast")("validates id is required", () => {
    expect(() => {
      new ContextEntry({
        id: "",
        type: "function",
        name: "test",
        path: null,
        lineStart: null,
        lineEnd: null,
        content: null,
        relevance: null,
        addedAt: new Date()
      });
    }).toThrow(/id is required/);
  });

  speed_profile("fast")("validates type is required", () => {
    expect(() => {
      new ContextEntry({
        id: "entry-123",
        type: "",
        name: "test",
        path: null,
        lineStart: null,
        lineEnd: null,
        content: null,
        relevance: null,
        addedAt: new Date()
      });
    }).toThrow(/type is required/);
  });

  speed_profile("fast")("validates name is required", () => {
    expect(() => {
      new ContextEntry({
        id: "entry-123",
        type: "function",
        name: "",
        path: null,
        lineStart: null,
        lineEnd: null,
        content: null,
        relevance: null,
        addedAt: new Date()
      });
    }).toThrow(/name is required/);
  });

  speed_profile("fast")("validates addedAt is required", () => {
    expect(() => {
      new ContextEntry({
        id: "entry-123",
        type: "function",
        name: "test",
        path: null,
        lineStart: null,
        lineEnd: null,
        content: null,
        relevance: null,
        addedAt: null
      });
    }).toThrow(/addedAt is required/);
  });

  // ============================================================================
  // METHOD TESTS
  // ============================================================================

  speed_profile("fast")("getLocation returns path with line numbers", () => {
    const entry = buildEntry({
      path: "/app/models/user.rb",
      lineStart: 10,
      lineEnd: 20
    });

    expect(entry.getLocation()).toBe("/app/models/user.rb:10-20");
  });

  speed_profile("fast")("getLocation returns path with single line", () => {
    const entry = buildEntry({
      path: "/app/models/user.rb",
      lineStart: 10,
      lineEnd: 10
    });

    expect(entry.getLocation()).toBe("/app/models/user.rb:10");
  });

  speed_profile("fast")("getLocation returns name when no path", () => {
    const entry = buildEntry({
      path: null,
      lineStart: null,
      lineEnd: null
    });

    expect(entry.getLocation()).toBe("test_function");
  });

  speed_profile("fast")("hasContent returns true when content exists", () => {
    const entry = buildEntry({ content: "some code" });

    expect(entry.hasContent()).toBe(true);
  });

  speed_profile("fast")("hasContent returns false when no content", () => {
    const entry = buildEntry({ content: null });

    expect(entry.hasContent()).toBe(false);
  });

  speed_profile("fast")("hasLineNumbers returns true when both present", () => {
    const entry = buildEntry({ lineStart: 10, lineEnd: 20 });

    expect(entry.hasLineNumbers()).toBe(true);
  });

  speed_profile("fast")("hasLineNumbers returns false when missing", () => {
    const entry = buildEntry({ lineStart: null, lineEnd: null });

    expect(entry.hasLineNumbers()).toBe(false);
  });

  speed_profile("fast")("getContentPreview returns full content if short", () => {
    const entry = buildEntry({ content: "short" });

    expect(entry.getContentPreview(100)).toBe("short");
  });

  speed_profile("fast")("getContentPreview truncates long content", () => {
    const entry = buildEntry({ content: "A".repeat(200) });

    const preview = entry.getContentPreview(50);

    expect(preview).toHaveLength(53); // 50 + "..."
    expect(preview.endsWith("...")).toBe(true);
  });

  speed_profile("fast")("getContentPreview returns empty for no content", () => {
    const entry = buildEntry({ content: null });

    expect(entry.getContentPreview()).toBe("");
  });

  speed_profile("fast")("getLineCount returns correct count", () => {
    const entry = buildEntry({ lineStart: 10, lineEnd: 25 });

    expect(entry.getLineCount()).toBe(16); // 25 - 10 + 1
  });

  speed_profile("fast")("getLineCount returns null when no line numbers", () => {
    const entry = buildEntry({ lineStart: null, lineEnd: null });

    expect(entry.getLineCount()).toBeNull();
  });

  // ============================================================================
  // SERIALIZATION TESTS
  // ============================================================================

  speed_profile("fast")("toJSON serializes correctly", () => {
    const timestamp = new Date();
    const entry = buildEntry({
      id: "entry-789",
      content: "test code",
      addedAt: timestamp
    });

    const json = entry.toJSON();

    expect(json.id).toBe("entry-789");
    expect(json.type).toBe("function");
    expect(json.name).toBe("test_function");
    expect(json.content).toBe("test code");
    expect(json.added_at).toBe(timestamp.toISOString());
    expect(json.has_content).toBe(true);
    expect(json.location).toBeDefined();
  });

  speed_profile("fast")("fromJSON creates entry from JSON", () => {
    const json = {
      id: "entry-abc",
      type: "class",
      name: "UserService",
      path: "/app/services/user_service.rb",
      line_start: 5,
      line_end: 100,
      content: "class UserService\nend",
      relevance: "User management",
      added_at: new Date().toISOString(),
      metadata: { author: "dev" }
    };

    const entry = ContextEntry.fromJSON(json);

    expect(entry.id).toBe("entry-abc");
    expect(entry.type).toBe("class");
    expect(entry.name).toBe("UserService");
    expect(entry.lineStart).toBe(5);
    expect(entry.lineEnd).toBe(100);
  });

  speed_profile("fast")("fromJSON handles camelCase", () => {
    const json = {
      id: "entry-abc",
      type: "function",
      name: "test",
      path: null,
      lineStart: 10,
      lineEnd: 20,
      content: "code",
      relevance: "test",
      addedAt: new Date().toISOString()
    };

    const entry = ContextEntry.fromJSON(json);

    expect(entry.lineStart).toBe(10);
    expect(entry.lineEnd).toBe(20);
  });
});

// Helper function
function buildEntry(overrides = {}) {
  const defaults = {
    id: "entry-123",
    type: "function",
    name: "test_function",
    path: "/app/models/test.rb",
    lineStart: 10,
    lineEnd: 20,
    content: "def test\nend",
    relevance: "Test function",
    addedAt: new Date(),
    metadata: {}
  };

  return new ContextEntry({ ...defaults, ...overrides });
}








