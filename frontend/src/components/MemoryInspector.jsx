import React from "react";
import { useAgentStore } from "../store/agentStore";
import "./MemoryInspector.css";

/**
 * MemoryInspector displays agent memory sections and their contents.
 * Allows viewing and clearing memory sections.
 */
const MemoryInspector = React.memo(() => {
  const {
    currentSessionId,
    memory,
    sessionLoading,
    loadMemory,
    clearMemorySection,
  } = useAgentStore();

  const [expandedSections, setExpandedSections] = React.useState(new Set());
  const [confirmClear, setConfirmClear] = React.useState(null);

  // Load memory on mount
  React.useEffect(() => {
    if (currentSessionId) {
      loadMemory();
    }
  }, [currentSessionId, loadMemory]);

  const toggleSection = (sectionName) => {
    const newExpanded = new Set(expandedSections);
    if (newExpanded.has(sectionName)) {
      newExpanded.delete(sectionName);
    } else {
      newExpanded.add(sectionName);
    }
    setExpandedSections(newExpanded);
  };

  const handleClearSection = async (sectionName) => {
    if (confirmClear !== sectionName) {
      setConfirmClear(sectionName);
      setTimeout(() => setConfirmClear(null), 3000); // Reset after 3s
      return;
    }

    await clearMemorySection(sectionName);
    setConfirmClear(null);
  };

  const renderContent = (content) => {
    if (Array.isArray(content)) {
      return (
        <ul className="memory-list">
          {content.map((item, index) => (
            <li key={index}>{typeof item === "string" ? item : JSON.stringify(item)}</li>
          ))}
        </ul>
      );
    }

    if (typeof content === "object" && content !== null) {
      return <pre className="memory-json">{JSON.stringify(content, null, 2)}</pre>;
    }

    return <div className="memory-text">{String(content)}</div>;
  };

  const renderSection = (section) => {
    const isExpanded = expandedSections.has(section.section_name);
    const isConfirming = confirmClear === section.section_name;

    return (
      <div key={section.section_name} className="memory-section">
        <div className="section-header">
          <button
            className="section-toggle"
            onClick={() => toggleSection(section.section_name)}
            aria-label={`Toggle ${section.section_name}`}
          >
            <span className="toggle-icon">{isExpanded ? "▼" : "▶"}</span>
            <span className="section-name">{section.section_name}</span>
            <span className="section-size">
              {Array.isArray(section.content) ? `${section.content.length} items` : ""}
            </span>
          </button>
          <button
            className={`clear-button ${isConfirming ? "confirming" : ""}`}
            onClick={() => handleClearSection(section.section_name)}
            disabled={sessionLoading}
            aria-label={`Clear ${section.section_name}`}
          >
            {isConfirming ? "Click again to confirm" : "🗑️ Clear"}
          </button>
        </div>

        {isExpanded && (
          <div className="section-content">
            {section.updated_at && (
              <div className="section-meta">
                Last updated: {new Date(section.updated_at).toLocaleString()}
              </div>
            )}
            {section.content ? renderContent(section.content) : (
              <div className="section-empty">Section is empty</div>
            )}
          </div>
        )}
      </div>
    );
  };

  if (!currentSessionId) {
    return (
      <div className="memory-inspector">
        <div className="memory-empty-state">
          <p>No active session. Please initialize a session first.</p>
        </div>
      </div>
    );
  }

  const sections = Array.isArray(memory) ? memory : [];

  return (
    <div className="memory-inspector">
      <div className="memory-header">
        <h3>🧠 Memory Inspector</h3>
        <button
          className="refresh-button"
          onClick={() => loadMemory()}
          disabled={sessionLoading}
          aria-label="Refresh memory"
        >
          🔄 Refresh
        </button>
      </div>

      <div className="memory-content">
        {sections.length === 0 ? (
          <div className="memory-empty-state">
            <p>No memory sections available.</p>
            <p className="hint">Memory sections will appear as the agent works.</p>
          </div>
        ) : (
          <div className="memory-sections">
            <div className="sections-count">
              {sections.length} section{sections.length !== 1 ? "s" : ""}
            </div>
            {sections.map((section) => renderSection(section))}
          </div>
        )}
        {sessionLoading && (
          <div className="memory-loading">
            <span className="loading-indicator">⏳ Loading memory...</span>
          </div>
        )}
      </div>
    </div>
  );
});

MemoryInspector.displayName = 'MemoryInspector';

export default MemoryInspector;








