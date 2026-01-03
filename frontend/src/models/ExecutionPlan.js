// ExecutionPlan domain model - represents a Daedalus execution plan
// Follows strict OOP patterns from oop-patterns.md

export class ExecutionPlan {
  constructor({
    goal,
    constraints,
    assumptions,
    risks,
    milestones,
    outputPaths,
    analysisSummary,
    metadata,
  }) {
    // Validate required parameters
    if (!goal || typeof goal !== "string") {
      throw new Error("goal must be a non-empty string");
    }
    if (!Array.isArray(constraints)) {
      throw new Error("constraints must be an array");
    }
    if (!Array.isArray(assumptions)) {
      throw new Error("assumptions must be an array");
    }
    if (!Array.isArray(risks)) {
      throw new Error("risks must be an array");
    }
    if (!Array.isArray(milestones)) {
      throw new Error("milestones must be an array");
    }
    if (!outputPaths || typeof outputPaths !== "object") {
      throw new Error("outputPaths must be an object");
    }
    if (!analysisSummary || typeof analysisSummary !== "object") {
      throw new Error("analysisSummary must be an object");
    }
    if (!metadata || typeof metadata !== "object") {
      throw new Error("metadata must be an object");
    }

    this._goal = goal;
    this._constraints = Object.freeze([...constraints]);
    this._assumptions = Object.freeze([...assumptions]);
    this._risks = Object.freeze([...risks]);
    this._milestones = Object.freeze(
      milestones.map((m) => Object.freeze({ ...m }))
    );
    this._outputPaths = Object.freeze({ ...outputPaths });
    this._analysisSummary = Object.freeze({ ...analysisSummary });
    this._metadata = Object.freeze({ ...metadata });

    Object.freeze(this);
  }

  get goal() {
    return this._goal;
  }

  get constraints() {
    return this._constraints;
  }

  get assumptions() {
    return this._assumptions;
  }

  get risks() {
    return this._risks;
  }

  get milestones() {
    return this._milestones;
  }

  get outputPaths() {
    return this._outputPaths;
  }

  get analysisSummary() {
    return this._analysisSummary;
  }

  get metadata() {
    return this._metadata;
  }

  // Get milestone by index
  getMilestone(index) {
    return this._milestones[index] || null;
  }

  // Get total milestone count
  getMilestoneCount() {
    return this._milestones.length;
  }

  // Get total step count across all milestones
  getStepCount() {
    return this._milestones.reduce(
      (total, milestone) => total + (milestone.steps?.length || 0),
      0
    );
  }

  // Serialize to JSON
  toJSON() {
    return {
      goal: this._goal,
      constraints: this._constraints,
      assumptions: this._assumptions,
      risks: this._risks,
      milestones: this._milestones,
      output_paths: this._outputPaths,
      analysis_summary: this._analysisSummary,
      metadata: this._metadata,
    };
  }

  // Deserialize from JSON (from API response)
  static fromJSON(json) {
    if (!json || typeof json !== "object") {
      throw new Error("JSON must be an object");
    }

    // Handle both camelCase (frontend) and snake_case (backend) keys
    const executionPlan = json.execution_plan || json;

    return new ExecutionPlan({
      goal: executionPlan.goal,
      constraints: executionPlan.constraints || [],
      assumptions: executionPlan.assumptions || [],
      risks: executionPlan.risks || [],
      milestones: executionPlan.milestones || [],
      outputPaths: json.output_paths || executionPlan.output_paths || {},
      analysisSummary:
        json.analysis_summary || executionPlan.analysis_summary || {},
      metadata: json.metadata || {},
    });
  }

  // Create from Daedalus API response
  static fromDaedalusResponse(response) {
    if (!response || !response.result) {
      throw new Error("Invalid Daedalus response");
    }

    return ExecutionPlan.fromJSON({
      execution_plan: response.result.execution_plan,
      output_paths: response.result.output_paths,
      analysis_summary: response.result.analysis_summary,
      metadata: response.metadata,
    });
  }
}


