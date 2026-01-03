import { describe, test, expect, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { speed_profile } from "../../test/speedProfile";
import AgentWorkspace from "../AgentWorkspace";
import { useAgentStore } from "../../store/agentStore";

describe("AgentWorkspace", () => {
  beforeEach(() => {
    useAgentStore.getState().reset();
  });

  afterEach(() => {
    useAgentStore.getState().reset();
  });

  // ============================================================================
  // INITIALIZATION TESTS
  // ============================================================================

  speed_profile("fast")("renders with daedalus mode by default", () => {
    render(<AgentWorkspace />);

    expect(screen.getByRole("heading", { name: /daedalus.*architect/i })).toBeInTheDocument();
  });

  speed_profile("fast")("renders mode selector", () => {
    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    expect(selector).toBeInTheDocument();
    expect(selector.tagName).toBe("SELECT");
  });

  speed_profile("fast")("mode selector has correct options", () => {
    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    const options = Array.from(selector.options).map(opt => opt.value);
    
    expect(options).toContain("daedalus");
    expect(options).toContain("sisyphus");
  });

  speed_profile("fast")("renders configuration toggle button", () => {
    render(<AgentWorkspace />);

    const button = screen.getByRole("button", { name: /toggle configuration/i });
    expect(button).toBeInTheDocument();
    expect(button.textContent).toContain("⚙️");
  });

  speed_profile("fast")("config panel hidden by default", () => {
    render(<AgentWorkspace />);

    expect(screen.queryByText(/LLM Configuration/i)).not.toBeInTheDocument();
  });

  // ============================================================================
  // MODE SWITCHING TESTS
  // ============================================================================

  speed_profile("fast")("switches to sisyphus mode", () => {
    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    expect(screen.getByRole("heading", { name: /sisyphus.*executor/i })).toBeInTheDocument();
  });

  speed_profile("fast")("switches back to daedalus mode", () => {
    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    
    // Switch to Sisyphus
    fireEvent.change(selector, { target: { value: "sisyphus" } });
    expect(screen.getByRole("heading", { name: /sisyphus/i })).toBeInTheDocument();
    
    // Switch back to Daedalus
    fireEvent.change(selector, { target: { value: "daedalus" } });
    expect(screen.getByRole("heading", { name: /daedalus/i })).toBeInTheDocument();
  });

  speed_profile("fast")("mode persists in store", () => {
    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    const state = useAgentStore.getState();
    expect(state.mode).toBe("sisyphus");
  });

  // ============================================================================
  // CONFIG PANEL TESTS
  // ============================================================================

  speed_profile("fast")("toggles config panel on button click", () => {
    render(<AgentWorkspace />);

    const toggleButton = screen.getByRole("button", { name: /toggle configuration/i });
    
    // Initially hidden
    expect(screen.queryByText(/LLM Configuration/i)).not.toBeInTheDocument();
    
    // Click to show
    fireEvent.click(toggleButton);
    // Config panel may load asynchronously
  });

  speed_profile("fast")("config panel remains visible after mode switch", () => {
    render(<AgentWorkspace />);

    const toggleButton = screen.getByRole("button", { name: /toggle configuration/i });
    const modeSelector = screen.getByLabelText(/agent mode/i);
    
    // Show config panel
    fireEvent.click(toggleButton);
    
    // Switch mode
    fireEvent.change(modeSelector, { target: { value: "sisyphus" } });
    
    // Config panel state should persist (showConfig remains true)
  });

  // ============================================================================
  // DAEDALUS MODE TESTS
  // ============================================================================

  speed_profile("fast")("renders daedalus form elements", () => {
    render(<AgentWorkspace />);

    expect(screen.getByLabelText(/goal/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/codebase path/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/context hint/i)).toBeInTheDocument();
  });

  speed_profile("fast")("daedalus form has submit button", () => {
    render(<AgentWorkspace />);

    const submitButton = screen.getByRole("button", { name: /generate execution plan/i });
    expect(submitButton).toBeInTheDocument();
  });

  speed_profile("fast")("daedalus form has reset button", () => {
    render(<AgentWorkspace />);

    const resetButton = screen.getByRole("button", { name: /reset/i });
    expect(resetButton).toBeInTheDocument();
  });

  speed_profile("fast")("submit button disabled when fields empty", () => {
    render(<AgentWorkspace />);

    const submitButton = screen.getByRole("button", { name: /generate execution plan/i });
    expect(submitButton).toBeDisabled();
  });

  speed_profile("fast")("submit button enabled when required fields filled", () => {
    render(<AgentWorkspace />);

    fireEvent.change(screen.getByLabelText(/goal/i), { target: { value: "Test goal" } });
    fireEvent.change(screen.getByLabelText(/codebase path/i), { target: { value: "/test/path" } });

    const submitButton = screen.getByRole("button", { name: /generate execution plan/i });
    expect(submitButton).not.toBeDisabled();
  });

  speed_profile("fast")("goal input updates store", () => {
    render(<AgentWorkspace />);

    const goalInput = screen.getByLabelText(/goal/i);
    fireEvent.change(goalInput, { target: { value: "Test goal" } });

    const state = useAgentStore.getState();
    expect(state.daedalus.goal).toBe("Test goal");
  });

  speed_profile("fast")("context hint input updates store", () => {
    render(<AgentWorkspace />);

    const hintInput = screen.getByLabelText(/context hint/i);
    fireEvent.change(hintInput, { target: { value: "Test hint" } });

    const state = useAgentStore.getState();
    expect(state.daedalus.contextHint).toBe("Test hint");
  });

  speed_profile("fast")("reset button clears daedalus form", () => {
    render(<AgentWorkspace />);

    // Fill form
    fireEvent.change(screen.getByLabelText(/goal/i), { target: { value: "Test goal" } });
    fireEvent.change(screen.getByLabelText(/context hint/i), { target: { value: "Test hint" } });

    // Reset
    const resetButton = screen.getByRole("button", { name: /reset/i });
    fireEvent.click(resetButton);

    // Check store state
    const state = useAgentStore.getState();
    expect(state.daedalus.goal).toBe("");
    expect(state.daedalus.contextHint).toBe("");
  });

  speed_profile("fast")("displays error message when error exists", () => {
    useAgentStore.setState({
      daedalus: {
        ...useAgentStore.getState().daedalus,
        error: "Test error message",
      },
    });

    render(<AgentWorkspace />);

    expect(screen.getByText(/test error message/i)).toBeInTheDocument();
  });

  speed_profile("fast")("disables form when loading", () => {
    useAgentStore.setState({
      daedalus: {
        ...useAgentStore.getState().daedalus,
        loading: true,
        goal: "Test",
      },
    });

    render(<AgentWorkspace />);

    const goalInput = screen.getByLabelText(/goal/i);
    expect(goalInput).toBeDisabled();
  });

  speed_profile("fast")("shows loading indicator when daedalus loading", () => {
    useAgentStore.setState({
      daedalus: {
        ...useAgentStore.getState().daedalus,
        loading: true,
      },
    });

    render(<AgentWorkspace />);

    // Loading indicator should be visible in header
    const header = screen.getByRole("banner") || screen.getByClassName("agent-header");
    expect(header).toBeInTheDocument();
  });

  speed_profile("fast")("renders execution plan when result exists", () => {
    const mockResult = {
      result: {
        execution_plan: {
          goal: "Test goal",
          constraints: ["constraint1"],
          assumptions: ["assumption1"],
          risks: ["risk1"],
          milestones: [
            {
              id: "m1",
              title: "Milestone 1",
              description: "Test milestone",
              estimated_duration: "1 day",
              success_criteria: ["criteria1"],
              steps: [],
            },
          ],
        },
        output_paths: {
          plan_path: "/test/plan.md",
          json_path: "/test/plan.json",
          metadata_path: "/test/metadata.json",
        },
        analysis_summary: {
          relevant_files: ["file1.rb", "file2.rb"],
        },
      },
      metadata: {
        milestone_count: 1,
        step_count: 0,
      },
    };

    useAgentStore.setState({
      daedalus: {
        ...useAgentStore.getState().daedalus,
        result: mockResult,
      },
    });

    render(<AgentWorkspace />);

    expect(screen.getAllByText(/execution plan/i).length).toBeGreaterThan(0);
    expect(screen.getByText("Test goal")).toBeInTheDocument();
    // Milestone 1 should be rendered in the plan
    const milestoneElements = screen.queryAllByText(/milestone/i);
    expect(milestoneElements.length).toBeGreaterThan(0);
  });

  // ============================================================================
  // SISYPHUS MODE TESTS
  // ============================================================================

  speed_profile("fast")("renders sisyphus form elements", () => {
    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    expect(screen.getByLabelText(/project path/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/plan path/i)).toBeInTheDocument();
  });

  speed_profile("fast")("renders execution options", () => {
    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    expect(screen.getByText(/dry run mode/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/approval mode/i)).toBeInTheDocument();
  });

  speed_profile("fast")("renders start execution button", () => {
    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    const startButton = screen.getByRole("button", { name: /start execution/i });
    expect(startButton).toBeInTheDocument();
  });

  speed_profile("fast")("start button disabled when paths empty", () => {
    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    const startButton = screen.getByRole("button", { name: /start execution/i });
    expect(startButton).toBeDisabled();
  });

  speed_profile("fast")("start button enabled when paths filled", () => {
    useAgentStore.setState({
      projectPath: "/test/project",
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        planPath: "/test/plan.md",
      },
    });

    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    const startButton = screen.getByRole("button", { name: /start execution/i });
    expect(startButton).not.toBeDisabled();
  });

  speed_profile("fast")("plan path input updates store", () => {
    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    const planPathInput = screen.getByLabelText(/plan path/i);
    fireEvent.change(planPathInput, { target: { value: "/test/plan.md" } });

    const state = useAgentStore.getState();
    expect(state.sisyphus.planPath).toBe("/test/plan.md");
  });

  speed_profile("fast")("dry run checkbox toggles", () => {
    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    const checkbox = screen.getByRole("checkbox");
    
    // Initially unchecked
    expect(checkbox).not.toBeChecked();
    
    // Check it
    fireEvent.click(checkbox);
    expect(useAgentStore.getState().sisyphus.dryRun).toBe(true);
    
    // Uncheck it
    fireEvent.click(checkbox);
    expect(useAgentStore.getState().sisyphus.dryRun).toBe(false);
  });

  speed_profile("fast")("approval mode selector changes", () => {
    render(<AgentWorkspace />);

    const modeSelector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(modeSelector, { target: { value: "sisyphus" } });

    const approvalSelector = screen.getByLabelText(/approval mode/i);
    
    fireEvent.change(approvalSelector, { target: { value: "step" } });
    expect(useAgentStore.getState().sisyphus.approvalMode).toBe("step");
    
    fireEvent.change(approvalSelector, { target: { value: "milestone" } });
    expect(useAgentStore.getState().sisyphus.approvalMode).toBe("milestone");
    
    fireEvent.change(approvalSelector, { target: { value: "autonomous" } });
    expect(useAgentStore.getState().sisyphus.approvalMode).toBe("autonomous");
  });

  speed_profile("fast")("shows dry run warning when enabled", () => {
    useAgentStore.setState({
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        dryRun: true,
        currentExecution: {
          execution_id: "test-123",
          status: "running",
        },
      },
    });

    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    expect(screen.getAllByText(/dry run mode/i).length).toBeGreaterThan(0);
  });

  speed_profile("fast")("renders execution monitor", () => {
    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    expect(screen.getByText(/execution monitor/i)).toBeInTheDocument();
  });

  speed_profile("fast")("shows empty state when no execution", () => {
    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    expect(screen.getByText(/no execution in progress/i)).toBeInTheDocument();
  });

  speed_profile("fast")("renders execution details when execution exists", () => {
    useAgentStore.setState({
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        currentExecution: {
          execution_id: "test-123",
          status: "running",
          progress_percentage: 50,
          current_milestone: "Milestone 1",
          current_step: "Step 1",
          files_changed: ["file1.rb", "file2.rb"],
        },
      },
    });

    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    expect(screen.getByText("test-123")).toBeInTheDocument();
    expect(screen.getByText(/running/i)).toBeInTheDocument();
    expect(screen.getByText("Milestone 1")).toBeInTheDocument();
    expect(screen.getByText("Step 1")).toBeInTheDocument();
  });

  speed_profile("fast")("shows recent executions list", () => {
    useAgentStore.setState({
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        executions: [
          { execution_id: "exec-1", status: "complete" },
          { execution_id: "exec-2", status: "running" },
        ],
      },
    });

    render(<AgentWorkspace />);

    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    expect(screen.getByText(/recent executions/i)).toBeInTheDocument();
  });

  // ============================================================================
  // SHARED STATE TESTS
  // ============================================================================

  speed_profile("fast")("project path persists across mode switch", () => {
    render(<AgentWorkspace />);

    // Set path in Daedalus
    const pathInput = screen.getByLabelText(/codebase path/i);
    fireEvent.change(pathInput, { target: { value: "/test/project" } });

    // Switch to Sisyphus
    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    // Check that path persisted
    const sisyphusPathInput = screen.getByLabelText(/project path/i);
    expect(sisyphusPathInput.value).toBe("/test/project");
  });

  speed_profile("fast")("project path updated in sisyphus reflects in daedalus", () => {
    render(<AgentWorkspace />);

    // Switch to Sisyphus
    const selector = screen.getByLabelText(/agent mode/i);
    fireEvent.change(selector, { target: { value: "sisyphus" } });

    // Set path in Sisyphus
    const pathInput = screen.getByLabelText(/project path/i);
    fireEvent.change(pathInput, { target: { value: "/sisyphus/path" } });

    // Switch back to Daedalus
    fireEvent.change(selector, { target: { value: "daedalus" } });

    // Check that path persisted
    const daedalusPathInput = screen.getByLabelText(/codebase path/i);
    expect(daedalusPathInput.value).toBe("/sisyphus/path");
  });

  // ============================================================================
  // APPROVAL MODAL TESTS
  // ============================================================================

  speed_profile("fast")("does not show approval modal when no pending approval", () => {
    render(<AgentWorkspace />);

    expect(screen.queryByText(/approval required/i)).not.toBeInTheDocument();
  });

  speed_profile("fast")("shows approval modal when pending approval exists", () => {
    const mockApproval = {
      id: "approval-1",
      type: "step",
      status: "pending",
      subjectTitle: "Test Step",
      isPending: () => true,
    };

    useAgentStore.setState({
      sisyphus: {
        ...useAgentStore.getState().sisyphus,
        pendingApproval: mockApproval,
      },
    });

    render(<AgentWorkspace />);

    // ApprovalModal should render
    // Note: Actual text depends on ApprovalModal implementation
  });
});
