/**
 * IDEHeader Component
 * 
 * Displays the top header bar with session info, project path, and actions.
 * Pure presentation component - no business logic.
 * Follows SRP: Single responsibility is header presentation.
 */

import React from 'react';
import PropTypes from 'prop-types';

export function IDEHeader({
  sessionId,
  projectPath,
  onProjectPathChange,
  onLoadProject,
  onBrowseDirectory,
  onInitializeSession,
  onOpenPreferences,
  showInitButton
}) {
  return (
    <header className="ide-header">
      <div className="header-left">
        <h1>🛠️ IDE</h1>
        {sessionId && typeof sessionId === 'string' && (
          <span className="session-badge">Session: {sessionId.slice(0, 8)}</span>
        )}
      </div>
      
      <div className="header-center">
        <button onClick={onBrowseDirectory} className="btn-browse" title="Browse for directory">
          📁 Browse
        </button>
        <input
          type="text"
          className="project-path-input"
          placeholder="Enter project path..."
          value={projectPath}
          onChange={(e) => onProjectPathChange(e.target.value)}
        />
        <button onClick={onLoadProject} className="btn-load">
          Load Project
        </button>
      </div>
      
      <div className="header-right">
        {showInitButton && (
          <button onClick={onInitializeSession} className="btn-init">
            Initialize Session
          </button>
        )}
        <button onClick={onOpenPreferences} className="btn-icon">
          👤
        </button>
      </div>
    </header>
  );
}

IDEHeader.propTypes = {
  sessionId: PropTypes.string,
  projectPath: PropTypes.string.isRequired,
  onProjectPathChange: PropTypes.func.isRequired,
  onLoadProject: PropTypes.func.isRequired,
  onBrowseDirectory: PropTypes.func.isRequired,
  onInitializeSession: PropTypes.func.isRequired,
  onOpenPreferences: PropTypes.func.isRequired,
  showInitButton: PropTypes.bool.isRequired,
};

export default IDEHeader;

