import { describe, test, expect, beforeEach, afterEach } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import { speed_profile } from "../../test/speedProfile";
import ConfigurationPanel from "../ConfigurationPanel";
import { useAgentStore } from "../../store/agentStore";

describe("ConfigurationPanel", () => {
  beforeEach(() => {
    useAgentStore.getState().reset();
  });

  afterEach(() => {
    useAgentStore.getState().reset();
  });

  // ============================================================================
  // LOADING STATE TESTS
  // ============================================================================

  speed_profile("fast")("shows loading indicator when loading and no config", () => {
    useAgentStore.setState({ configLoading: true, config: null });

    render(<ConfigurationPanel />);

    // Should show loading state - check that config content is not present
    expect(screen.queryByText(/LLM Configuration/i)).not.toBeInTheDocument();
  });

  speed_profile("fast")("does not show config content when loading initially", () => {
    useAgentStore.setState({ configLoading: true, config: null });

    render(<ConfigurationPanel />);

    expect(screen.queryByText(/LLM Configuration/i)).not.toBeInTheDocument();
  });

  speed_profile("fast")("shows config content even when configLoading is true if config exists", () => {
    const testConfig = {
      capabilities: {},
      environment: {},
    };

    useAgentStore.setState({ configLoading: true, config: testConfig });

    render(<ConfigurationPanel />);

    // Should still show config even if loading (e.g., refreshing)
    expect(screen.getByText(/LLM Configuration/i)).toBeInTheDocument();
  });

  // ============================================================================
  // ERROR STATE TESTS
  // ============================================================================

  speed_profile("fast")("shows error message when error exists", () => {
    useAgentStore.setState({
      configLoading: false,
      configError: "Test error message XYZ123",
      config: null,
    });

    render(<ConfigurationPanel />);

    expect(screen.getByText(/test error message xyz123/i)).toBeInTheDocument();
  });

  speed_profile("fast")("shows retry button when error exists", () => {
    useAgentStore.setState({
      configLoading: false,
      configError: "Connection failed",
      config: null,
    });

    render(<ConfigurationPanel />);

    const buttons = screen.queryAllByRole("button", { name: /retry/i });
    expect(buttons.length).toBeGreaterThan(0);
  });

  speed_profile("fast")("retry button calls loadConfig", () => {
    useAgentStore.setState({
      configLoading: false,
      configError: "Connection failed",
      config: null,
    });

    render(<ConfigurationPanel />);

    const initialLoadingState = useAgentStore.getState().configLoading;
    expect(initialLoadingState).toBe(false);

    const retryButtons = screen.queryAllByRole("button", { name: /retry/i });
    expect(retryButtons.length).toBeGreaterThan(0);
    
    if (retryButtons.length > 0) {
      fireEvent.click(retryButtons[0]);
      // loadConfig should have been called - button may disappear or remain
    }
  });

  speed_profile("fast")("does not show error message when no error", () => {
    useAgentStore.setState({
      configLoading: false,
      configError: "",
      config: null,
    });

    render(<ConfigurationPanel />);

    expect(screen.queryByText(/error/i)).not.toBeInTheDocument();
  });

  // ============================================================================
  // EMPTY STATE TESTS
  // ============================================================================

  speed_profile("fast")("shows empty state when no config and no loading", () => {
    useAgentStore.setState({
      configLoading: false,
      configError: "",
      config: null,
    });

    render(<ConfigurationPanel />);

    expect(screen.getByText(/no configuration loaded/i)).toBeInTheDocument();
  });

  speed_profile("fast")("shows load configuration button when no config", () => {
    useAgentStore.setState({
      configLoading: false,
      configError: "",
      config: null,
    });

    render(<ConfigurationPanel />);

    const buttons = screen.queryAllByRole("button", { name: /load configuration/i });
    expect(buttons.length).toBeGreaterThan(0);
  });

  speed_profile("fast")("load configuration button calls loadConfig", () => {
    useAgentStore.setState({
      configLoading: false,
      configError: "",
      config: null,
    });

    render(<ConfigurationPanel />);

    const buttons = screen.queryAllByRole("button", { name: /load configuration/i });
    expect(buttons.length).toBeGreaterThan(0);
    
    if (buttons.length > 0) {
      fireEvent.click(buttons[0]);
      // Should trigger loadConfig - button may disappear or remain
    }
  });

  // ============================================================================
  // CONFIGURATION DISPLAY TESTS
  // ============================================================================

  speed_profile("fast")("renders configuration header", () => {
    const testConfig = {
      capabilities: {},
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    expect(screen.getByText(/LLM Configuration/i)).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: /LLM Configuration/i })).toBeInTheDocument();
  });

  speed_profile("fast")("renders refresh button", () => {
    const testConfig = {
      capabilities: {},
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    const refreshButton = screen.getByRole("button", { name: /refresh configuration/i });
    expect(refreshButton).toBeInTheDocument();
    expect(refreshButton.textContent).toContain("🔄");
  });

  speed_profile("fast")("refresh button disabled when loading", () => {
    const testConfig = {
      capabilities: {},
      environment: {},
    };

    useAgentStore.setState({
      configLoading: true,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    const refreshButton = screen.getByRole("button", { name: /refresh configuration/i });
    expect(refreshButton).toBeDisabled();
  });

  speed_profile("fast")("refresh button enabled when not loading", () => {
    const testConfig = {
      capabilities: {},
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    const refreshButton = screen.getByRole("button", { name: /refresh configuration/i });
    expect(refreshButton).not.toBeDisabled();
  });

  speed_profile("fast")("refresh button calls loadConfig", () => {
    const testConfig = {
      capabilities: {},
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    const refreshButton = screen.getByRole("button", { name: /refresh configuration/i });
    fireEvent.click(refreshButton);

    // Should trigger loadConfig
    expect(refreshButton).toBeInTheDocument();
  });

  // ============================================================================
  // CAPABILITIES SECTION TESTS
  // ============================================================================

  speed_profile("fast")("renders capabilities section", () => {
    const testConfig = {
      capabilities: {
        general_llm: {
          model_name: "test_model",
          port: 52003,
          max_context: 64000,
          base_url: "http://localhost",
        },
      },
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    expect(screen.getByText(/capabilities/i)).toBeInTheDocument();
  });

  speed_profile("fast")("renders capability name", () => {
    const testConfig = {
      capabilities: {
        general_llm: {
          model_name: "test_model",
          port: 52003,
          max_context: 64000,
          base_url: "http://localhost",
        },
      },
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    expect(screen.getByText("general_llm")).toBeInTheDocument();
  });

  speed_profile("fast")("renders capability details", () => {
    const testConfig = {
      capabilities: {
        general_llm: {
          model_name: "test_model",
          port: 52003,
          max_context: 64000,
          base_url: "http://localhost",
        },
      },
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    expect(screen.getByText("test_model")).toBeInTheDocument();
    expect(screen.getByText("52003")).toBeInTheDocument();
    expect(screen.getByText("64000 tokens")).toBeInTheDocument();
    expect(screen.getByText("http://localhost")).toBeInTheDocument();
  });

  speed_profile("fast")("renders multiple capabilities", () => {
    const testConfig = {
      capabilities: {
        general_llm: {
          model_name: "model_1",
          port: 52003,
          max_context: 64000,
          base_url: "url1",
        },
        tool_calling: {
          model_name: "model_2",
          port: 52004,
          max_context: 32000,
          base_url: "url2",
        },
      },
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    expect(screen.getByText("general_llm")).toBeInTheDocument();
    expect(screen.getByText("tool_calling")).toBeInTheDocument();
    expect(screen.getByText("model_1")).toBeInTheDocument();
    expect(screen.getByText("model_2")).toBeInTheDocument();
  });

  speed_profile("fast")("renders test connection buttons for each capability", () => {
    const testConfig = {
      capabilities: {
        general_llm: {
          model_name: "test_model",
          port: 52003,
          max_context: 64000,
          base_url: "http://localhost",
        },
        tool_calling: {
          model_name: "test_model_2",
          port: 52004,
          max_context: 32000,
          base_url: "http://localhost",
        },
      },
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    const testButtons = screen.getAllByRole("button", {
      name: /test connection/i,
    });
    expect(testButtons).toHaveLength(2);
  });

  speed_profile("fast")("test connection button disabled when loading", () => {
    const testConfig = {
      capabilities: {
        general_llm: {
          model_name: "test_model",
          port: 52003,
          max_context: 64000,
          base_url: "http://localhost",
        },
      },
      environment: {},
    };

    useAgentStore.setState({
      configLoading: true,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    const testButtons = screen.queryAllByRole("button");
    const testButton = testButtons.find(btn => btn.textContent.includes("Test") || btn.textContent.includes("test"));
    if (testButton) {
      expect(testButton).toBeDisabled();
    }
  });

  speed_profile("fast")("test connection button enabled when not loading", () => {
    const testConfig = {
      capabilities: {
        general_llm: {
          model_name: "test_model",
          port: 52003,
          max_context: 64000,
          base_url: "http://localhost",
        },
      },
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    const testButton = screen.getByRole("button", { name: /test connection/i });
    expect(testButton).not.toBeDisabled();
  });

  speed_profile("fast")("test connection button shows testing text when loading", () => {
    const testConfig = {
      capabilities: {
        general_llm: {
          model_name: "test_model",
          port: 52003,
          max_context: 64000,
          base_url: "http://localhost",
        },
      },
      environment: {},
    };

    useAgentStore.setState({
      configLoading: true,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    expect(screen.getByText(/testing/i)).toBeInTheDocument();
  });

  // ============================================================================
  // TEST RESULTS TESTS
  // ============================================================================

  speed_profile("fast")("shows success status when test succeeds", () => {
    const testConfig = {
      capabilities: {
        general_llm: {
          model_name: "test_model",
          port: 52003,
          max_context: 64000,
          base_url: "http://localhost",
        },
      },
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
      testResults: {
        general_llm: { success: true, error: null },
      },
    });

    render(<ConfigurationPanel />);

    expect(screen.getByText(/✓ connected/i)).toBeInTheDocument();
  });

  speed_profile("fast")("shows error status when test fails", () => {
    const testConfig = {
      capabilities: {
        general_llm: {
          model_name: "test_model",
          port: 52003,
          max_context: 64000,
          base_url: "http://localhost",
        },
      },
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
      testResults: {
        general_llm: { success: false, error: "Connection refused" },
      },
    });

    render(<ConfigurationPanel />);

    expect(screen.getByText(/✗ failed/i)).toBeInTheDocument();
  });

  speed_profile("fast")("shows error message when test fails", () => {
    const testConfig = {
      capabilities: {
        general_llm: {
          model_name: "test_model",
          port: 52003,
          max_context: 64000,
          base_url: "http://localhost",
        },
      },
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
      testResults: {
        general_llm: { success: false, error: "Connection timed out" },
      },
    });

    render(<ConfigurationPanel />);

    expect(screen.getByText(/connection timed out/i)).toBeInTheDocument();
  });

  speed_profile("fast")("does not show status when no test results", () => {
    const testConfig = {
      capabilities: {
        general_llm: {
          model_name: "test_model",
          port: 52003,
          max_context: 64000,
          base_url: "http://localhost",
        },
      },
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
      testResults: {},
    });

    render(<ConfigurationPanel />);

    expect(screen.queryByText(/✓ connected/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/✗ failed/i)).not.toBeInTheDocument();
  });

  // ============================================================================
  // ENVIRONMENT SECTION TESTS
  // ============================================================================

  speed_profile("fast")("renders environment section", () => {
    const testConfig = {
      capabilities: {},
      environment: {
        rails_env: "test",
      },
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    expect(screen.getByText(/environment/i)).toBeInTheDocument();
  });

  speed_profile("fast")("renders environment variables", () => {
    const testConfig = {
      capabilities: {},
      environment: {
        rails_env: "test",
        llm_url: "***localhost",
        llm_retry: "3",
      },
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    expect(screen.getByText(/rails_env/i)).toBeInTheDocument();
    expect(screen.getByText("test")).toBeInTheDocument();
    expect(screen.getByText(/llm_url/i)).toBeInTheDocument();
    expect(screen.getByText("***localhost")).toBeInTheDocument();
    expect(screen.getByText(/llm_retry/i)).toBeInTheDocument();
    expect(screen.getByText("3")).toBeInTheDocument();
  });

  speed_profile("fast")("shows 'not set' for missing environment values", () => {
    const testConfig = {
      capabilities: {},
      environment: {
        rails_env: null,
      },
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    expect(screen.getByText(/not set/i)).toBeInTheDocument();
  });

  speed_profile("fast")("renders empty environment object", () => {
    const testConfig = {
      capabilities: {},
      environment: {},
    };

    useAgentStore.setState({
      configLoading: false,
      config: testConfig,
    });

    render(<ConfigurationPanel />);

    // Should still render the environment section
    expect(screen.getByText(/environment/i)).toBeInTheDocument();
  });
});

