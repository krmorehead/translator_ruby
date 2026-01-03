import React from "react";
import { useAgentStore } from "../store/agentStore";
import "./TimelineView.css";

/**
 * TimelineView displays chronological history of agent actions.
 * Shows agent decisions, tool calls, and state transitions.
 */
const TimelineView = () => {
  const { currentSessionId } = useAgentStore();
  const [actions, setActions] = React.useState([]);
  const [loading, setLoading] = React.useState(false);
  const [filter, setFilter] = React.useState("all"); // all, tools, decisions, errors

  // Load action history
  React.useEffect(() => {
    if (!currentSessionId) return;

    const loadActions = async () => {
      setLoading(true);
      try {
        const response = await fetch(`/api/agent_sessions/${currentSessionId}/actions`);
        const data = await response.json();
        
        if (data.success) {
          setActions(data.actions || []);
        }
      } catch (error) {
        console.error("Failed to load actions:", error);
      } finally {
        setLoading(false);
      }
    };

    loadActions();
  }, [currentSessionId]);

  const getFilteredActions = () => {
    if (filter === "all") return actions;
    return actions.filter(action => action.type === filter);
  };

  const getActionIcon = (type) => {
    const icons = {
      tool_call: "🔧",
      decision: "🤔",
      error: "❌",
      milestone: "🎯",
      approval: "✋",
      completion: "✅",
      state_change: "🔄",
    };
    return icons[type] || "📝";
  };

  const renderAction = (action, index) => {
    return (
      <div key={action.id || index} className={`timeline-item ${action.type}`}>
        <div className="timeline-marker">{getActionIcon(action.type)}</div>
        <div className="timeline-content">
          <div className="action-header">
            <span className="action-type">{action.type}</span>
            <span className="action-timestamp">
              {new Date(action.timestamp).toLocaleTimeString()}
            </span>
          </div>
          <div className="action-description">{action.description || action.action}</div>
          {action.details && (
            <details className="action-details">
              <summary>Show Details</summary>
              <pre>{JSON.stringify(action.details, null, 2)}</pre>
            </details>
          )}
          {action.error && (
            <div className="action-error">{action.error}</div>
          )}
        </div>
      </div>
    );
  };

  if (!currentSessionId) {
    return (
      <div className="timeline-view">
        <div className="timeline-empty-state">
          <p>No active session. Please initialize a session first.</p>
        </div>
      </div>
    );
  }

  const filteredActions = getFilteredActions();

  return (
    <div className="timeline-view">
      <div className="timeline-header">
        <h3>⏱️ Action Timeline</h3>
        <div className="timeline-controls">
          <select
            className="timeline-filter"
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            aria-label="Filter actions"
          >
            <option value="all">All Actions</option>
            <option value="tools">Tool Calls</option>
            <option value="decisions">Decisions</option>
            <option value="errors">Errors</option>
          </select>
        </div>
      </div>

      <div className="timeline-content">
        {filteredActions.length === 0 ? (
          <div className="timeline-empty-state">
            <p>No actions recorded yet.</p>
            <p className="hint">Agent actions will appear here as they occur.</p>
          </div>
        ) : (
          <>
            <div className="timeline-count">
              {filteredActions.length} action{filteredActions.length !== 1 ? "s" : ""}
              {filter !== "all" && actions.length > filteredActions.length && (
                <span className="filtered-count"> (of {actions.length} total)</span>
              )}
            </div>
            <div className="timeline-list">
              {filteredActions.map((action, index) => renderAction(action, index))}
            </div>
          </>
        )}
        {loading && (
          <div className="timeline-loading">
            <span className="loading-indicator">⏳ Loading timeline...</span>
          </div>
        )}
      </div>
    </div>
  );
};

export default TimelineView;








