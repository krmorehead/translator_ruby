import React, { useState } from "react";
import { useAgentStore } from "../store/agentStore";
import "./UserPreferences.css";

/**
 * UserPreferencesPanel - User settings and preferences
 * 
 * Features:
 * - Theme selection (light/dark/auto)
 * - Font size adjustment
 * - Keyboard shortcut display
 * - Export/import settings
 */
const UserPreferencesPanel = ({ onClose }) => {
  const [theme, setTheme] = useState(localStorage.getItem('theme') || 'dark');
  const [fontSize, setFontSize] = useState(localStorage.getItem('fontSize') || 'medium');
  const [showKeyboardShortcuts, setShowKeyboardShortcuts] = useState(false);
  
  const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
  const modKey = isMac ? '⌘' : 'Ctrl';
  
  const handleThemeChange = (newTheme) => {
    setTheme(newTheme);
    localStorage.setItem('theme', newTheme);
    applyTheme(newTheme);
  };
  
  const applyTheme = (themeName) => {
    if (themeName === 'auto') {
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      document.documentElement.setAttribute('data-theme', prefersDark ? 'dark' : 'light');
    } else {
      document.documentElement.setAttribute('data-theme', themeName);
    }
  };
  
  const handleFontSizeChange = (newSize) => {
    setFontSize(newSize);
    localStorage.setItem('fontSize', newSize);
    applyFontSize(newSize);
  };
  
  const applyFontSize = (size) => {
    const sizes = {
      small: '14px',
      medium: '16px',
      large: '18px',
      xlarge: '20px',
    };
    document.documentElement.style.fontSize = sizes[size] || sizes.medium;
  };
  
  const handleExportSettings = () => {
    const settings = {
      theme,
      fontSize,
      version: '1.0',
      exportedAt: new Date().toISOString(),
    };
    
    const blob = new Blob([JSON.stringify(settings, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'agent-preferences.json';
    a.click();
    URL.revokeObjectURL(url);
  };
  
  const handleImportSettings = (event) => {
    const file = event.target.files[0];
    if (!file) return;
    
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const settings = JSON.parse(e.target.result);
        if (settings.theme) handleThemeChange(settings.theme);
        if (settings.fontSize) handleFontSizeChange(settings.fontSize);
      } catch (error) {
        console.error('Failed to import settings:', error);
        alert('Failed to import settings. Please check the file format.');
      }
    };
    reader.readAsText(file);
  };
  
  const shortcuts = [
    { keys: `${modKey} + K`, action: 'Focus chat input' },
    { keys: `${modKey} + /`, action: 'Toggle configuration' },
    { keys: `${modKey} + 1`, action: 'Switch to Chat' },
    { keys: `${modKey} + 2`, action: 'Switch to Thoughts' },
    { keys: `${modKey} + 3`, action: 'Switch to Memory' },
    { keys: `${modKey} + 4`, action: 'Switch to Context' },
    { keys: `${modKey} + 5`, action: 'Switch to Timeline' },
    { keys: `${modKey} + I`, action: 'Initialize session' },
    { keys: 'Esc', action: 'Close modals' },
  ];
  
  return (
    <div className="user-preferences-overlay" onClick={onClose}>
      <div className="user-preferences-panel" onClick={(e) => e.stopPropagation()}>
        <div className="preferences-header">
          <h2>⚙️ User Preferences</h2>
          <button
            className="close-button"
            onClick={onClose}
            aria-label="Close preferences"
          >
            ✕
          </button>
        </div>
        
        <div className="preferences-content">
          {/* Theme Selection */}
          <section className="preference-section">
            <h3>🎨 Theme</h3>
            <div className="preference-options">
              <label className="radio-option">
                <input
                  type="radio"
                  name="theme"
                  value="light"
                  checked={theme === 'light'}
                  onChange={(e) => handleThemeChange(e.target.value)}
                />
                <span>☀️ Light</span>
              </label>
              <label className="radio-option">
                <input
                  type="radio"
                  name="theme"
                  value="dark"
                  checked={theme === 'dark'}
                  onChange={(e) => handleThemeChange(e.target.value)}
                />
                <span>🌙 Dark</span>
              </label>
              <label className="radio-option">
                <input
                  type="radio"
                  name="theme"
                  value="auto"
                  checked={theme === 'auto'}
                  onChange={(e) => handleThemeChange(e.target.value)}
                />
                <span>🔄 Auto</span>
              </label>
            </div>
          </section>
          
          {/* Font Size */}
          <section className="preference-section">
            <h3>🔤 Font Size</h3>
            <div className="preference-options">
              <label className="radio-option">
                <input
                  type="radio"
                  name="fontSize"
                  value="small"
                  checked={fontSize === 'small'}
                  onChange={(e) => handleFontSizeChange(e.target.value)}
                />
                <span className="font-preview-small">Small</span>
              </label>
              <label className="radio-option">
                <input
                  type="radio"
                  name="fontSize"
                  value="medium"
                  checked={fontSize === 'medium'}
                  onChange={(e) => handleFontSizeChange(e.target.value)}
                />
                <span className="font-preview-medium">Medium</span>
              </label>
              <label className="radio-option">
                <input
                  type="radio"
                  name="fontSize"
                  value="large"
                  checked={fontSize === 'large'}
                  onChange={(e) => handleFontSizeChange(e.target.value)}
                />
                <span className="font-preview-large">Large</span>
              </label>
              <label className="radio-option">
                <input
                  type="radio"
                  name="fontSize"
                  value="xlarge"
                  checked={fontSize === 'xlarge'}
                  onChange={(e) => handleFontSizeChange(e.target.value)}
                />
                <span className="font-preview-xlarge">Extra Large</span>
              </label>
            </div>
          </section>
          
          {/* Keyboard Shortcuts */}
          <section className="preference-section">
            <h3>⌨️ Keyboard Shortcuts</h3>
            <button
              className="show-shortcuts-btn"
              onClick={() => setShowKeyboardShortcuts(!showKeyboardShortcuts)}
            >
              {showKeyboardShortcuts ? '▼ Hide' : '▶ Show'} Shortcuts
            </button>
            
            {showKeyboardShortcuts && (
              <div className="shortcuts-list">
                {shortcuts.map((shortcut, index) => (
                  <div key={index} className="shortcut-item">
                    <kbd className="shortcut-keys">{shortcut.keys}</kbd>
                    <span className="shortcut-action">{shortcut.action}</span>
                  </div>
                ))}
              </div>
            )}
          </section>
          
          {/* Import/Export */}
          <section className="preference-section">
            <h3>💾 Settings Backup</h3>
            <div className="backup-actions">
              <button
                className="export-btn"
                onClick={handleExportSettings}
              >
                📤 Export Settings
              </button>
              <label className="import-btn-label">
                <input
                  type="file"
                  accept=".json"
                  onChange={handleImportSettings}
                  style={{ display: 'none' }}
                />
                <span className="import-btn">📥 Import Settings</span>
              </label>
            </div>
          </section>
        </div>
        
        <div className="preferences-footer">
          <button className="done-button" onClick={onClose}>
            Done
          </button>
        </div>
      </div>
    </div>
  );
};

export default UserPreferencesPanel;

