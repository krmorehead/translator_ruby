import React from "react";
import { useSisyphusStore } from "../store/sisyphusStore";
import ApprovalModal from "./ApprovalModal";
import "./chat.css";

/**
 * SisyphusPage - Main interface for the Sisyphus Agent Worker.
 * 
 * Provides a multi-panel interface for:
 * - Selecting projects and plans
 * - Starting and monitoring executions
 * - Browsing files in the target project
 * - Viewing agent configuration
 * 
 * This is a minimal MVP implementation. Full component library
 * with presentational/container patterns will be added incrementally.
 */
function SisyphusPage() {
  const {
    // Execution state
    currentExecution,
    executionLoading,
    executionError,
    executions,

    // Project state
    projectPath,
    planPath,
    dryRun,
    approvalMode,
    setProjectPath,
    setPlanPath,
    setDryRun,
    setApprovalMode,

    // Actions
    startExecution,
    fetchExecutions,
    loadConfig,
    loadFileTree,

    // File browser state
    currentPath,
    fileTree,
    fileLoading,

    // Config state
    config,
    configLoading,

    // Approval state
    pendingApproval,
    approvalLoading,
    approvalError,
    fetchPendingApproval,
    approveRequest,
    rejectRequest,
    startApprovalPolling,
    stopApprovalPolling,
    clearApproval
  } = useSisyphusStore();

  const [initialized, setInitialized] = React.useState(false);

  // Initialize on mount
  React.useEffect(() => {
    if (!initialized) {
      fetchExecutions();
      loadConfig();
      setInitialized(true);
    }
  }, [initialized, fetchExecutions, loadConfig]);

  // Cleanup polling on unmount
  React.useEffect(() => {
    return () => {
      stopApprovalPolling();
    };
  }, [stopApprovalPolling]);

  const handleStartExecution = async () => {
    if (!planPath || !projectPath) {
      alert("Please specify both plan path and project path");
      return;
    }
    
    try {
      const options = {
        dry_run: dryRun,
        approval_mode: approvalMode
      };
      
      const result = await startExecution(planPath, projectPath, options);
      
      // Start polling for approval requests if execution started successfully
      // (only needed if approval mode is not autonomous)
      if (result && result.execution_id && approvalMode !== "autonomous") {
        startApprovalPolling(result.execution_id);
      }
    } catch (error) {
      console.error("Failed to start execution:", error);
      // Error is already set in store
    }
  };

  const handleApprove = async (requestId) => {
    try {
      await approveRequest(requestId);
    } catch (error) {
      console.error("Failed to approve:", error);
      alert(`Failed to approve: ${error.message}`);
    }
  };

  const handleReject = async (requestId) => {
    try {
      await rejectRequest(requestId);
    } catch (error) {
      console.error("Failed to reject:", error);
      alert(`Failed to reject: ${error.message}`);
    }
  };

  const handleCloseApprovalModal = () => {
    clearApproval();
  };

  const handleBrowseProject = async () => {
    if (!projectPath) {
      alert("Please specify a project path");
      return;
    }
    await loadFileTree(projectPath);
  };

  return (
    <div className="chat-page">
      <div className="chat-container">
        {/* Approval Modal */}
        {pendingApproval && (
          <ApprovalModal
            approval={pendingApproval}
            onApprove={handleApprove}
            onReject={handleReject}
            onClose={handleCloseApprovalModal}
            loading={approvalLoading}
          />
        )}

        {/* Header */}
        <div style={{ padding: "1rem", borderBottom: "1px solid #ccc" }}>
          <h1>Sisyphus Agent Worker</h1>
          <p style={{ color: "#666", fontSize: "0.9rem" }}>
            Autonomous execution agent for structured plans
          </p>
        </div>

        {/* Main Content - Three Column Layout */}
        <div style={{ display: "flex", height: "calc(100vh - 100px)" }}>
          {/* Left Panel: Project Selection & Execution */}
          <div style={{
            flex: "0 0 300px",
            borderRight: "1px solid #ccc",
            padding: "1rem",
            overflowY: "auto"
          }}>
            <h2 style={{ fontSize: "1.2rem", marginBottom: "1rem" }}>
              Project Setup
            </h2>

            {/* Project Path Input */}
            <div style={{ marginBottom: "1rem" }}>
              <label style={{ display: "block", marginBottom: "0.5rem", fontWeight: "bold" }}>
                Project Path
              </label>
              <input
                type="text"
                value={projectPath}
                onChange={(e) => setProjectPath(e.target.value)}
                placeholder="/path/to/project"
                style={{
                  width: "100%",
                  padding: "0.5rem",
                  border: "1px solid #ccc",
                  borderRadius: "4px"
                }}
              />
            </div>

            {/* Plan Path Input */}
            <div style={{ marginBottom: "1rem" }}>
              <label style={{ display: "block", marginBottom: "0.5rem", fontWeight: "bold" }}>
                Plan Path
              </label>
              <input
                type="text"
                value={planPath}
                onChange={(e) => setPlanPath(e.target.value)}
                placeholder="/path/to/plan.md"
                style={{
                  width: "100%",
                  padding: "0.5rem",
                  border: "1px solid #ccc",
                  borderRadius: "4px"
                }}
              />
            </div>

            {/* Execution Options */}
            <div style={{
              marginBottom: "1rem",
              padding: "1rem",
              background: "#f5f5f5",
              borderRadius: "4px",
              border: "1px solid #ddd"
            }}>
              <div style={{ fontWeight: "bold", marginBottom: "0.75rem", fontSize: "0.9rem" }}>
                Execution Options
              </div>

              {/* Dry Run Toggle */}
              <div style={{ marginBottom: "0.75rem" }}>
                <label style={{
                  display: "flex",
                  alignItems: "center",
                  cursor: "pointer",
                  fontSize: "0.9rem"
                }}>
                  <input
                    type="checkbox"
                    checked={dryRun}
                    onChange={(e) => setDryRun(e.target.checked)}
                    style={{ marginRight: "0.5rem", cursor: "pointer" }}
                  />
                  <span>
                    Dry Run Mode
                    {dryRun && (
                      <span style={{
                        marginLeft: "0.5rem",
                        padding: "0.125rem 0.5rem",
                        background: "#FF9800",
                        color: "white",
                        borderRadius: "8px",
                        fontSize: "0.7rem",
                        fontWeight: "bold"
                      }}>
                        PREVIEW ONLY
                      </span>
                    )}
                  </span>
                </label>
                <div style={{ fontSize: "0.75rem", color: "#666", marginLeft: "1.5rem", marginTop: "0.25rem" }}>
                  {dryRun ? "Changes will be simulated, not executed" : "Changes will be executed for real"}
                </div>
              </div>

              {/* Approval Mode Selector */}
              <div>
                <label style={{ display: "block", marginBottom: "0.5rem", fontSize: "0.9rem", fontWeight: "bold" }}>
                  Approval Mode
                </label>
                <select
                  value={approvalMode}
                  onChange={(e) => setApprovalMode(e.target.value)}
                  style={{
                    width: "100%",
                    padding: "0.5rem",
                    border: "1px solid #ccc",
                    borderRadius: "4px",
                    fontSize: "0.85rem",
                    cursor: "pointer"
                  }}
                >
                  <option value="autonomous">Autonomous (No approvals)</option>
                  <option value="step">Step (Approve each step)</option>
                  <option value="milestone">Milestone (Approve each milestone)</option>
                </select>
                <div style={{ fontSize: "0.75rem", color: "#666", marginTop: "0.25rem" }}>
                  {approvalMode === "autonomous" && "Execution runs automatically"}
                  {approvalMode === "step" && "You'll approve each individual step"}
                  {approvalMode === "milestone" && "You'll approve each milestone (group of steps)"}
                </div>
              </div>
            </div>

            {/* Action Buttons */}
            <div style={{ marginBottom: "1rem" }}>
              <button
                onClick={handleStartExecution}
                disabled={executionLoading || !planPath || !projectPath}
                style={{
                  width: "100%",
                  padding: "0.75rem",
                  marginBottom: "0.5rem",
                  background: "#4CAF50",
                  color: "white",
                  border: "none",
                  borderRadius: "4px",
                  cursor: "pointer",
                  fontWeight: "bold"
                }}
              >
                {executionLoading ? "Starting..." : "Start Execution"}
              </button>

              <button
                onClick={handleBrowseProject}
                disabled={fileLoading || !projectPath}
                style={{
                  width: "100%",
                  padding: "0.75rem",
                  background: "#2196F3",
                  color: "white",
                  border: "none",
                  borderRadius: "4px",
                  cursor: "pointer"
                }}
              >
                {fileLoading ? "Loading..." : "Browse Files"}
              </button>
            </div>

            {executionError && (
              <div style={{
                padding: "0.75rem",
                background: "#ffebee",
                color: "#c62828",
                borderRadius: "4px",
                marginBottom: "1rem",
                fontSize: "0.9rem"
              }}>
                {executionError}
              </div>
            )}

            {/* Recent Executions */}
            <div style={{ marginTop: "2rem" }}>
              <h3 style={{ fontSize: "1rem", marginBottom: "0.5rem" }}>
                Recent Executions
              </h3>
              {executions.length === 0 ? (
                <p style={{ color: "#666", fontSize: "0.9rem" }}>
                  No executions yet
                </p>
              ) : (
                <div style={{ fontSize: "0.85rem" }}>
                  {executions.slice(0, 5).map((exec) => (
                    <div
                      key={exec.execution_id}
                      style={{
                        padding: "0.5rem",
                        marginBottom: "0.5rem",
                        background: "#f5f5f5",
                        borderRadius: "4px",
                        cursor: "pointer"
                      }}
                    >
                      <div style={{ fontWeight: "bold" }}>
                        {exec.execution_id.substring(0, 8)}
                      </div>
                      <div style={{ color: "#666" }}>
                        Status: {exec.status}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Middle Panel: Execution Monitor */}
          <div style={{
            flex: "1",
            borderRight: "1px solid #ccc",
            padding: "1rem",
            overflowY: "auto"
          }}>
            <h2 style={{ fontSize: "1.2rem", marginBottom: "1rem" }}>
              Execution Monitor
            </h2>

            {currentExecution ? (
              <div>
                {/* Dry Run Warning Banner */}
                {dryRun && (
                  <div style={{
                    padding: "1rem",
                    marginBottom: "1rem",
                    background: "#fff3cd",
                    border: "2px solid #ffc107",
                    borderRadius: "4px",
                    color: "#856404",
                    fontWeight: "bold",
                    textAlign: "center"
                  }}>
                    🔍 DRY RUN MODE - Changes are simulated, not executed
                  </div>
                )}

                <div style={{ marginBottom: "1rem" }}>
                  <div style={{ fontWeight: "bold", marginBottom: "0.5rem" }}>
                    Execution ID
                  </div>
                  <div style={{ fontFamily: "monospace", fontSize: "0.9rem" }}>
                    {currentExecution.execution_id}
                  </div>
                </div>

                <div style={{ marginBottom: "1rem" }}>
                  <div style={{ fontWeight: "bold", marginBottom: "0.5rem" }}>
                    Status
                  </div>
                  <div style={{
                    display: "inline-block",
                    padding: "0.25rem 0.75rem",
                    background: currentExecution.status === "running" ? "#4CAF50" :
                                currentExecution.status === "complete" ? "#2196F3" :
                                currentExecution.status === "failed" ? "#f44336" : "#999",
                    color: "white",
                    borderRadius: "12px",
                    fontSize: "0.85rem",
                    fontWeight: "bold"
                  }}>
                    {currentExecution.status.toUpperCase()}
                  </div>
                  {pendingApproval && (
                    <div style={{
                      display: "inline-block",
                      marginLeft: "0.5rem",
                      padding: "0.25rem 0.75rem",
                      background: "#FF9800",
                      color: "white",
                      borderRadius: "12px",
                      fontSize: "0.85rem",
                      fontWeight: "bold"
                    }}>
                      ⏸️ AWAITING APPROVAL
                    </div>
                  )}
                </div>

                <div style={{ marginBottom: "1rem" }}>
                  <div style={{ fontWeight: "bold", marginBottom: "0.5rem" }}>
                    Progress
                  </div>
                  <div style={{
                    width: "100%",
                    height: "20px",
                    background: "#e0e0e0",
                    borderRadius: "10px",
                    overflow: "hidden"
                  }}>
                    <div style={{
                      width: `${currentExecution.progress_percentage || 0}%`,
                      height: "100%",
                      background: "#4CAF50",
                      transition: "width 0.3s"
                    }} />
                  </div>
                  <div style={{ fontSize: "0.9rem", marginTop: "0.25rem", color: "#666" }}>
                    {(currentExecution.progress_percentage || 0).toFixed(1)}%
                  </div>
                </div>

                {currentExecution.current_milestone && (
                  <div style={{ marginBottom: "1rem" }}>
                    <div style={{ fontWeight: "bold", marginBottom: "0.5rem" }}>
                      Current Milestone
                    </div>
                    <div>{currentExecution.current_milestone}</div>
                  </div>
                )}

                {currentExecution.current_step && (
                  <div style={{ marginBottom: "1rem" }}>
                    <div style={{ fontWeight: "bold", marginBottom: "0.5rem" }}>
                      Current Step
                    </div>
                    <div>{currentExecution.current_step}</div>
                  </div>
                )}

                {currentExecution.files_changed && currentExecution.files_changed.length > 0 && (
                  <div style={{ marginBottom: "1rem" }}>
                    <div style={{ fontWeight: "bold", marginBottom: "0.5rem" }}>
                      Files Changed ({currentExecution.files_changed.length})
                    </div>
                    <div style={{
                      maxHeight: "150px",
                      overflowY: "auto",
                      fontSize: "0.85rem",
                      fontFamily: "monospace"
                    }}>
                      {currentExecution.files_changed.map((file, index) => (
                        <div key={index} style={{ padding: "0.25rem 0" }}>
                          {file}
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <div style={{ color: "#666", textAlign: "center", marginTop: "2rem" }}>
                No execution in progress
              </div>
            )}
          </div>

          {/* Right Panel: Configuration */}
          <div style={{
            flex: "0 0 300px",
            padding: "1rem",
            overflowY: "auto"
          }}>
            <h2 style={{ fontSize: "1.2rem", marginBottom: "1rem" }}>
              Configuration
            </h2>

            {configLoading ? (
              <div style={{ color: "#666" }}>Loading configuration...</div>
            ) : config ? (
              <div>
                <div style={{ marginBottom: "1rem" }}>
                  <div style={{ fontWeight: "bold", marginBottom: "0.5rem" }}>
                    LLM Capabilities
                  </div>
                  {config.capabilities && config.capabilities.length > 0 ? (
                    config.capabilities.map((cap) => (
                      <div
                        key={cap.name}
                        style={{
                          padding: "0.75rem",
                          marginBottom: "0.5rem",
                          background: "#f5f5f5",
                          borderRadius: "4px",
                          fontSize: "0.85rem"
                        }}
                      >
                        <div style={{ fontWeight: "bold", marginBottom: "0.25rem" }}>
                          {cap.name}
                        </div>
                        <div style={{ color: "#666" }}>
                          Model: {cap.model_name}
                        </div>
                        <div style={{ color: "#666" }}>
                          Port: {cap.port}
                        </div>
                      </div>
                    ))
                  ) : (
                    <div style={{ color: "#666" }}>No capabilities configured</div>
                  )}
                </div>

                {config.environment && (
                  <div style={{ marginTop: "2rem" }}>
                    <div style={{ fontWeight: "bold", marginBottom: "0.5rem" }}>
                      Environment
                    </div>
                    <div style={{
                      padding: "0.75rem",
                      background: "#f5f5f5",
                      borderRadius: "4px",
                      fontSize: "0.85rem",
                      fontFamily: "monospace"
                    }}>
                      {Object.entries(config.environment).map(([key, value]) => (
                        <div key={key} style={{ marginBottom: "0.25rem" }}>
                          <span style={{ color: "#666" }}>{key}:</span> {value}
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <div style={{ color: "#666" }}>Configuration not loaded</div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default SisyphusPage;

