import { create } from "zustand";
import { createProjectPlan } from "../api/projectPlanApi";

export const useProjectPlanStore = create((set, get) => ({
  // Form state
  goal: "",
  path: "",
  projectName: "",
  
  // UI state
  loading: false,
  error: "",
  
  // Result state
  result: null,
  
  // Actions
  setGoal: (goal) => set({ goal }),
  setPath: (path) => set({ path }),
  setProjectName: (projectName) => set({ projectName }),
  
  createPlan: async () => {
    const { goal, path, projectName } = get();
    
    if (!goal || !path || !projectName) {
      set({ error: "Please fill in all required fields" });
      return;
    }
    
    set({ loading: true, error: "", result: null });
    
    try {
      const result = await createProjectPlan({
        goal,
        path,
        projectName
      });
      
      if (result.success) {
        set({ result, loading: false, error: "" });
      } else {
        set({ error: result.error || "Planning failed", loading: false });
      }
    } catch (err) {
      set({ error: err.message || "Failed to create project plan", loading: false });
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

