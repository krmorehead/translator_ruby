/**
 * useIDEKeyboardShortcuts Hook
 * 
 * Manages keyboard shortcuts for the IDE.
 * Depends on actions and state, not store directly.
 * Follows DIP: Depends on abstractions (actions/state), not concretions (store).
 */

import { useKeyboardShortcuts } from '../useKeyboardShortcuts.jsx';

export function useIDEKeyboardShortcuts(actions, state, handlers) {
  useKeyboardShortcuts({
    focusChatInput: () => {
      if (state.session.isActive && handlers.activeTab === 'chat') {
        const input = document.querySelector('.chat-input, textarea[placeholder*="message"]');
        input?.focus();
      }
    },
    toggleConfig: handlers.toggleConfig,
    switchTab: (tab) => {
      if (state.session.isActive) {
        // Map from old tab names to new tab names
        const tabMap = {
          'chat': 'chat',
          'thoughts': 'thoughts',
          'memory': 'context',  // Old 'memory' maps to 'context'
          'context': 'timeline', // Old 'context' maps to 'timeline'
          'timeline': 'checkpoints' // Old 'timeline' maps to 'checkpoints'
        };
        const mappedTab = tabMap[tab] || tab;
        handlers.setActiveTab(mappedTab);
      }
    },
    initializeSession: () => {
      if (!state.session.isActive) {
        actions.session.initialize();
      }
    },
    closeModal: () => {
      if (state.approval.isVisible) {
        actions.approval.close();
      }
    },
  });
}

