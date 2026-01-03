import { describe, test, expect, beforeEach } from "vitest";
import { speed_profile } from "../../test/speedProfile";
import { useAgentStore } from "../agentStore";

describe("AgentStore", () => {
  beforeEach(() => {
    useAgentStore.getState().reset();
  });

  speed_profile("fast")("initializes with daedalus mode", () => {
    const state = useAgentStore.getState();
    expect(state.mode).toBe("daedalus");
  });

  speed_profile("fast")("switches between modes", () => {
    const { setMode } = useAgentStore.getState();
    
    setMode("sisyphus");
    expect(useAgentStore.getState().mode).toBe("sisyphus");
    
    setMode("daedalus");
    expect(useAgentStore.getState().mode).toBe("daedalus");
  });

  speed_profile("fast")("updates project path", () => {
    const { setProjectPath } = useAgentStore.getState();
    
    setProjectPath("/test/project");
    expect(useAgentStore.getState().projectPath).toBe("/test/project");
  });

  speed_profile("fast")("initializes daedalus state correctly", () => {
    const state = useAgentStore.getState();
    
    expect(state.daedalus.goal).toBe("");
    expect(state.daedalus.contextHint).toBe("");
    expect(state.daedalus.loading).toBe(false);
    expect(state.daedalus.error).toBe(null);
    expect(state.daedalus.result).toBe(null);
  });

  speed_profile("fast")("updates daedalus goal", () => {
    const { setDaedalusGoal } = useAgentStore.getState();
    
    setDaedalusGoal("Test goal");
    expect(useAgentStore.getState().daedalus.goal).toBe("Test goal");
  });

  speed_profile("fast")("updates daedalus context hint", () => {
    const { setDaedalusContextHint } = useAgentStore.getState();
    
    setDaedalusContextHint("Test hint");
    expect(useAgentStore.getState().daedalus.contextHint).toBe("Test hint");
  });

  speed_profile("fast")("resets daedalus state", () => {
    const { setDaedalusGoal, setDaedalusContextHint, resetDaedalus } = useAgentStore.getState();
    
    setDaedalusGoal("Test goal");
    setDaedalusContextHint("Test hint");
    
    resetDaedalus();
    
    const state = useAgentStore.getState();
    expect(state.daedalus.goal).toBe("");
    expect(state.daedalus.contextHint).toBe("");
  });

  speed_profile("fast")("initializes sisyphus state correctly", () => {
    const state = useAgentStore.getState();
    
    expect(state.sisyphus.planPath).toBe("");
    expect(state.sisyphus.dryRun).toBe(false);
    expect(state.sisyphus.approvalMode).toBe("autonomous");
    expect(state.sisyphus.executions).toEqual([]);
  });

  speed_profile("fast")("updates sisyphus plan path", () => {
    const { setPlanPath } = useAgentStore.getState();
    
    setPlanPath("/test/plan.md");
    expect(useAgentStore.getState().sisyphus.planPath).toBe("/test/plan.md");
  });

  speed_profile("fast")("updates sisyphus dry run mode", () => {
    const { setDryRun } = useAgentStore.getState();
    
    setDryRun(true);
    expect(useAgentStore.getState().sisyphus.dryRun).toBe(true);
    
    setDryRun(false);
    expect(useAgentStore.getState().sisyphus.dryRun).toBe(false);
  });

  speed_profile("fast")("updates sisyphus approval mode", () => {
    const { setApprovalMode } = useAgentStore.getState();
    
    setApprovalMode("step");
    expect(useAgentStore.getState().sisyphus.approvalMode).toBe("step");
    
    setApprovalMode("milestone");
    expect(useAgentStore.getState().sisyphus.approvalMode).toBe("milestone");
    
    setApprovalMode("autonomous");
    expect(useAgentStore.getState().sisyphus.approvalMode).toBe("autonomous");
  });

  speed_profile("fast")("resets all state", () => {
    const { 
      setMode, 
      setProjectPath, 
      setDaedalusGoal, 
      setPlanPath, 
      setDryRun, 
      reset 
    } = useAgentStore.getState();
    
    // Set some state
    setMode("sisyphus");
    setProjectPath("/test/path");
    setDaedalusGoal("Test goal");
    setPlanPath("/test/plan.md");
    setDryRun(true);
    
    // Reset
    reset();
    
    const state = useAgentStore.getState();
    expect(state.mode).toBe("daedalus");
    expect(state.projectPath).toBe("");
    expect(state.daedalus.goal).toBe("");
    expect(state.sisyphus.planPath).toBe("");
    expect(state.sisyphus.dryRun).toBe(false);
  });

  speed_profile("fast")("adds execution to sisyphus executions list", () => {
    const { addExecution } = useAgentStore.getState();
    
    const execution = {
      execution_id: "test-123",
      status: "running",
    };
    
    addExecution(execution);
    
    const state = useAgentStore.getState();
    expect(state.sisyphus.executions).toHaveLength(1);
    expect(state.sisyphus.executions[0].execution_id).toBe("test-123");
  });

  speed_profile("fast")("clears approval state", () => {
    // Manually set approval state
    const state = useAgentStore.getState();
    state.sisyphus.pendingApproval = { id: "test" };
    state.sisyphus.approvalError = "Test error";
    
    const { clearApproval } = useAgentStore.getState();
    clearApproval();
    
    const updatedState = useAgentStore.getState();
    expect(updatedState.sisyphus.pendingApproval).toBe(null);
    expect(updatedState.sisyphus.approvalError).toBe("");
  });
});

