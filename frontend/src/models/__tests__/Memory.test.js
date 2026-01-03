import { describe, test, expect } from "vitest";
import { speed_profile } from "../../test/speedProfile";
import { Memory } from "../Memory";
import { MemorySection } from "../MemorySection";

describe("Memory", () => {
  // ============================================================================
  // CREATION TESTS
  // ============================================================================

  speed_profile("fast")("creates empty memory", () => {
    const memory = new Memory({
      agentType: "daedalus",
      sections: []
    });

    expect(memory.agentType).toBe("daedalus");
    expect(memory.sections).toEqual([]);
    expect(memory.isEmpty()).toBe(true);
  });

  speed_profile("fast")("creates memory with sections", () => {
    const sections = [
      buildSection({ sectionName: "findings" }),
      buildSection({ sectionName: "context" })
    ];

    const memory = new Memory({
      agentType: "daedalus",
      sections
    });

    expect(memory.length).toBe(2);
    expect(memory.isEmpty()).toBe(false);
  });

  speed_profile("fast")("is immutable after creation", () => {
    const memory = buildMemory();

    expect(Object.isFrozen(memory)).toBe(true);
    expect(Object.isFrozen(memory.sections)).toBe(true);
  });

  // ============================================================================
  // VALIDATION TESTS
  // ============================================================================

  speed_profile("fast")("validates agentType is required", () => {
    expect(() => {
      new Memory({
        agentType: "",
        sections: []
      });
    }).toThrow(/agentType is required/);
  });

  speed_profile("fast")("validates sections is array", () => {
    expect(() => {
      new Memory({
        agentType: "daedalus",
        sections: {}
      });
    }).toThrow(/sections must be an array/);
  });

  speed_profile("fast")("validates all sections are MemorySection instances", () => {
    expect(() => {
      new Memory({
        agentType: "daedalus",
        sections: [{ sectionName: "findings" }]
      });
    }).toThrow(/must be a MemorySection instance/);
  });

  // ============================================================================
  // QUERY TESTS
  // ============================================================================

  speed_profile("fast")("getSectionByName returns section by name", () => {
    const memory = buildMemory();

    const section = memory.getSectionByName("findings");

    expect(section).toBeInstanceOf(MemorySection);
    expect(section.sectionName).toBe("findings");
  });

  speed_profile("fast")("getSectionByName returns null for missing section", () => {
    const memory = buildMemory();

    const section = memory.getSectionByName("nonexistent");

    expect(section).toBeNull();
  });

  speed_profile("fast")("getSectionNames returns all section names", () => {
    const memory = buildMemory();

    const names = memory.getSectionNames();

    expect(names).toContain("findings");
    expect(names).toContain("context");
    expect(names).toHaveLength(2);
  });

  speed_profile("fast")("getNonEmptySections filters empty sections", () => {
    const sections = [
      buildSection({ sectionName: "findings", content: ["item"] }),
      buildSection({ sectionName: "empty", content: [] })
    ];

    const memory = new Memory({
      agentType: "daedalus",
      sections
    });

    const nonEmpty = memory.getNonEmptySections();

    expect(nonEmpty).toHaveLength(1);
    expect(nonEmpty[0].sectionName).toBe("findings");
  });

  // ============================================================================
  // MANIPULATION TESTS (immutable - return NEW instances)
  // ============================================================================

  speed_profile("fast")("updateSection returns new instance (adds if missing)", () => {
    const memory = buildMemory();
    const newSection = buildSection({
      sectionName: "new_section",
      content: ["new content"]
    });

    const newMemory = memory.updateSection(newSection);

    expect(newMemory).toBeInstanceOf(Memory);
    expect(newMemory).not.toBe(memory);
    expect(newMemory.length).toBe(3);
    expect(memory.length).toBe(2); // Original unchanged
  });

  speed_profile("fast")("removeSection returns new instance without section", () => {
    const memory = buildMemory();

    const newMemory = memory.removeSection("findings");

    expect(newMemory.length).toBe(1);
    expect(newMemory.getSectionByName("findings")).toBeNull();
    expect(memory.length).toBe(2); // Original unchanged
  });

  // ============================================================================
  // SERIALIZATION TESTS
  // ============================================================================

  speed_profile("fast")("toJSON serializes correctly", () => {
    const memory = buildMemory();

    const json = memory.toJSON();

    expect(json.agent_type).toBe("daedalus");
    expect(json.sections).toBeInstanceOf(Array);
    expect(json.sections).toHaveLength(2);
    expect(json.count).toBe(2);
  });

  speed_profile("fast")("fromJSON creates memory from JSON", () => {
    const json = {
      agent_type: "sisyphus",
      sections: [
        {
          section_name: "findings",
          content: ["finding"],
          timestamp: new Date().toISOString()
        }
      ]
    };

    const memory = Memory.fromJSON(json);

    expect(memory.agentType).toBe("sisyphus");
    expect(memory.length).toBe(1);
    expect(memory.getSectionByName("findings")).not.toBeNull();
  });

  speed_profile("fast")("empty creates empty memory", () => {
    const memory = Memory.empty("daedalus");

    expect(memory.agentType).toBe("daedalus");
    expect(memory.isEmpty()).toBe(true);
  });
});

// Helper functions
function buildSection(overrides = {}) {
  const defaults = {
    sectionName: "test_section",
    content: ["test content"],
    timestamp: new Date()
  };

  return new MemorySection({ ...defaults, ...overrides });
}

function buildMemory(overrides = {}) {
  const defaults = {
    agentType: "daedalus",
    sections: [
      buildSection({ sectionName: "findings", content: ["finding 1"] }),
      buildSection({ sectionName: "context", content: ["context 1"] })
    ]
  };

  return new Memory({ ...defaults, ...overrides });
}

