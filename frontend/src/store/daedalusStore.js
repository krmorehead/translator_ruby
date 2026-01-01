import { create } from 'zustand';
import { daedalusApi } from '../api/daedalusApi';

export const useDaedalusStore = create((set, get) => ({
  goal: '',
  path: '',
  contextHint: '',
  loading: false,
  error: null,
  result: null,

  setGoal: (goal) => set({ goal }),
  setPath: (path) => set({ path }),
  setContextHint: (contextHint) => set({ contextHint }),

  createPlan: async () => {
    const { goal, path, contextHint } = get();
    set({ loading: true, error: null, result: null });

    try {
      const context = { hint: contextHint };
      const response = await daedalusApi.createPlan({ goal, path, context });
      set({ result: response, loading: false });
    } catch (error) {
      set({ error: error.message, loading: false });
    }
  },

  reset: () => set({
    goal: '',
    path: '',
    contextHint: '',
    loading: false,
    error: null,
    result: null,
  }),
}));

