/**
 * TabBar Component
 * 
 * Tab navigation for the agent panel.
 * Pure presentation component.
 * Follows SRP: Single responsibility is tab navigation presentation.
 */

import React from 'react';
import PropTypes from 'prop-types';

const TABS = [
  { id: 'chat', icon: '💬', label: 'Chat' },
  { id: 'thoughts', icon: '💭', label: 'Thoughts' },
  { id: 'context', icon: '📁', label: 'Context' },
  { id: 'timeline', icon: '⏱️', label: 'Timeline' },
  { id: 'checkpoints', icon: '📍', label: 'Checkpoints' },
];

export function TabBar({ activeTab, onTabChange }) {
  return (
    <div className="agent-tabs">
      {TABS.map(({ id, icon, label }) => (
        <button
          key={id}
          className={`tab-btn ${activeTab === id ? 'active' : ''}`}
          onClick={() => onTabChange(id)}
        >
          {icon} {label}
        </button>
      ))}
    </div>
  );
}

TabBar.propTypes = {
  activeTab: PropTypes.string.isRequired,
  onTabChange: PropTypes.func.isRequired,
};

export default TabBar;

