/**
 * TabContent Component
 * 
 * Routes to the correct tab content based on activeTab.
 * Acts as a simple router for tab panels.
 * Follows SRP: Single responsibility is tab content routing.
 */

import React from 'react';
import PropTypes from 'prop-types';
import ErrorBoundary from '../ErrorBoundary';
import ChatPanel from '../ChatPanel';
import ThoughtsPanel from '../ThoughtsPanel';
import ContextManager from '../ContextManager';
import TimelineView from '../TimelineView';
import CheckpointManager from '../CheckpointManager';

export function TabContent({ activeTab }) {
  const renderContent = () => {
    switch (activeTab) {
      case 'chat':
        return <ChatPanel />;
      case 'thoughts':
        return <ThoughtsPanel />;
      case 'context':
        return <ContextManager />;
      case 'timeline':
        return <TimelineView />;
      case 'checkpoints':
        return <CheckpointManager />;
      default:
        return <ChatPanel />;
    }
  };

  return (
    <ErrorBoundary>
      {renderContent()}
    </ErrorBoundary>
  );
}

TabContent.propTypes = {
  activeTab: PropTypes.string.isRequired,
};

export default TabContent;

