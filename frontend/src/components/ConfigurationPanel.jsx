import { useAgentStore } from "../store/agentStore";
import LoadingIndicator from "./LoadingIndicator";

// ConfigurationPanel component - displays and manages LLM configuration
// Follows OOP principles with strict separation of concerns
function ConfigurationPanel() {
  const config = useAgentStore((state) => state.config);
  const configLoading = useAgentStore((state) => state.configLoading);
  const configError = useAgentStore((state) => state.configError);
  const testResults = useAgentStore((state) => state.testResults);
  const testConnection = useAgentStore((state) => state.testConnection);
  const loadConfig = useAgentStore((state) => state.loadConfig);

  const handleTestConnection = async (capabilityName) => {
    try {
      await testConnection(capabilityName);
    } catch (error) {
      console.error("Connection test failed:", error);
    }
  };

  const handleRefreshConfig = () => {
    loadConfig();
  };

  if (configLoading && !config) {
    return (
      <div className="configuration-panel">
        <LoadingIndicator />
      </div>
    );
  }

  if (configError) {
    return (
      <div className="configuration-panel">
        <div className="config-error">
          <strong>Error:</strong> {configError}
        </div>
        <button onClick={handleRefreshConfig} className="btn-secondary">
          Retry
        </button>
      </div>
    );
  }

  if (!config) {
    return (
      <div className="configuration-panel">
        <div className="config-empty">No configuration loaded</div>
        <button onClick={handleRefreshConfig} className="btn-primary">
          Load Configuration
        </button>
      </div>
    );
  }

  return (
    <div className="configuration-panel">
      <div className="config-header">
        <h3>LLM Configuration</h3>
        <button
          onClick={handleRefreshConfig}
          className="btn-icon"
          disabled={configLoading}
          aria-label="Refresh configuration"
        >
          🔄
        </button>
      </div>

      {/* LLM Capabilities */}
      <div className="config-section">
        <h4>Capabilities</h4>
        {Object.entries(config.capabilities).map(([name, capability]) => {
          const testResult = testResults[name];
          return (
            <div key={name} className="capability-card">
              <div className="capability-header">
                <strong>{name}</strong>
                {testResult && (
                  <span
                    className={`capability-status ${
                      testResult.success ? "status-success" : "status-error"
                    }`}
                  >
                    {testResult.success ? "✓ Connected" : "✗ Failed"}
                  </span>
                )}
              </div>
              <div className="capability-details">
                <div>
                  <label>Model:</label>
                  <span>{capability.model_name}</span>
                </div>
                <div>
                  <label>Port:</label>
                  <span>{capability.port}</span>
                </div>
                <div>
                  <label>Max Context:</label>
                  <span>{capability.max_context} tokens</span>
                </div>
                <div>
                  <label>Base URL:</label>
                  <span>{capability.base_url}</span>
                </div>
              </div>
              <button
                onClick={() => handleTestConnection(name)}
                disabled={configLoading}
                className="btn-secondary btn-small"
              >
                {configLoading ? "Testing..." : "Test Connection"}
              </button>
              {testResult && !testResult.success && (
                <div className="capability-error">
                  <strong>Error:</strong> {testResult.error}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Environment Variables */}
      <div className="config-section">
        <h4>Environment</h4>
        <div className="environment-details">
          {Object.entries(config.environment).map(([key, value]) => (
            <div key={key} className="environment-item">
              <label>{key}:</label>
              <span>{value || "not set"}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default ConfigurationPanel;








