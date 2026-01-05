import { useEffect } from "react";

/**
 * KeyboardShortcuts - Handles global keyboard shortcuts for the application
 * 
 * Shortcuts:
 * - Cmd/Ctrl + K: Focus chat input
 * - Cmd/Ctrl + /: Toggle configuration panel
 * - Cmd/Ctrl + 1-5: Switch between tabs (Chat, Thoughts, Memory, Context, Timeline)
 * - Cmd/Ctrl + I: Initialize session
 * - Escape: Close modals/dialogs
 */
export const useKeyboardShortcuts = (handlers) => {
  useEffect(() => {
    const handleKeyDown = (event) => {
      const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
      const modKey = isMac ? event.metaKey : event.ctrlKey;
      
      // Ignore if typing in an input/textarea (unless it's a special shortcut)
      const isTyping = ['INPUT', 'TEXTAREA'].includes(event.target.tagName);
      
      // Cmd/Ctrl + K: Focus chat input
      if (modKey && event.key === 'k') {
        event.preventDefault();
        handlers.focusChatInput?.();
        return;
      }
      
      // Cmd/Ctrl + /: Toggle config
      if (modKey && event.key === '/') {
        event.preventDefault();
        handlers.toggleConfig?.();
        return;
      }
      
      // Don't process number shortcuts if typing
      if (isTyping && !modKey) return;
      
      // Cmd/Ctrl + 1-5: Switch tabs
      if (modKey && event.key >= '1' && event.key <= '5') {
        event.preventDefault();
        const tabIndex = parseInt(event.key) - 1;
        const tabs = ['chat', 'thoughts', 'memory', 'context', 'timeline'];
        handlers.switchTab?.(tabs[tabIndex]);
        return;
      }
      
      // Cmd/Ctrl + I: Initialize session
      if (modKey && event.key === 'i') {
        event.preventDefault();
        handlers.initializeSession?.();
        return;
      }
      
      // Escape: Close modals
      if (event.key === 'Escape') {
        handlers.closeModal?.();
        return;
      }
    };
    
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [handlers]);
};

/**
 * KeyboardShortcutsHelp - Displays available keyboard shortcuts
 */
export const KeyboardShortcutsHelp = () => {
  const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
  const modKey = isMac ? '⌘' : 'Ctrl';
  
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
    <div className="keyboard-shortcuts-help">
      <h4>⌨️ Keyboard Shortcuts</h4>
      <div className="shortcuts-list">
        {shortcuts.map((shortcut, index) => (
          <div key={index} className="shortcut-item">
            <kbd className="shortcut-keys">{shortcut.keys}</kbd>
            <span className="shortcut-action">{shortcut.action}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

export default { useKeyboardShortcuts, KeyboardShortcutsHelp };

