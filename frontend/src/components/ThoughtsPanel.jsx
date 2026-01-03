import React from "react";
import { useAgentStore } from "../store/agentStore";
import "./ThoughtsPanel.css";

/**
 * ThoughtsPanel displays agent reasoning and internal thoughts.
 * Shows extracted <think> tags from agent responses.
 */
const ThoughtsPanel = () => {
  const {
    currentSessionId,
    thoughtStream,
    sessionLoading,
    loadThoughts,
  } = useAgentStore();

  const [autoRefresh, setAutoRefresh] = React.useState(true);
  const [filter, setFilter] = React.useState("all"); // all, recent

  // Load thoughts on mount and when session changes
  React.useEffect(() => {
    if (currentSessionId) {
      loadThoughts();
    }
  }, [currentSessionId, loadThoughts]);

  // Auto-refresh thoughts every 5 seconds
  React.useEffect(() => {
    if (!autoRefresh || !currentSessionId) return;

    const interval = setInterval(() => {
      loadThoughts();
    }, 5000);

    return () => clearInterval(interval);
  }, [autoRefresh, currentSessionId, loadThoughts]);

  const getDisplayedThoughts = () => {
    if (!thoughtStream || !Array.isArray(thoughtStream)) return [];
    
    if (filter === "recent") {
      return thoughtStream.slice(-10); // Last 10
    }
    return thoughtStream;
  };

  const renderThought = (thought, index) => {
    return (
      <div key={thought.id || index} className="thought-entry">
        <div className="thought-header">
          <span className="thought-index">#{index + 1}</span>
          <span className="thought-timestamp">
            {new Date(thought.timestamp).toLocaleString()}
          </span>
        </div>
        <pre className="thought-content">{thought.content}</pre>
        {thought.metadata && Object.keys(thought.metadata).length > 0 && (
          <details className="thought-metadata">
            <summary>📋 Metadata</summary>
            <pre>{JSON.stringify(thought.metadata, null, 2)}</pre>
          </details>
        )}
      </div>
    );
  };

  if (!currentSessionId) {
    return (
      <div className="thoughts-panel">
        <div className="thoughts-empty-state">
          <p>No active session. Please initialize a session first.</p>
        </div>
      </div>
    );
  }

  const displayedThoughts = getDisplayedThoughts();

  return (
    <div className="thoughts-panel">
      <div className="thoughts-header">
        <h3>💭 Agent Reasoning</h3>
        <div className="thoughts-controls">
          <label className="auto-refresh-toggle">
            <input
              type="checkbox"
              checked={autoRefresh}
              onChange={(e) => setAutoRefresh(e.target.checked)}
              aria-label="Auto-refresh thoughts"
            />
            <span>Auto-refresh</span>
          </label>
          <select
            className="thoughts-filter"
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            aria-label="Filter thoughts"
          >
            <option value="all">All Thoughts</option>
            <option value="recent">Recent (10)</option>
          </select>
          <button
            className="refresh-button"
            onClick={() => loadThoughts()}
            disabled={sessionLoading}
            aria-label="Refresh thoughts"
          >
            🔄
          </button>
        </div>
      </div>

      <div className="thoughts-content">
        {displayedThoughts.length === 0 ? (
          <div className="thoughts-empty-state">
            <p>No thoughts recorded yet. The agent will share its reasoning here.</p>
          </div>
        ) : (
          <>
            <div className="thoughts-count">
              {displayedThoughts.length} thought{displayedThoughts.length !== 1 ? "s" : ""}
              {filter === "recent" && thoughtStream.length > 10 && (
                <span className="total-count"> (of {thoughtStream.length} total)</span>
              )}
            </div>
            <div className="thoughts-list">
              {displayedThoughts.map((thought, index) => renderThought(thought, index))}
            </div>
          </>
        )}
        {sessionLoading && (
          <div className="thoughts-loading">
            <span className="loading-indicator">⏳ Loading thoughts...</span>
          </div>
        )}
      </div>
    </div>
  );
};

export default ThoughtsPanel;








