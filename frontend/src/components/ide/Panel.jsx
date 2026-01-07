/**
 * Panel Component
 * 
 * Generic panel structure for the IDE.
 * Reusable across all panels (left, middle, right).
 * Follows OCP: Open for extension (via children), closed for modification.
 */

import React from 'react';
import PropTypes from 'prop-types';

export function Panel({ title, icon, children, className = '', showHeader = true }) {
  return (
    <div className={`panel ${className}`}>
      {showHeader && (
        <div className="panel-header">
          <h3>{icon && `${icon} `}{title}</h3>
        </div>
      )}
      <div className="panel-content">
        {children}
      </div>
    </div>
  );
}

Panel.propTypes = {
  title: PropTypes.string,
  icon: PropTypes.string,
  children: PropTypes.node.isRequired,
  className: PropTypes.string,
  showHeader: PropTypes.bool,
};

export default Panel;

