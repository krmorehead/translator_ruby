import React from "react";
import { useAgentStore } from "../store/agentStore";
import { Context } from "../models/Context";
import { ContextEntry } from "../models/ContextEntry";
import "./ContextManager.css";

/**
 * ContextManager displays and manages context entries (relevant files/code).
 * Allows adding, removing, and viewing context that the agent uses.
 */
const ContextManager = () => {
  const { currentSessionId, context, updateContext } = useAgentStore();
  
  const [showAddForm, setShowAddForm] = React.useState(false);
  const [newEntry, setNewEntry] = React.useState({
    type: "file",
    name: "",
    path: "",
    lineStart: "",
    lineEnd: "",
    content: "",
    relevance: "",
  });

  const handleAddEntry = (e) => {
    e.preventDefault();
    
    if (!currentSessionId || !newEntry.name) return;

    try {
      const entry = new ContextEntry({
        id: `entry-${Date.now()}`,
        type: newEntry.type,
        name: newEntry.name,
        path: newEntry.path || null,
        lineStart: newEntry.lineStart ? parseInt(newEntry.lineStart) : null,
        lineEnd: newEntry.lineEnd ? parseInt(newEntry.lineEnd) : null,
        content: newEntry.content || null,
        relevance: newEntry.relevance || null,
        addedAt: new Date(),
      });

      const currentContext = context || Context.empty(currentSessionId);
      const newContext = currentContext.addEntry(entry);
      updateContext(newContext);

      // Reset form
      setNewEntry({
        type: "file",
        name: "",
        path: "",
        lineStart: "",
        lineEnd: "",
        content: "",
        relevance: "",
      });
      setShowAddForm(false);
    } catch (error) {
      console.error("Failed to add context entry:", error);
    }
  };

  const handleRemoveEntry = (entryId) => {
    if (!context) return;
    
    const newContext = context.removeEntry(entryId);
    updateContext(newContext);
  };

  const renderEntry = (entry) => {
    return (
      <div key={entry.id} className="context-entry">
        <div className="entry-header">
          <span className="entry-type-badge">{entry.type}</span>
          <span className="entry-name">{entry.name}</span>
          <button
            className="remove-button"
            onClick={() => handleRemoveEntry(entry.id)}
            aria-label={`Remove ${entry.name}`}
          >
            ✕
          </button>
        </div>
        {entry.path && (
          <div className="entry-location">{entry.getLocation()}</div>
        )}
        {entry.relevance && (
          <div className="entry-relevance">{entry.relevance}</div>
        )}
        {entry.hasContent() && (
          <details className="entry-content-preview">
            <summary>📄 View Content</summary>
            <pre>{entry.getContentPreview(500)}</pre>
          </details>
        )}
      </div>
    );
  };

  if (!currentSessionId) {
    return (
      <div className="context-manager">
        <div className="context-empty-state">
          <p>No active session. Please initialize a session first.</p>
        </div>
      </div>
    );
  }

  const entries = context ? context.entries : [];
  const stats = context ? {
    total: context.length,
    withContent: context.getEntriesWithContent().length,
    paths: context.getUniquePaths().length,
    types: context.getUniqueTypes().length,
    size: context.getTotalContentSize(),
  } : null;

  return (
    <div className="context-manager">
      <div className="context-header">
        <h3>📚 Context Manager</h3>
        <button
          className="add-button"
          onClick={() => setShowAddForm(!showAddForm)}
          aria-label="Add context entry"
        >
          {showAddForm ? "✕ Cancel" : "+ Add Entry"}
        </button>
      </div>

      {showAddForm && (
        <form className="add-entry-form" onSubmit={handleAddEntry}>
          <div className="form-row">
            <label>
              Type:
              <select
                value={newEntry.type}
                onChange={(e) => setNewEntry({ ...newEntry, type: e.target.value })}
              >
                <option value="file">File</option>
                <option value="function">Function</option>
                <option value="class">Class</option>
                <option value="variable">Variable</option>
                <option value="other">Other</option>
              </select>
            </label>
            <label>
              Name:
              <input
                type="text"
                value={newEntry.name}
                onChange={(e) => setNewEntry({ ...newEntry, name: e.target.value })}
                placeholder="e.g., UserService"
                required
              />
            </label>
          </div>
          <div className="form-row">
            <label>
              Path:
              <input
                type="text"
                value={newEntry.path}
                onChange={(e) => setNewEntry({ ...newEntry, path: e.target.value })}
                placeholder="e.g., /app/services/user_service.rb"
              />
            </label>
          </div>
          <div className="form-row">
            <label>
              Line Start:
              <input
                type="number"
                value={newEntry.lineStart}
                onChange={(e) => setNewEntry({ ...newEntry, lineStart: e.target.value })}
                placeholder="10"
              />
            </label>
            <label>
              Line End:
              <input
                type="number"
                value={newEntry.lineEnd}
                onChange={(e) => setNewEntry({ ...newEntry, lineEnd: e.target.value })}
                placeholder="50"
              />
            </label>
          </div>
          <label className="full-width">
            Relevance:
            <textarea
              value={newEntry.relevance}
              onChange={(e) => setNewEntry({ ...newEntry, relevance: e.target.value })}
              placeholder="Why is this relevant?"
              rows="2"
            />
          </label>
          <label className="full-width">
            Content (optional):
            <textarea
              value={newEntry.content}
              onChange={(e) => setNewEntry({ ...newEntry, content: e.target.value })}
              placeholder="Paste code here..."
              rows="4"
            />
          </label>
          <button type="submit" className="submit-button">
            ✓ Add Entry
          </button>
        </form>
      )}

      <div className="context-content">
        {stats && (
          <div className="context-stats">
            <span>{stats.total} entries</span>
            <span>•</span>
            <span>{stats.withContent} with content</span>
            <span>•</span>
            <span>{stats.paths} files</span>
            <span>•</span>
            <span>{(stats.size / 1024).toFixed(1)} KB</span>
          </div>
        )}

        {entries.length === 0 ? (
          <div className="context-empty-state">
            <p>No context entries yet.</p>
            <p className="hint">Add files, functions, or code snippets that are relevant to your task.</p>
          </div>
        ) : (
          <div className="context-entries">
            {entries.map((entry) => renderEntry(entry))}
          </div>
        )}
      </div>
    </div>
  );
};

export default ContextManager;


