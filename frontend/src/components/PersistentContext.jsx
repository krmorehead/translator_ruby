import React, { useState, useEffect } from "react";
import { useAgentStore } from "../store/agentStore";
import "./PersistentContext.css";

/**
 * PersistentContext - User-defined context sent with every request
 * 
 * This context persists across all interactions and is included in:
 * - Every chat message
 * - Daedalus planning requests
 * - Sisyphus execution cycles
 * - Context condensation (always preserved)
 * 
 * Use cases:
 * - Coding style preferences
 * - Project guidelines
 * - Technical constraints
 * - Tone/voice preferences
 */
const PersistentContext = ({ compact = false }) => {
  const { persistentContext, setPersistentContext } = useAgentStore();
  const [isEditing, setIsEditing] = useState(false);
  const [editValue, setEditValue] = useState(persistentContext || "");
  const [isExpanded, setIsExpanded] = useState(!compact);
  
  useEffect(() => {
    setEditValue(persistentContext || "");
  }, [persistentContext]);
  
  const handleSave = () => {
    setPersistentContext(editValue.trim());
    setIsEditing(false);
  };
  
  const handleCancel = () => {
    setEditValue(persistentContext || "");
    setIsEditing(false);
  };
  
  const handleClear = () => {
    if (confirm("Are you sure you want to clear the persistent context?")) {
      setPersistentContext("");
      setEditValue("");
      setIsEditing(false);
    }
  };
  
  const hasContent = persistentContext && persistentContext.trim().length > 0;
  
  if (compact) {
    return (
      <div className="persistent-context-compact">
        <button
          className="persistent-context-toggle"
          onClick={() => setIsExpanded(!isExpanded)}
          aria-label="Toggle persistent context"
        >
          <span className={`toggle-icon ${isExpanded ? 'expanded' : ''}`}>▶</span>
          <span className="toggle-label">
            📌 Persistent Context
            {hasContent && <span className="context-indicator">●</span>}
          </span>
        </button>
        
        {isExpanded && (
          <div className="persistent-context-content">
            {!isEditing ? (
              <div className="context-display">
                {hasContent ? (
                  <>
                    <div className="context-text">{persistentContext}</div>
                    <div className="context-actions">
                      <button
                        className="btn-edit"
                        onClick={() => setIsEditing(true)}
                        aria-label="Edit context"
                      >
                        ✏️ Edit
                      </button>
                      <button
                        className="btn-clear"
                        onClick={handleClear}
                        aria-label="Clear context"
                      >
                        🗑️ Clear
                      </button>
                    </div>
                  </>
                ) : (
                  <div className="context-empty">
                    <p>No persistent context set.</p>
                    <button
                      className="btn-add"
                      onClick={() => setIsEditing(true)}
                    >
                      + Add Context
                    </button>
                  </div>
                )}
              </div>
            ) : (
              <div className="context-editor">
                <textarea
                  className="context-textarea"
                  value={editValue}
                  onChange={(e) => setEditValue(e.target.value)}
                  placeholder="Enter context that will be sent with every request...

Examples:
- Always use functional programming style
- Follow PEP 8 Python style guidelines
- Prefer concise explanations
- Include error handling in all code
- Target Ruby 3.0+ features"
                  rows={8}
                  autoFocus
                />
                <div className="editor-actions">
                  <button
                    className="btn-save"
                    onClick={handleSave}
                    disabled={editValue.trim() === persistentContext}
                  >
                    ✓ Save
                  </button>
                  <button
                    className="btn-cancel"
                    onClick={handleCancel}
                  >
                    ✕ Cancel
                  </button>
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    );
  }
  
  // Full view (not compact)
  return (
    <div className="persistent-context-panel">
      <div className="persistent-context-header">
        <h3>📌 Persistent Context</h3>
        <p className="context-description">
          Define context that will be included in <strong>every</strong> request to the agent.
          This persists across all conversations, planning, and execution cycles.
        </p>
      </div>
      
      {!isEditing ? (
        <div className="context-display">
          {hasContent ? (
            <>
              <div className="context-text-full">{persistentContext}</div>
              <div className="context-actions-full">
                <button
                  className="btn-edit"
                  onClick={() => setIsEditing(true)}
                >
                  ✏️ Edit Context
                </button>
                <button
                  className="btn-clear"
                  onClick={handleClear}
                >
                  🗑️ Clear Context
                </button>
              </div>
            </>
          ) : (
            <div className="context-empty-full">
              <p>No persistent context defined yet.</p>
              <p className="context-hint">
                Add instructions, style preferences, or guidelines that should
                apply to all agent interactions.
              </p>
              <button
                className="btn-add-large"
                onClick={() => setIsEditing(true)}
              >
                + Add Persistent Context
              </button>
            </div>
          )}
        </div>
      ) : (
        <div className="context-editor-full">
          <label htmlFor="persistent-context-input">
            Context Instructions
          </label>
          <textarea
            id="persistent-context-input"
            className="context-textarea-full"
            value={editValue}
            onChange={(e) => setEditValue(e.target.value)}
            placeholder="Enter persistent context...

Examples:
• Coding Style: Always use functional programming, avoid mutations
• Documentation: Include JSDoc comments for all functions
• Error Handling: Always use try-catch blocks
• Testing: Write tests for all new features
• Performance: Prefer efficient algorithms, avoid nested loops
• Security: Validate all inputs, sanitize user data"
            rows={12}
            autoFocus
          />
          <div className="character-count">
            {editValue.length} characters
          </div>
          <div className="editor-actions-full">
            <button
              className="btn-save-large"
              onClick={handleSave}
              disabled={editValue.trim() === persistentContext}
            >
              ✓ Save Persistent Context
            </button>
            <button
              className="btn-cancel-large"
              onClick={handleCancel}
            >
              ✕ Cancel
            </button>
          </div>
        </div>
      )}
      
      {hasContent && !isEditing && (
        <div className="context-info">
          <span className="info-icon">ℹ️</span>
          <span className="info-text">
            This context is automatically included in all requests to the agent,
            including chat messages, planning, and execution cycles.
          </span>
        </div>
      )}
    </div>
  );
};

export default PersistentContext;

