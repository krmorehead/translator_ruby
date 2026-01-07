/**
 * useIDEState Hook
 * 
 * Centralizes all state management for the UnifiedIDE.
 * Aggregates store selectors into logical groups.
 * Follows SRP: Single responsibility is state aggregation.
 */

import { useAgentStore } from '../../store/agentStore';
import { useCheckpointStore } from '../../store/checkpointStore';

export function useIDEState() {
  // Session state
  const sessionId = useAgentStore(state => state.currentSessionId);
  
  // Agent state
  const mode = useAgentStore(state => state.mode);
  
  // Project state
  const projectPath = useAgentStore(state => state.projectPath);
  
  // File state
  const selectedFile = useAgentStore(state => state.sisyphus.selectedFile);
  const fileContent = useAgentStore(state => state.sisyphus.fileContent);
  
  // Approval state (Sisyphus)
  const pendingApproval = useAgentStore(state => state.sisyphus.pendingApproval);
  const approvalLoading = useAgentStore(state => state.sisyphus.approvalLoading);
  
  return {
    session: {
      id: sessionId,
      isActive: !!sessionId,
    },
    agent: {
      mode,
    },
    project: {
      path: projectPath,
      isLoaded: !!projectPath,
    },
    file: {
      selected: selectedFile,
      content: fileContent,
    },
    approval: {
      pending: pendingApproval,
      loading: approvalLoading,
      isVisible: !!pendingApproval,
    },
  };
}

