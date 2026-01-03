// AgentConfig domain model - mirrors backend Configuration::AgentConfig
// Follows strict OOP patterns from oop-patterns.md

export class AgentConfig {
  constructor({ capabilities, environment }) {
    // Validate parameters
    if (!capabilities || typeof capabilities !== "object") {
      throw new Error("capabilities must be an object");
    }
    if (!environment || typeof environment !== "object") {
      throw new Error("environment must be an object");
    }

    this._capabilities = Object.freeze({ ...capabilities });
    this._environment = Object.freeze({ ...environment });

    Object.freeze(this);
  }

  get capabilities() {
    return this._capabilities;
  }

  get environment() {
    return this._environment;
  }

  // Get capability by name
  getCapability(name) {
    return this._capabilities[name] || null;
  }

  // Get all capability names
  getCapabilityNames() {
    return Object.keys(this._capabilities);
  }

  // Check if capability exists
  hasCapability(name) {
    return name in this._capabilities;
  }

  // Serialize to JSON
  toJSON() {
    return {
      capabilities: this._capabilities,
      environment: this._environment,
    };
  }

  // Deserialize from JSON
  static fromJSON(json) {
    if (!json || typeof json !== "object") {
      throw new Error("JSON must be an object");
    }

    return new AgentConfig({
      capabilities: json.capabilities || {},
      environment: json.environment || {},
    });
  }
}








