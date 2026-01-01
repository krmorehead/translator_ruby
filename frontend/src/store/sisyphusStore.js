import { create } from "zustand";
import * as sisyphusApi from "../api/sisyphusApi";

export const useSisyphusStore = create((set, get) => ({
  executions: [],
  currentExecution: null,
  executionLoading: false,
  executionError: "",
  currentPath: "",
  fileTree: null,
  selectedFile: null,
  fileContent: "",
  fileLoading: false,
  fileError: "",
  config: null,
  configLoading: false,
  configError: "",
  testResults: {},
  searchPattern: "",
  searchPath: "",
  searchResults: null,
  searchLoading: false,
  projectPath: "",
  planPath: "",

  startExecution: async (planPath, projectPath, options = {}) => {
    set({ executionLoading: true, executionError: "" });
    try {
      const result = await sisyphusApi.createExecution({ planPath, projectPath, options });
      set({ currentExecution: result.state, executionLoading: false });
      get().addExecution(result.state);
    } catch (error) {
      set({ executionError: error.message, executionLoading: false });
    }
  },

  fetchExecutionState: async (executionId) => {
    set({ executionLoading: true, executionError: "" });
    try {
      const result = await sisyphusApi.getExecutionState(executionId);
      set({ currentExecution: result.state, executionLoading: false });
    } catch (error) {
      set({ executionError: error.message, executionLoading: false });
    }
  },

  fetchExecutions: async (limit = 50) => {
    set({ executionLoading: true, executionError: "" });
    try {
      const result = await sisyphusApi.listExecutions(limit);
      set({ executions: result.executions, executionLoading: false });
    } catch (error) {
      set({ executionError: error.message, executionLoading: false });
    }
  },

  cancelExecution: async (executionId) => {
    set({ executionLoading: true, executionError: "" });
    try {
      await sisyphusApi.cancelExecution(executionId);
      if (get().currentExecution.execution_id === executionId) {
        set({
          currentExecution: {
            ...get().currentExecution,
            status: "failed",
            error: "Cancelled by user"
          }
        });
      }
      set({ executionLoading: false });
    } catch (error) {
      set({ executionError: error.message, executionLoading: false });
    }
  },

  addExecution: (execution) => {
    set((state) => ({ executions: [execution, ...state.executions] }));
  },

  loadFileTree: async (path, options = {}) => {
    set({ fileLoading: true, fileError: "", currentPath: path });
    try {
      const result = await sisyphusApi.getFileTree({ path, ...options });
      set({ fileTree: result.data, fileLoading: false });
    } catch (error) {
      set({ fileError: error.message, fileLoading: false });
    }
  },

  readFile: async (path) => {
    set({ fileLoading: true, fileError: "", selectedFile: path });
    try {
      const result = await sisyphusApi.readFile(path);
      set({ fileContent: result.data, fileLoading: false });
    } catch (error) {
      set({ fileError: error.message, fileLoading: false, fileContent: "" });
    }
  },

  searchFiles: async (pattern, path, options = {}) => {
    set({ searchLoading: true, searchPattern: pattern, searchPath: path });
    try {
      const result = await sisyphusApi.searchFiles({ pattern, path, ...options });
      set({ searchResults: result.data, searchLoading: false });
    } catch (error) {
      set({ fileError: error.message, searchLoading: false, searchResults: null });
    }
  },

  clearFileSelection: () => {
    set({ selectedFile: null, fileContent: "", fileError: "" });
  },

  loadConfig: async () => {
    set({ configLoading: true, configError: "" });
    try {
      const result = await sisyphusApi.getConfig();
      set({ config: result, configLoading: false });
    } catch (error) {
      set({ configError: error.message, configLoading: false });
    }
  },

  validateCapability: async (capability) => {
    set({ configLoading: true, configError: "" });
    try {
      const result = await sisyphusApi.validateConfig(capability);
      set({ configLoading: false });
      return result;
    } catch (error) {
      set({ configError: error.message, configLoading: false });
      throw error;
    }
  },

  testConnection: async (capabilityName) => {
    set({ configLoading: true });
    try {
      const result = await sisyphusApi.testConnection(capabilityName);
      set((state) => ({
        testResults: { ...state.testResults, [capabilityName]: result },
        configLoading: false
      }));
      return result;
    } catch (error) {
      set((state) => ({
        testResults: { ...state.testResults, [capabilityName]: { success: false, error: error.message } },
        configLoading: false
      }));
      throw error;
    }
  },

  setProjectPath: (path) => set({ projectPath: path }),
  setPlanPath: (path) => set({ planPath: path }),

  reset: () => set({
    executions: [],
    currentExecution: null,
    executionLoading: false,
    executionError: "",
    currentPath: "",
    fileTree: null,
    selectedFile: null,
    fileContent: "",
    fileLoading: false,
    fileError: "",
    config: null,
    configLoading: false,
    configError: "",
    testResults: {},
    searchPattern: "",
    searchPath: "",
    searchResults: null,
    searchLoading: false,
    projectPath: "",
    planPath: ""
  }),

  resetExecution: () => set({
    currentExecution: null,
    executionLoading: false,
    executionError: ""
  }),

  resetFileBrowser: () => set({
    currentPath: "",
    fileTree: null,
    selectedFile: null,
    fileContent: "",
    fileLoading: false,
    fileError: "",
    searchPattern: "",
    searchPath: "",
    searchResults: null,
    searchLoading: false
  })
}));

