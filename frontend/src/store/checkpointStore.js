import { create } from 'zustand';
import * as checkpointApi from '../api/checkpointApi';

export const useCheckpointStore = create((set, get) => ({
  // State
  checkpoints: [],
  currentCheckpoint: null,
  selectedCheckpoint: null,
  diff: null,
  rollbackCandidates: [],
  loading: false,
  error: '',
  repositoryPath: '',

  // Actions
  setRepositoryPath: (path) => set({ repositoryPath: path }),

  /**
   * Fetch current checkpoint ID
   */
  fetchCurrentCheckpoint: async () => {
    const { repositoryPath } = get();
    if (!repositoryPath) {
      set({ error: 'Repository path not set' });
      return;
    }

    set({ loading: true, error: '' });
    try {
      const result = await checkpointApi.getCurrentCheckpoint(repositoryPath);
      set({
        currentCheckpoint: result.checkpoint_id,
        loading: false,
      });
    } catch (error) {
      set({ error: error.message, loading: false });
    }
  },

  /**
   * Fetch list of checkpoints with optional filtering
   */
  fetchCheckpoints: async (options = {}) => {
    const { repositoryPath } = get();
    if (!repositoryPath) {
      set({ error: 'Repository path not set' });
      return;
    }

    set({ loading: true, error: '' });
    try {
      const result = await checkpointApi.listCheckpoints(repositoryPath, options);
      set({
        checkpoints: result.checkpoints,
        loading: false,
      });
    } catch (error) {
      set({ error: error.message, loading: false });
    }
  },

  /**
   * Create a new checkpoint
   */
  createCheckpoint: async (message, metadata = {}) => {
    const { repositoryPath } = get();
    if (!repositoryPath) {
      set({ error: 'Repository path not set' });
      return null;
    }

    set({ loading: true, error: '' });
    try {
      const result = await checkpointApi.createCheckpoint(repositoryPath, message, metadata);
      set({ loading: false });
      
      // Refresh checkpoint list
      await get().fetchCheckpoints();
      await get().fetchCurrentCheckpoint();
      
      return result.checkpoint;
    } catch (error) {
      set({ error: error.message, loading: false });
      return null;
    }
  },

  /**
   * Get details of a specific checkpoint
   */
  fetchCheckpointDetails: async (checkpointId) => {
    const { repositoryPath } = get();
    if (!repositoryPath) {
      set({ error: 'Repository path not set' });
      return;
    }

    set({ loading: true, error: '' });
    try {
      const result = await checkpointApi.getCheckpoint(checkpointId, repositoryPath);
      set({
        selectedCheckpoint: result.checkpoint,
        loading: false,
      });
    } catch (error) {
      set({ error: error.message, loading: false });
    }
  },

  /**
   * Fetch diff for a checkpoint
   */
  fetchCheckpointDiff: async (checkpointId, targetCheckpointId = null) => {
    const { repositoryPath } = get();
    if (!repositoryPath) {
      set({ error: 'Repository path not set' });
      return;
    }

    set({ loading: true, error: '' });
    try {
      const result = await checkpointApi.getCheckpointDiff(
        checkpointId,
        repositoryPath,
        targetCheckpointId
      );
      set({
        diff: result,
        loading: false,
      });
    } catch (error) {
      set({ error: error.message, loading: false });
    }
  },

  /**
   * Rollback to a checkpoint
   */
  rollbackToCheckpoint: async (checkpointId, force = false) => {
    const { repositoryPath } = get();
    if (!repositoryPath) {
      set({ error: 'Repository path not set' });
      return false;
    }

    set({ loading: true, error: '' });
    try {
      const result = await checkpointApi.rollbackToCheckpoint(
        checkpointId,
        repositoryPath,
        force
      );
      set({ loading: false });
      
      // Refresh checkpoints and current checkpoint
      await get().fetchCheckpoints();
      await get().fetchCurrentCheckpoint();
      
      return result.success;
    } catch (error) {
      set({ error: error.message, loading: false });
      return false;
    }
  },

  /**
   * Fetch rollback candidates
   */
  fetchRollbackCandidates: async (limit = null) => {
    const { repositoryPath } = get();
    if (!repositoryPath) {
      set({ error: 'Repository path not set' });
      return;
    }

    set({ loading: true, error: '' });
    try {
      const result = await checkpointApi.getRollbackCandidates(repositoryPath, limit);
      set({
        rollbackCandidates: result.candidates,
        loading: false,
      });
    } catch (error) {
      set({ error: error.message, loading: false });
    }
  },

  /**
   * Clear error message
   */
  clearError: () => set({ error: '' }),

  /**
   * Clear selected checkpoint
   */
  clearSelectedCheckpoint: () => set({ selectedCheckpoint: null, diff: null }),
}));


