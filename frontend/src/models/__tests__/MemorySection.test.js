import { describe, test, expect } from "vitest";
import { speed_profile } from "../../test/speedProfile";
import { MemorySection } from "../MemorySection";

describe("MemorySection", () => {
  // ============================================================================
  // CREATION TESTS
  // ============================================================================

  speed_profile("fast")("creates section with array content", () => {
    const section = new MemorySection({
      sectionName: "findings",
      content: ["finding 1", "finding 2"],
      timestamp: new Date()
    });

    expect(section.sectionName).toBe("findings");
    expect(section.content).toEqual(["finding 1", "finding 2"]);
    expect(section.getSize()).toBe(2);
  });

  speed_profile("fast")("creates section with object content", () => {
    const section = new MemorySection({
      sectionName: "context_chain",
      content: { key: "value", nested: { data: "test" } },
      timestamp: new Date()
    });

    expect(typeof section.content).toBe("object");
    expect(section.content.key).toBe("value");
  });

  speed_profile("fast")("is immutable after creation", () => {
    const section = buildSection();

    expect(Object.isFrozen(section)).toBe(true);
  });

  speed_profile("fast")("content is deeply frozen", () => {
    const section = buildSection({
      content: { arr: [1, 2], nested: { key: "value" } }
    });

    expect(Object.isFrozen(section.content)).toBe(true);
    expect(Object.isFrozen(section.content.arr)).toBe(true);
    expect(Object.isFrozen(section.content.nested)).toBe(true);
  });

  // ============================================================================
  // VALIDATION TESTS
  // ============================================================================

  speed_profile("fast")("validates sectionName is required", () => {
    expect(() => {
      new MemorySection({
        sectionName: "",
        content: [],
        timestamp: new Date()
      });
    }).toThrow(/sectionName is required/);
  });

  speed_profile("fast")("validates content is required", () => {
    expect(() => {
      new MemorySection({
        sectionName: "test",
        content: null,
        timestamp: new Date()
      });
    }).toThrow(/content is required/);
  });

  speed_profile("fast")("validates timestamp is required", () => {
    expect(() => {
      new MemorySection({
        sectionName: "test",
        content: [],
        timestamp: null
      });
    }).toThrow(/timestamp is required/);
  });

  // ============================================================================
  // QUERY TESTS
  // ============================================================================

  speed_profile("fast")("isEmpty returns true for empty array", () => {
    const section = buildSection({ content: [] });

    expect(section.isEmpty()).toBe(true);
  });

  speed_profile("fast")("isEmpty returns true for empty object", () => {
    const section = buildSection({ content: {} });

    expect(section.isEmpty()).toBe(true);
  });

  speed_profile("fast")("isEmpty returns false for non-empty array", () => {
    const section = buildSection({ content: ["item"] });

    expect(section.isEmpty()).toBe(false);
  });

  speed_profile("fast")("getSize returns array length", () => {
    const section = buildSection({ content: [1, 2, 3, 4, 5] });

    expect(section.getSize()).toBe(5);
  });

  speed_profile("fast")("getSize returns object key count", () => {
    const section = buildSection({ content: { a: 1, b: 2, c: 3 } });

    expect(section.getSize()).toBe(3);
  });

  speed_profile("fast")("getSize returns null for non-collection", () => {
    const section = buildSection({ content: "string" });

    expect(section.getSize()).toBeNull();
  });

  speed_profile("fast")("getFormattedTimestamp returns locale string", () => {
    const section = buildSection();

    const formatted = section.getFormattedTimestamp();

    expect(typeof formatted).toBe("string");
    expect(formatted.length).toBeGreaterThan(0);
  });

  // ============================================================================
  // SERIALIZATION TESTS
  // ============================================================================

  speed_profile("fast")("toJSON serializes correctly", () => {
    const timestamp = new Date();
    const section = buildSection({
      sectionName: "test_section",
      content: ["item1", "item2"],
      timestamp,
      metadata: { agent_type: "daedalus" }
    });

    const json = section.toJSON();

    expect(json.section_name).toBe("test_section");
    expect(json.content).toEqual(["item1", "item2"]);
    expect(json.timestamp).toBe(timestamp.toISOString());
    expect(json.size).toBe(2);
    expect(json.empty).toBe(false);
  });

  speed_profile("fast")("fromJSON creates section from JSON", () => {
    const json = {
      section_name: "findings",
      content: ["finding"],
      timestamp: new Date().toISOString(),
      metadata: { test: true }
    };

    const section = MemorySection.fromJSON(json);

    expect(section.sectionName).toBe("findings");
    expect(section.content).toEqual(["finding"]);
  });

  speed_profile("fast")("fromJSON handles camelCase", () => {
    const json = {
      sectionName: "findings",
      content: ["finding"],
      timestamp: new Date().toISOString()
    };

    const section = MemorySection.fromJSON(json);

    expect(section.sectionName).toBe("findings");
  });
});

// Helper function
function buildSection(overrides = {}) {
  const defaults = {
    sectionName: "test_section",
    content: ["test content"],
    timestamp: new Date(),
    metadata: {}
  };

  return new MemorySection({ ...defaults, ...overrides });
}


