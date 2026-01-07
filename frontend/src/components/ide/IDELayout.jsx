/**
 * IDELayout Component
 * 
 * Three-panel layout structure.
 * Pure structural component with no business logic.
 * Follows SRP: Single responsibility is layout structure.
 */

import React from 'react';
import PropTypes from 'prop-types';

export function IDELayout({ leftPanel, middlePanel, rightPanel }) {
  return (
    <div className="ide-panels">
      <div className="panel panel-left">
        {leftPanel}
      </div>
      
      <div className="panel panel-middle">
        {middlePanel}
      </div>
      
      <div className="panel panel-right">
        {rightPanel}
      </div>
    </div>
  );
}

IDELayout.propTypes = {
  leftPanel: PropTypes.node.isRequired,
  middlePanel: PropTypes.node.isRequired,
  rightPanel: PropTypes.node.isRequired,
};

export default IDELayout;

