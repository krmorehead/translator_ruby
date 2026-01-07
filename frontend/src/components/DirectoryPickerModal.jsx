/**
 * DirectoryPickerModal Component
 * 
 * Server-side directory browser that allows users to navigate
 * the filesystem visible to the Rails backend.
 * 
 * Solves browser security limitations - browser can't access
 * filesystem paths, but server can!
 */

import React, { useState, useEffect } from 'react';
import PropTypes from 'prop-types';
import './directory-picker-modal.css';

export function DirectoryPickerModal({ isOpen, onClose, onSelectDirectory }) {
  const [currentPath, setCurrentPath] = useState('');
  const [parentPath, setParentPath] = useState(null);
  const [directories, setDirectories] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [suggestions, setSuggestions] = useState([]);

  // Load initial suggestions
  useEffect(() => {
    if (isOpen && !currentPath) {
      loadHomeSuggestions();
    }
  }, [isOpen]);

  const loadHomeSuggestions = async () => {
    setLoading(true);
    setError(null);
    
    try {
      const response = await fetch('/api/filesystem/home');
      if (!response.ok) {
        throw new Error('Failed to load suggestions');
      }
      
      const data = await response.json();
      setSuggestions(data.suggestions || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const browseDirectory = async (path) => {
    setLoading(true);
    setError(null);
    
    try {
      const response = await fetch(`/api/filesystem/browse?path=${encodeURIComponent(path)}`);
      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to browse directory');
      }
      
      const data = await response.json();
      setCurrentPath(data.current_path);
      setParentPath(data.parent_path);
      setDirectories(data.directories || []);
      setSuggestions([]); // Clear suggestions once browsing
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSelectSuggestion = (path) => {
    browseDirectory(path);
  };

  const handleSelectDirectory = (dir) => {
    browseDirectory(dir.path);
  };

  const handleGoUp = () => {
    if (parentPath) {
      browseDirectory(parentPath);
    }
  };

  const handleChooseCurrent = () => {
    if (currentPath) {
      onSelectDirectory(currentPath);
      onClose();
    }
  };

  const handleBackToHome = () => {
    setCurrentPath('');
    setParentPath(null);
    setDirectories([]);
    setError(null);
    loadHomeSuggestions();
  };

  if (!isOpen) {
    return null;
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="directory-picker-modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>📁 Select Project Directory</h2>
          <button className="btn-close" onClick={onClose}>✕</button>
        </div>

        <div className="modal-body">
          {error && (
            <div className="error-banner">
              ⚠️ {error}
            </div>
          )}

          {/* Current Path Display */}
          {currentPath && (
            <div className="current-path-bar">
              <button className="btn-home" onClick={handleBackToHome} title="Back to start">
                🏠
              </button>
              <div className="path-display" title={currentPath}>
                {currentPath}
              </div>
              <button 
                className="btn-choose-current" 
                onClick={handleChooseCurrent}
                title="Select this directory"
              >
                ✓ Choose This
              </button>
            </div>
          )}

          {/* Navigation */}
          {currentPath && parentPath && (
            <button className="btn-up-directory" onClick={handleGoUp}>
              ⬆️ Up to Parent Directory
            </button>
          )}

          {loading ? (
            <div className="loading-spinner">
              <div className="spinner"></div>
              <p>Loading directories...</p>
            </div>
          ) : suggestions.length > 0 ? (
            /* Initial Suggestions */
            <div className="suggestions-list">
              <p className="suggestions-title">Start browsing from:</p>
              {suggestions.map((suggestion) => (
                <button
                  key={suggestion.path}
                  className="suggestion-item"
                  onClick={() => handleSelectSuggestion(suggestion.path)}
                >
                  <span className="suggestion-icon">{suggestion.icon}</span>
                  <div className="suggestion-info">
                    <div className="suggestion-name">{suggestion.name}</div>
                    <div className="suggestion-path">{suggestion.path}</div>
                  </div>
                  <span className="suggestion-arrow">→</span>
                </button>
              ))}
            </div>
          ) : directories.length > 0 ? (
            /* Directory Listing */
            <div className="directories-list">
              {directories.map((dir) => (
                <button
                  key={dir.path}
                  className="directory-item"
                  onClick={() => handleSelectDirectory(dir)}
                >
                  <span className="dir-icon">📁</span>
                  <span className="dir-name">{dir.name}</span>
                  <span className="dir-arrow">→</span>
                </button>
              ))}
            </div>
          ) : currentPath ? (
            <div className="empty-directory">
              <p>No subdirectories found in this location.</p>
              <p className="hint">You can still select this directory using "Choose This" above.</p>
            </div>
          ) : null}
        </div>

        <div className="modal-footer">
          <button className="btn-cancel" onClick={onClose}>
            Cancel
          </button>
          {currentPath && (
            <button className="btn-select" onClick={handleChooseCurrent}>
              Select: {currentPath.split('/').pop()}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

DirectoryPickerModal.propTypes = {
  isOpen: PropTypes.bool.isRequired,
  onClose: PropTypes.func.isRequired,
  onSelectDirectory: PropTypes.func.isRequired,
};

export default DirectoryPickerModal;

