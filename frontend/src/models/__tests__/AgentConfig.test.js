import { describe, test, expect } from "vitest";
import { speed_profile } from "../../test/speedProfile";
import { AgentConfig } from "../AgentConfig";

describe("AgentConfig", () => {
  speed_profile("fast")("creates instance with valid parameters", () => {
    const config = new AgentConfig({
      capabilities: {
        general_llm: {
          model_name: "test_model",
          port: 52003,
          max_context: 64000,
          base_url: "http://localhost",
        },
      },
      environment: {
        rails_env: "test",
      },
    });

    expect(config).toBeInstanceOf(AgentConfig);
  });

  speed_profile("fast")("throws error for invalid capabilities", () => {
    expect(() => {
      new AgentConfig({
        capabilities: null,
        environment: {},
      });
    }).toThrow("capabilities must be an object");
  });

  speed_profile("fast")("throws error for invalid environment", () => {
    expect(() => {
      new AgentConfig({
        capabilities: {},
        environment: null,
      });
    }).toThrow("environment must be an object");
  });

  speed_profile("fast")("getCapability returns capability by name", () => {
    const config = new AgentConfig({
      capabilities: {
        general_llm: {
          model_name: "test_model",
          port: 52003,
        },
      },
      environment: {},
    });

    const capability = config.getCapability("general_llm");
    expect(capability).toEqual({
      model_name: "test_model",
      port: 52003,
    });
  });

  speed_profile("fast")("getCapability returns null for unknown capability", () => {
    const config = new AgentConfig({
      capabilities: {},
      environment: {},
    });

    expect(config.getCapability("unknown")).toBe(null);
  });

  speed_profile("fast")("getCapabilityNames returns array of names", () => {
    const config = new AgentConfig({
      capabilities: {
        general_llm: {},
        tool_calling: {},
      },
      environment: {},
    });

    const names = config.getCapabilityNames();
    expect(names).toEqual(["general_llm", "tool_calling"]);
  });

  speed_profile("fast")("hasCapability checks for capability existence", () => {
    const config = new AgentConfig({
      capabilities: {
        general_llm: {},
      },
      environment: {},
    });

    expect(config.hasCapability("general_llm")).toBe(true);
    expect(config.hasCapability("unknown")).toBe(false);
  });

  speed_profile("fast")("toJSON serializes to JSON", () => {
    const config = new AgentConfig({
      capabilities: {
        general_llm: { port: 52003 },
      },
      environment: {
        rails_env: "test",
      },
    });

    const json = config.toJSON();
    expect(json).toEqual({
      capabilities: {
        general_llm: { port: 52003 },
      },
      environment: {
        rails_env: "test",
      },
    });
  });

  speed_profile("fast")("fromJSON deserializes from JSON", () => {
    const json = {
      capabilities: {
        general_llm: { port: 52003 },
      },
      environment: {
        rails_env: "test",
      },
    };

    const config = AgentConfig.fromJSON(json);
    expect(config).toBeInstanceOf(AgentConfig);
    expect(config.getCapability("general_llm").port).toBe(52003);
  });

  speed_profile("fast")("fromJSON throws error for invalid JSON", () => {
    expect(() => {
      AgentConfig.fromJSON(null);
    }).toThrow("JSON must be an object");
  });

  speed_profile("fast")("is immutable", () => {
    const config = new AgentConfig({
      capabilities: {},
      environment: {},
    });

    expect(() => {
      config.capabilities = {};
    }).toThrow();
  });
});

