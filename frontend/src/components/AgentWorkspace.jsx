import React, { useEffect, useState } from "react";
import { useAgentStore } from "../store/agentStore";
import { useKeyboardShortcuts } from "../hooks/useKeyboardShortcuts";
import ErrorBoundary from "./ErrorBoundary";
import FilePathSelector from "./FilePathSelector";
import ConfigurationPanel from "./ConfigurationPanel";
import ApprovalModal from "./ApprovalModal";
import LoadingIndicator from "./LoadingIndicator";
import ChatPanel from "./ChatPanel";
import ThoughtsPanel from "./ThoughtsPanel";
import MemoryInspector from "./MemoryInspector";
import ContextManager from "./ContextManager";
import TimelineView from "./TimelineView";
import UserPreferencesPanel from "./UserPreferencesPanel";
import PersistentContext from "./PersistentContext";
import "./agent.css";

// AgentWorkspace - Unified interface for Daedalus (planning) and Sisyphus (execution)
function AgentWorkspace() {
  const [showConfig, setShowConfig] = useState(false);
  const [showPreferences, setShowPreferences] = useState(false);
  const [initialized, setInitialized] = useState(false);
  const [activeTab, setActiveTab] = useState("chat"); // chat, thoughts, memory, context, timeline

  // Shared state
  const mode = useAgentStore((state) => state.mode);
  const setMode = useAgentStore((state) => state.setMode);
  const projectPath = useAgentStore((state) => state.projectPath);
  const setProjectPath = useAgentStore((state) => state.setProjectPath);
  const loadConfig = useAgentStore((state) => state.loadConfig);
  
  // Session state
  const sessionId = useAgentStore((state) => state.currentSessionId);
  const initializeSession = useAgentStore((state) => state.initializeSession);

  // Keyboard shortcuts
  useKeyboardShortcuts({
    focusChatInput: () => {
      if (sessionId && activeTab === 'chat') {
        const input = document.querySelector('.chat-input');
        input?.focus();
      }
    },
    toggleConfig: () => setShowConfig(!showConfig),
    switchTab: (tab) => {
      if (sessionId) {
        setActiveTab(tab);
      }
    },
    initializeSession: () => {
      if (!sessionId) {
        handleInitializeSession();
      }
    },
    closeModal: () => {
      // Approval modal handles its own escape
    },
  });

  // Daedalus state
  const daedalus = useAgentStore((state) => state.daedalus);
  const setDaedalusGoal = useAgentStore((state) => state.setDaedalusGoal);
  const setDaedalusContextHint = useAgentStore(
    (state) => state.setDaedalusContextHint
  );
  const createPlan = useAgentStore((state) => state.createPlan);
  const resetDaedalus = useAgentStore((state) => state.resetDaedalus);

  // Sisyphus state
  const sisyphus = useAgentStore((state) => state.sisyphus);
  const setPlanPath = useAgentStore((state) => state.setPlanPath);
  const setDryRun = useAgentStore((state) => state.setDryRun);
  const setApprovalMode = useAgentStore((state) => state.setApprovalMode);
  const startExecution = useAgentStore((state) => state.startExecution);
  const fetchExecutions = useAgentStore((state) => state.fetchExecutions);
  const approveRequest = useAgentStore((state) => state.approveRequest);
  const rejectRequest = useAgentStore((state) => state.rejectRequest);
  const startApprovalPolling = useAgentStore(
    (state) => state.startApprovalPolling
  );
  const stopApprovalPolling = useAgentStore(
    (state) => state.stopApprovalPolling
  );
  const clearApproval = useAgentStore((state) => state.clearApproval);

  // Initialize on mount
  useEffect(() => {
    if (!initialized) {
      loadConfig();
      if (mode === "sisyphus") {
        fetchExecutions();
      }
      setInitialized(true);
    }
  }, [initialized, mode, loadConfig, fetchExecutions]);
  
  // Handler for session initialization
  const handleInitializeSession = async () => {
    try {
      await initializeSession(mode);
    } catch (error) {
      console.error("Failed to initialize session:", error);
    }
  };

  // Cleanup polling on unmount
  useEffect(() => {
    return () => {
      stopApprovalPolling();
    };
  }, [stopApprovalPolling]);

  // Daedalus handlers
  const handleDaedalusSubmit = (e) => {
    e.preventDefault();
    createPlan();
  };

  const handleDaedalusReset = () => {
    resetDaedalus();
  };

  // Sisyphus handlers
  const handleStartExecution = async () => {
    if (!sisyphus.planPath || !projectPath) {
      alert("Please specify both plan path and project path");
      return;
    }

    try {
      const options = {
        dry_run: sisyphus.dryRun,
        approval_mode: sisyphus.approvalMode,
      };

      const result = await startExecution(
        sisyphus.planPath,
        projectPath,
        options
      );

      if (
        result &&
        result.execution_id &&
        sisyphus.approvalMode !== "autonomous"
      ) {
        startApprovalPolling(result.execution_id);
      }
    } catch (error) {
      console.error("Failed to start execution:", error);
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

  const renderMilestone = (milestone, index) => {
    if (!milestone) return null;
    
    const steps = milestone.steps || [];
    const successCriteria = milestone.success_criteria || [];
    
    return (
      <div key={milestone.id || index} className="milestone-card">
        <div className="milestone-header">
          <h3>
            Milestone {index + 1}: {milestone.title || "Untitled"}
          </h3>
        </div>
        {milestone.description && (
        <p className="milestone-description">{milestone.description}</p>
        )}

        {milestone.estimated_duration && (
        <p className="milestone-duration">
          <strong>Estimated Duration:</strong> {milestone.estimated_duration}
        </p>
        )}

        {successCriteria.length > 0 && (
        <div className="success-criteria">
          <strong>Success Criteria:</strong>
          <ul>
              {successCriteria.map((criteria, i) => (
              <li key={i}>{criteria}</li>
            ))}
          </ul>
        </div>
        )}

        {steps.length > 0 && (
        <div className="steps-section">
            <h4>Steps ({steps.length})</h4>
            {steps.map((step, stepIndex) => {
              if (!step) return null;
              const details = step.details || [];
              const tests = step.tests || [];
              
              return (
                <div key={step.id || stepIndex} className="step-card">
              <div className="step-header">
                <h5>
                      Step {step.milestone_number || index + 1}.{step.step_number || stepIndex + 1}: {step.title || "Untitled"}
                </h5>
              </div>

                  {step.intent && (
              <p className="step-intent">
                <strong>Intent:</strong> {step.intent}
              </p>
                  )}

                  {details.length > 0 && (
              <div className="step-details">
                <strong>Details:</strong>
                <ul>
                        {details.map((detail, i) => (
                    <li key={i}>{detail}</li>
                  ))}
                </ul>
              </div>
                  )}

                  {tests.length > 0 && (
              <div className="step-tests">
                <strong>Tests:</strong>
                <ul>
                        {tests.map((test, i) => (
                    <li key={i}>{test}</li>
                  ))}
                </ul>
              </div>
                  )}
            </div>
              );
            })}
        </div>
        )}
      </div>
    );
  };

  return (
    <div className="agent-workspace">
      {/* Approval Modal (Sisyphus) */}
      {sisyphus.pendingApproval && (
        <ApprovalModal
          approval={sisyphus.pendingApproval}
          onApprove={handleApprove}
          onReject={handleReject}
          onClose={handleCloseApprovalModal}
          loading={sisyphus.approvalLoading}
        />
      )}

      {/* Header with Mode Selector */}
      <header className="agent-header">
        <div className="header-content">
          <div className="header-title-row">
            <div>
              <h1>
                {mode === "daedalus"
                  ? "🏛️ Daedalus - Master Architect"
                  : "⚡ Sisyphus - Autonomous Executor"}
              </h1>
              <p className="subtitle">
                {mode === "daedalus"
                  ? "Generate detailed execution plans from codebase analysis"
                  : "Execute structured plans with optional approval workflow"}
              </p>
              {sessionId && (
                <p className="session-info">Session: {sessionId}</p>
              )}
            </div>
            <div className="header-controls">
              {!sessionId && (
                <button
                  onClick={handleInitializeSession}
                  className="btn-primary"
                  aria-label="Initialize agent session"
                >
                  Initialize Session
                </button>
              )}
              <select
                value={mode}
                onChange={(e) => setMode(e.target.value)}
                className="mode-selector"
                aria-label="Agent Mode"
              >
                <option value="daedalus">Daedalus (Planning)</option>
                <option value="sisyphus">Sisyphus (Execution)</option>
              </select>
              <button
                onClick={() => setShowConfig(!showConfig)}
                className="btn-icon"
                aria-label="Toggle configuration panel"
              >
                ⚙️
              </button>
              <button
                onClick={() => setShowPreferences(!showPreferences)}
                className="btn-icon"
                aria-label="User preferences"
              >
                👤
              </button>
            </div>
          </div>
        </div>
        {(daedalus.loading || sisyphus.executionLoading) && (
          <LoadingIndicator />
        )}
      </header>

      {/* User Preferences Modal */}
      {showPreferences && (
        <UserPreferencesPanel onClose={() => setShowPreferences(false)} />
      )}

      <main className="agent-main">
        {/* Configuration Panel (collapsible) */}
        {showConfig && (
          <aside className="config-sidebar">
            <ConfigurationPanel />
          </aside>
        )}

        <div className="agent-content">
          {/* Persistent Context (Always visible when session active) */}
          {sessionId && (
            <div className="persistent-context-container">
              <PersistentContext compact={true} />
            </div>
          )}

          {/* Tab Navigation for Chat/Thoughts/Memory/Context */}
          {sessionId && (
            <div className="agent-tabs">
              <button
                className={`tab-button ${activeTab === "chat" ? "active" : ""}`}
                onClick={() => setActiveTab("chat")}
                aria-label="Chat"
              >
                💬 Chat
              </button>
              <button
                className={`tab-button ${activeTab === "thoughts" ? "active" : ""}`}
                onClick={() => setActiveTab("thoughts")}
                aria-label="Thoughts"
              >
                💭 Thoughts
              </button>
              <button
                className={`tab-button ${activeTab === "memory" ? "active" : ""}`}
                onClick={() => setActiveTab("memory")}
                aria-label="Memory"
              >
                🧠 Memory
              </button>
              <button
                className={`tab-button ${activeTab === "context" ? "active" : ""}`}
                onClick={() => setActiveTab("context")}
                aria-label="Context"
              >
                📁 Context
              </button>
              <button
                className={`tab-button ${activeTab === "timeline" ? "active" : ""}`}
                onClick={() => setActiveTab("timeline")}
                aria-label="Timeline"
              >
                ⏱️ Timeline
              </button>
            </div>
          )}
          
          {/* Tab Content */}
          {sessionId && (
            <div className="tab-content">
              {activeTab === "chat" && (
                <ErrorBoundary showDetails={false}>
                  <ChatPanel />
                </ErrorBoundary>
              )}
              {activeTab === "thoughts" && (
                <ErrorBoundary showDetails={false}>
                  <ThoughtsPanel />
                </ErrorBoundary>
              )}
              {activeTab === "memory" && (
                <ErrorBoundary showDetails={false}>
                  <MemoryInspector />
                </ErrorBoundary>
              )}
              {activeTab === "context" && (
                <ErrorBoundary showDetails={false}>
                  <ContextManager />
                </ErrorBoundary>
              )}
              {activeTab === "timeline" && (
                <ErrorBoundary showDetails={false}>
                  <TimelineView />
                </ErrorBoundary>
              )}
            </div>
          )}
          
          {/* DAEDALUS MODE */}
          {!sessionId && mode === "daedalus" && (
            <>
              <section className="plan-form-section">
                <form onSubmit={handleDaedalusSubmit} className="plan-form">
                  <div className="form-group">
                    <label htmlFor="goal">Goal</label>
                    <textarea
                      id="goal"
                      value={daedalus.goal}
                      onChange={(e) => setDaedalusGoal(e.target.value)}
                      placeholder="Describe what you want to accomplish (e.g., 'Add user authentication system')..."
                      rows={4}
                      disabled={daedalus.loading}
                    />
                  </div>

                  <FilePathSelector
                    value={projectPath}
                    onChange={setProjectPath}
                    label="Codebase Path"
                    placeholder="/path/to/your/codebase"
                    disabled={daedalus.loading}
                  />

                  <div className="form-group">
                    <label htmlFor="contextHint">Context Hint (Optional)</label>
                    <input
                      type="text"
                      id="contextHint"
                      value={daedalus.contextHint}
                      onChange={(e) => setDaedalusContextHint(e.target.value)}
                      placeholder="E.g., 'Look at existing authentication patterns'"
                      disabled={daedalus.loading}
                    />
                    <small>Optional hint to guide the analysis</small>
                  </div>

                  <div className="form-actions">
                    <button
                      type="submit"
                      className="btn-primary"
                      disabled={daedalus.loading || !daedalus.goal || !projectPath}
                    >
                      {daedalus.loading
                        ? "Generating Plan..."
                        : "Generate Execution Plan"}
                    </button>
                    <button
                      type="button"
                      className="btn-secondary"
                      onClick={handleDaedalusReset}
                      disabled={daedalus.loading}
                    >
                      Reset
                    </button>
                  </div>
                </form>

                {daedalus.error && (
                  <div className="banner banner-error">
                    <strong>Error:</strong> {daedalus.error}
                  </div>
                )}
              </section>

              {daedalus.result && daedalus.result.execution_plan && (
                <section className="plan-result-section">
                  <div className="result-header">
                    <h2>📋 Execution Plan</h2>
                    <div className="result-meta">
                      <span>
                        {daedalus.result.metadata?.milestone_count || 0} Milestones
                      </span>
                      <span>{daedalus.result.metadata?.step_count || 0} Steps</span>
                    </div>
                  </div>

                  <div className="plan-goal">
                    <h3>Goal</h3>
                    <p>{daedalus.result.execution_plan.goal}</p>
                  </div>

                  {daedalus.result.execution_plan.constraints?.length > 0 && (
                  <div className="plan-section">
                    <h3>⚠️ Constraints</h3>
                    <ul>
                      {daedalus.result.execution_plan.constraints.map(
                        (constraint, i) => (
                          <li key={i}>{constraint}</li>
                        )
                      )}
                    </ul>
                  </div>
                  )}

                  {daedalus.result.execution_plan.assumptions?.length > 0 && (
                  <div className="plan-section">
                    <h3>💡 Assumptions</h3>
                    <ul>
                      {daedalus.result.execution_plan.assumptions.map(
                        (assumption, i) => (
                          <li key={i}>{assumption}</li>
                        )
                      )}
                    </ul>
                  </div>
                  )}

                  {daedalus.result.execution_plan.risks?.length > 0 && (
                  <div className="plan-section">
                    <h3>⚠️ Risks</h3>
                    <ul>
                      {daedalus.result.execution_plan.risks.map(
                        (risk, i) => (
                          <li key={i}>{risk}</li>
                        )
                      )}
                    </ul>
                  </div>
                  )}

                  <div className="milestones-section">
                    <h3>🎯 Milestones</h3>
                    {(daedalus.result.execution_plan.milestones || []).map(
                      (milestone, index) => renderMilestone(milestone, index)
                    )}
                  </div>

                  {daedalus.result.output_paths && (
                  <div className="output-paths">
                    <h3>📁 Output Files</h3>
                    <p>
                      <strong>Plan Markdown:</strong>{" "}
                      <code>
                        {daedalus.result.output_paths.plan_path}
                      </code>
                    </p>
                    <p>
                      <strong>Plan JSON:</strong>{" "}
                      <code>
                        {daedalus.result.output_paths.json_path}
                      </code>
                    </p>
                    <p>
                      <strong>Metadata:</strong>{" "}
                      <code>
                        {daedalus.result.output_paths.metadata_path}
                      </code>
                    </p>
                  </div>
                  )}

                  {daedalus.result.analysis_summary?.relevant_files?.length > 0 && (
                  <div className="analysis-summary">
                    <h3>🔍 Analysis Summary</h3>
                    <div>
                      <strong>
                        Relevant Files ({daedalus.result.analysis_summary.relevant_files.length}):
                      </strong>
                      <ul>
                        {daedalus.result.analysis_summary.relevant_files
                          .slice(0, 10)
                          .map((file, i) => (
                            <li key={i}>
                              <code>{file}</code>
                            </li>
                          ))}
                        {daedalus.result.analysis_summary.relevant_files.length > 10 && (
                          <li>
                            ... and {daedalus.result.analysis_summary.relevant_files.length - 10} more
                          </li>
                        )}
                      </ul>
                    </div>
                  </div>
                  )}
                </section>
              )}
            </>
          )}

          {/* SISYPHUS MODE */}
          {!sessionId && mode === "sisyphus" && (
            <div className="sisyphus-layout">
              {/* Left Panel: Project Setup */}
              <div className="sisyphus-panel sisyphus-left">
                <h2>Project Setup</h2>

                <FilePathSelector
                  value={projectPath}
                  onChange={setProjectPath}
                  label="Project Path"
                  placeholder="/path/to/project"
                  disabled={sisyphus.executionLoading}
                />

                <div className="form-group">
                  <label htmlFor="planPath">Plan Path</label>
                  <input
                    type="text"
                    id="planPath"
                    value={sisyphus.planPath}
                    onChange={(e) => setPlanPath(e.target.value)}
                    placeholder="/path/to/plan.md"
                    disabled={sisyphus.executionLoading}
                  />
                </div>

                {/* Execution Options */}
                <div className="execution-options">
                  <h3>Execution Options</h3>

                  <label className="checkbox-label">
                    <input
                      type="checkbox"
                      checked={sisyphus.dryRun}
                      onChange={(e) => setDryRun(e.target.checked)}
                      disabled={sisyphus.executionLoading}
                    />
                    <span>
                      Dry Run Mode
                      {sisyphus.dryRun && (
                        <span className="badge badge-warning">PREVIEW ONLY</span>
                      )}
                    </span>
                  </label>
                  <p className="help-text">
                    {sisyphus.dryRun
                      ? "Changes will be simulated, not executed"
                      : "Changes will be executed for real"}
                  </p>

                  <label htmlFor="approvalMode">Approval Mode</label>
                  <select
                    id="approvalMode"
                    value={sisyphus.approvalMode}
                    onChange={(e) => setApprovalMode(e.target.value)}
                    disabled={sisyphus.executionLoading}
                  >
                    <option value="autonomous">Autonomous (No approvals)</option>
                    <option value="step">Step (Approve each step)</option>
                    <option value="milestone">
                      Milestone (Approve each milestone)
                    </option>
                  </select>
                  <p className="help-text">
                    {sisyphus.approvalMode === "autonomous" &&
                      "Execution runs automatically"}
                    {sisyphus.approvalMode === "step" &&
                      "You'll approve each individual step"}
                    {sisyphus.approvalMode === "milestone" &&
                      "You'll approve each milestone (group of steps)"}
                  </p>
                </div>

                <button
                  onClick={handleStartExecution}
                  disabled={
                    sisyphus.executionLoading ||
                    !sisyphus.planPath ||
                    !projectPath
                  }
                  className="btn-primary btn-block"
                >
                  {sisyphus.executionLoading
                    ? "Starting..."
                    : "Start Execution"}
                </button>

                {sisyphus.executionError && (
                  <div className="banner banner-error">
                    {sisyphus.executionError}
                  </div>
                )}

                {/* Recent Executions */}
                <div className="recent-executions">
                  <h3>Recent Executions</h3>
                  {sisyphus.executions.length === 0 ? (
                    <p className="empty-state">No executions yet</p>
                  ) : (
                    sisyphus.executions.slice(0, 5).map((exec) => (
                      <div key={exec.execution_id} className="execution-item">
                        <div className="execution-id">
                          {exec.execution_id.substring(0, 8)}
                        </div>
                        <div className="execution-status">
                          Status: {exec.status}
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>

              {/* Middle Panel: Execution Monitor */}
              <div className="sisyphus-panel sisyphus-middle">
                <h2>Execution Monitor</h2>

                {sisyphus.currentExecution ? (
                  <div className="execution-details">
                    {sisyphus.dryRun && (
                      <div className="banner banner-warning">
                        🔍 DRY RUN MODE - Changes are simulated, not executed
                      </div>
                    )}

                    <div className="detail-item">
                      <label>Execution ID</label>
                      <code>{sisyphus.currentExecution.execution_id}</code>
                    </div>

                    <div className="detail-item">
                      <label>Status</label>
                      <span
                        className={`status-badge status-${sisyphus.currentExecution.status}`}
                      >
                        {sisyphus.currentExecution.status.toUpperCase()}
                      </span>
                      {sisyphus.pendingApproval && (
                        <span className="status-badge status-waiting">
                          ⏸️ AWAITING APPROVAL
                        </span>
                      )}
                    </div>

                    <div className="detail-item">
                      <label>Progress</label>
                      <div className="progress-bar">
                        <div
                          className="progress-fill"
                          style={{
                            width: `${sisyphus.currentExecution.progress_percentage || 0}%`,
                          }}
                        />
                      </div>
                      <span className="progress-text">
                        {(
                          sisyphus.currentExecution.progress_percentage || 0
                        ).toFixed(1)}
                        %
                      </span>
                    </div>

                    {sisyphus.currentExecution.current_milestone && (
                      <div className="detail-item">
                        <label>Current Milestone</label>
                        <p>{sisyphus.currentExecution.current_milestone}</p>
                      </div>
                    )}

                    {sisyphus.currentExecution.current_step && (
                      <div className="detail-item">
                        <label>Current Step</label>
                        <p>{sisyphus.currentExecution.current_step}</p>
                      </div>
                    )}

                    {sisyphus.currentExecution.files_changed &&
                      sisyphus.currentExecution.files_changed.length > 0 && (
                        <div className="detail-item">
                          <label>
                            Files Changed (
                            {sisyphus.currentExecution.files_changed.length})
                          </label>
                          <ul className="file-list">
                            {sisyphus.currentExecution.files_changed.map(
                              (file, index) => (
                                <li key={index}>
                                  <code>{file}</code>
                                </li>
                              )
                            )}
                          </ul>
                        </div>
                      )}
                  </div>
                ) : (
                  <div className="empty-state">No execution in progress</div>
                )}
              </div>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}

export default AgentWorkspace;

