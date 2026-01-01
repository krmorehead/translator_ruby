import { describe, expect, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { speed_profile } from "../../test/speedProfile";
import ProjectPlanPage from "../ProjectPlanPage";
import { useProjectPlanStore } from "../../store/projectPlanStore";

describe("ProjectPlanPage", () => {
  beforeEach(() => {
    useProjectPlanStore.getState().reset();
  });

  afterEach(() => {
    useProjectPlanStore.getState().reset();
  });

  speed_profile("fast")("renders the form with all required elements", () => {
    render(<ProjectPlanPage />);

    expect(screen.getByLabelText(/project goal/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/codebase path/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/project name/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /generate plan/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /reset/i })).toBeInTheDocument();
  });

  speed_profile("fast")("updates store state when inputs change", () => {
    render(<ProjectPlanPage />);

    const goalInput = screen.getByLabelText(/project goal/i);
    const pathInput = screen.getByLabelText(/codebase path/i);
    const projectNameInput = screen.getByLabelText(/project name/i);

    fireEvent.change(goalInput, { target: { value: "Test goal" } });
    fireEvent.change(pathInput, { target: { value: "/test/path" } });
    fireEvent.change(projectNameInput, { target: { value: "test_project" } });

    const state = useProjectPlanStore.getState();
    expect(state.goal).toBe("Test goal");
    expect(state.path).toBe("/test/path");
    expect(state.projectName).toBe("test_project");
  });

  speed_profile("fast")("disables submit button when required fields are empty", () => {
    render(<ProjectPlanPage />);

    const submitButton = screen.getByRole("button", { name: /generate plan/i });
    expect(submitButton).toBeDisabled();
  });

  speed_profile("fast")("enables submit button when all fields are filled", () => {
    render(<ProjectPlanPage />);

    const goalInput = screen.getByLabelText(/project goal/i);
    const pathInput = screen.getByLabelText(/codebase path/i);
    const projectNameInput = screen.getByLabelText(/project name/i);

    fireEvent.change(goalInput, { target: { value: "Test goal" } });
    fireEvent.change(pathInput, { target: { value: "/test/path" } });
    fireEvent.change(projectNameInput, { target: { value: "test_project" } });

    const submitButton = screen.getByRole("button", { name: /generate plan/i });
    expect(submitButton).not.toBeDisabled();
  });

  speed_profile("fast")("disables submit button when loading", () => {
    useProjectPlanStore.setState({ 
      loading: true, 
      goal: "Test", 
      path: "/path",
      projectName: "test"
    });

    render(<ProjectPlanPage />);

    const submitButton = screen.getByRole("button", { name: /planning/i });
    expect(submitButton).toBeDisabled();
  });

  speed_profile("fast")("displays error message when error exists", () => {
    useProjectPlanStore.setState({ error: "Test error message" });

    render(<ProjectPlanPage />);

    expect(screen.getByText(/test error message/i)).toBeInTheDocument();
  });

  speed_profile("fast")("calls reset action", () => {
    useProjectPlanStore.setState({
      goal: "Test goal",
      path: "/test/path",
      projectName: "test",
      error: "Some error"
    });

    render(<ProjectPlanPage />);

    const resetButton = screen.getByRole("button", { name: /reset/i });
    fireEvent.click(resetButton);

    const state = useProjectPlanStore.getState();
    expect(state.goal).toBe("");
    expect(state.path).toBe("");
    expect(state.projectName).toBe("");
    expect(state.error).toBe("");
  });
});
