/**
 * AgentControls Component
 * 
 * Agent mode selector and configuration button.
 * Pure presentation component.
 * Follows SRP: Single responsibility is agent control presentation.
 */

import React from 'react';
import PropTypes from 'prop-types';

const AGENT_MODES = [
  { value: 'daedalus', label: 'Daedalus (Planning)' },
  { value: 'sisyphus', label: 'Sisyphus (Execution)' },
  { value: 'researcher', label: 'Researcher (Analysis)' },
];

export function AgentControls({ mode, onModeChange, onOpenConfig }) {
  return (
    <div className="agent-controls">
      <select
        value={mode}
        onChange={(e) => onModeChange(e.target.value)}
        className="agent-selector"
      >
        {AGENT_MODES.map(({ value, label }) => (
          <option key={value} value={value}>
            {label}
          </option>
        ))}
      </select>
      <button onClick={onOpenConfig} className="btn-icon">
        ⚙️
      </button>
    </div>
  );
}

AgentControls.propTypes = {
  mode: PropTypes.string.isRequired,
  onModeChange: PropTypes.func.isRequired,
  onOpenConfig: PropTypes.func.isRequired,
};

export default AgentControls;

