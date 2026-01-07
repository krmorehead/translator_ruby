/**
 * useIDEActions Hook
 * 
 * Centralizes all actions for the UnifiedIDE.
 * Provides a clean, organized API for component interactions.
 * Follows SRP: Single responsibility is action aggregation.
 */

import { useAgentStore } from '../../store/agentStore';
import { useCheckpointStore } from '../../store/checkpointStore';

export function useIDEActions() {
  // Get actions from stores
  const initializeSession = useAgentStore(state => state.initializeSession);
  const setMode = useAgentStore(state => state.setMode);
  const setProjectPath = useAgentStore(state => state.setProjectPath);
  const loadFileTree = useAgentStore(state => state.loadFileTree);
  const readFile = useAgentStore(state => state.readFile);
  const approveRequest = useAgentStore(state => state.approveRequest);
  const rejectRequest = useAgentStore(state => state.rejectRequest);
  const clearApproval = useAgentStore(state => state.clearApproval);
  const setCheckpointPath = useCheckpointStore(state => state.setRepositoryPath);
  
  // Get current state for context-aware actions
  const mode = useAgentStore(state => state.mode);
  const projectPath = useAgentStore(state => state.projectPath);
  
  return {
    session: {
      initialize: async () => {
        try {
          await initializeSession(mode);
        } catch (error) {
          console.error("Failed to initialize session:", error);
          throw error;
        }
      },
    },
    agent: {
      changeMode: setMode,
    },
    project: {
      setPath: setProjectPath,
      loadFileTree: () => {
        const currentPath = useAgentStore.getState().projectPath;
        if (currentPath) {
          loadFileTree(currentPath);
          // Sync checkpoint store
          setCheckpointPath(currentPath);
        }
      },
    },
    file: {
      select: readFile,
    },
    approval: {
      approve: async (requestId) => {
        try {
          await approveRequest(requestId);
        } catch (error) {
          console.error("Failed to approve:", error);
          alert(`Failed to approve: ${error.message}`);
        }
      },
      reject: async (requestId) => {
        try {
          await rejectRequest(requestId);
        } catch (error) {
          console.error("Failed to reject:", error);
          alert(`Failed to reject: ${error.message}`);
        }
      },
      close: clearApproval,
    },
  };
}

