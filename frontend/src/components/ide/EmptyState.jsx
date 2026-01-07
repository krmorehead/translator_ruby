/**
 * EmptyState Component
 * 
 * Displays empty state message when no session is active.
 * Pure presentation component.
 * Follows SRP: Single responsibility is empty state presentation.
 */

import React from 'react';
import PropTypes from 'prop-types';

export function EmptyState({ message = 'Initialize a session to start chatting with the agent' }) {
  return (
    <div className="empty-state">
      <p>{message}</p>
    </div>
  );
}

EmptyState.propTypes = {
  message: PropTypes.string,
};

export default EmptyState;

