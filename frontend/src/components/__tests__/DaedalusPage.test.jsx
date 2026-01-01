import { describe, expect, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { speed_profile } from "../../test/speedProfile";
import DaedalusPage from "../DaedalusPage";
import { useDaedalusStore } from "../../store/daedalusStore";

describe("DaedalusPage", () => {
  beforeEach(() => {
    useDaedalusStore.getState().reset();
  });

  afterEach(() => {
    useDaedalusStore.getState().reset();
  });

  speed_profile("fast")("renders the form with all required elements", () => {
    render(<DaedalusPage />);

    expect(screen.getByLabelText(/goal/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/codebase path/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/context hint/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /generate execution plan/i })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /reset/i })).toBeInTheDocument();
  });

  speed_profile("fast")("updates store state when inputs change", () => {
    render(<DaedalusPage />);

    const goalInput = screen.getByLabelText(/goal/i);
    const pathInput = screen.getByLabelText(/codebase path/i);
    const contextInput = screen.getByLabelText(/context hint/i);

    fireEvent.change(goalInput, { target: { value: "Test goal" } });
    fireEvent.change(pathInput, { target: { value: "/test/path" } });
    fireEvent.change(contextInput, { target: { value: "Test hint" } });

    const state = useDaedalusStore.getState();
    expect(state.goal).toBe("Test goal");
    expect(state.path).toBe("/test/path");
    expect(state.contextHint).toBe("Test hint");
  });

  speed_profile("fast")("disables submit button when required fields are empty", () => {
    render(<DaedalusPage />);

    const submitButton = screen.getByRole("button", { name: /generate execution plan/i });
    expect(submitButton).toBeDisabled();
  });

  speed_profile("fast")("enables submit button when required fields are filled", () => {
    render(<DaedalusPage />);

    const goalInput = screen.getByLabelText(/goal/i);
    const pathInput = screen.getByLabelText(/codebase path/i);

    fireEvent.change(goalInput, { target: { value: "Test goal" } });
    fireEvent.change(pathInput, { target: { value: "/test/path" } });

    const submitButton = screen.getByRole("button", { name: /generate execution plan/i });
    expect(submitButton).not.toBeDisabled();
  });

  speed_profile("fast")("disables submit button when loading", () => {
    useDaedalusStore.setState({ loading: true, goal: "Test", path: "/path" });

    render(<DaedalusPage />);

    const submitButton = screen.getByRole("button", { name: /generating plan/i });
    expect(submitButton).toBeDisabled();
  });

  speed_profile("fast")("displays error message when error exists", () => {
    useDaedalusStore.setState({ error: "Test error message" });

    render(<DaedalusPage />);

    expect(screen.getByText(/test error message/i)).toBeInTheDocument();
  });

  speed_profile("fast")("calls reset action", () => {
    useDaedalusStore.setState({
      goal: "Test goal",
      path: "/test/path",
      error: "Some error"
    });

    render(<DaedalusPage />);

    const resetButton = screen.getByRole("button", { name: /reset/i });
    fireEvent.click(resetButton);

    const state = useDaedalusStore.getState();
    expect(state.goal).toBe("");
    expect(state.path).toBe("");
    expect(state.error).toBe(null);
  });
});
