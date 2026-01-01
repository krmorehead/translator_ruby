import { create } from "zustand";
import { createProjectPlan } from "../api/projectPlanApi";

export const useProjectPlanStore = create((set, get) => ({
  goal: "",
  path: "",
  projectName: "",
  loading: false,
  error: "",
  result: null,
  
  setGoal: (goal) => set({ goal }),
  setPath: (path) => set({ path }),
  setProjectName: (projectName) => set({ projectName }),
  
  createPlan: async () => {
    const { goal, path, projectName } = get();
    set({ loading: true, error: "", result: null });
    
    try {
      const result = await createProjectPlan({ goal, path, projectName });
      set({ result, loading: false });
    } catch (err) {
      set({ error: err.message, loading: false });
    }
  },
  
  reset: () => set({
    goal: "",
    path: "",
    projectName: "",
    loading: false,
    error: "",
    result: null
  })
}));

