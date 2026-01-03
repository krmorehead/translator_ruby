import { create } from "zustand";
import * as sisyphusApi from "../api/sisyphusApi";
import { ApprovalRequest } from "../models/ApprovalRequest";

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
  
  // Execution options
  dryRun: false,
  approvalMode: "autonomous",
  
  // Approval state - stores ApprovalRequest instances, not raw JSON
  pendingApproval: null, // ApprovalRequest instance or null
  approvalLoading: false,
  approvalError: "",
  approvalPollingInterval: null,

  startExecution: async (planPath, projectPath, options = {}) => {
    set({ executionLoading: true, executionError: "" });
    try {
      const result = await sisyphusApi.createExecution({ planPath, projectPath, options });
      set({ currentExecution: result.state, executionLoading: false });
      get().addExecution(result.state);
      return result; // Return the full result including execution_id
    } catch (error) {
      set({ executionError: error.message, executionLoading: false });
      throw error;
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
  setDryRun: (enabled) => set({ dryRun: enabled }),
  setApprovalMode: (mode) => set({ approvalMode: mode }),

  // Approval actions - work with ApprovalRequest objects

  /**
   * Fetch pending approval for an execution
   * @param {string} executionId - Execution ID
   * @returns {Promise<ApprovalRequest|null>} ApprovalRequest instance or null
   */
  fetchPendingApproval: async (executionId) => {
    if (!executionId || typeof executionId !== "string") {
      const error = "executionId must be a non-empty string";
      set({ approvalError: error, pendingApproval: null });
      throw new Error(error);
    }

    try {
      // API returns ApprovalRequest instance or null
      const approval = await sisyphusApi.getPendingApproval(executionId);
      
      // Validate if approval returned
      if (approval !== null && !(approval instanceof ApprovalRequest)) {
        throw new Error("API must return ApprovalRequest instance or null - got: " + typeof approval);
      }
      
      set({ pendingApproval: approval, approvalError: "" });
      return approval;
    } catch (error) {
      set({ approvalError: error.message, pendingApproval: null });
      throw error;
    }
  },

  /**
   * Approve a request
   * @param {string} requestId - Request ID
   * @returns {Promise<boolean>} Success status
   */
  approveRequest: async (requestId) => {
    if (!requestId || typeof requestId !== "string") {
      const error = "requestId must be a non-empty string";
      set({ approvalError: error });
      throw new Error(error);
    }

    set({ approvalLoading: true, approvalError: "" });
    try {
      // API returns updated ApprovalRequest instance
      const updatedApproval = await sisyphusApi.approveRequest(requestId, "user");
      
      // Validate returned instance
      if (!(updatedApproval instanceof ApprovalRequest)) {
        throw new Error("API must return ApprovalRequest instance - got: " + typeof updatedApproval);
      }
      
      if (!updatedApproval.isApproved()) {
        throw new Error("Approval request was not marked as approved");
      }
      
      set({ 
        pendingApproval: null, 
        approvalLoading: false 
      });
      return true;
    } catch (error) {
      set({ approvalError: error.message, approvalLoading: false });
      throw error;
    }
  },

  /**
   * Reject a request
   * @param {string} requestId - Request ID
   * @returns {Promise<boolean>} Success status
   */
  rejectRequest: async (requestId) => {
    if (!requestId || typeof requestId !== "string") {
      const error = "requestId must be a non-empty string";
      set({ approvalError: error });
      throw new Error(error);
    }

    set({ approvalLoading: true, approvalError: "" });
    try {
      // API returns updated ApprovalRequest instance
      const updatedApproval = await sisyphusApi.rejectRequest(requestId, "user");
      
      // Validate returned instance
      if (!(updatedApproval instanceof ApprovalRequest)) {
        throw new Error("API must return ApprovalRequest instance - got: " + typeof updatedApproval);
      }
      
      if (!updatedApproval.isRejected()) {
        throw new Error("Approval request was not marked as rejected");
      }
      
      set({ 
        pendingApproval: null, 
        approvalLoading: false 
      });
      return true;
    } catch (error) {
      set({ approvalError: error.message, approvalLoading: false });
      throw error;
    }
  },

  startApprovalPolling: (executionId, intervalMs = 2000) => {
    // Clear any existing interval
    const state = get();
    if (state.approvalPollingInterval) {
      clearInterval(state.approvalPollingInterval);
    }

    // Start polling
    const interval = setInterval(async () => {
      const approval = await get().fetchPendingApproval(executionId);
      
      // Stop polling if execution is complete or failed
      const currentExec = get().currentExecution;
      if (currentExec && ["complete", "failed", "cancelled"].includes(currentExec.status)) {
        get().stopApprovalPolling();
      }
    }, intervalMs);

    set({ approvalPollingInterval: interval });
  },

  stopApprovalPolling: () => {
    const state = get();
    if (state.approvalPollingInterval) {
      clearInterval(state.approvalPollingInterval);
      set({ approvalPollingInterval: null });
    }
  },

  clearApproval: () => {
    set({ pendingApproval: null, approvalError: "" });
  },

  reset: () => {
    const state = get();
    if (state.approvalPollingInterval) {
      clearInterval(state.approvalPollingInterval);
    }
    
    set({
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
      dryRun: false,
      approvalMode: "autonomous",
      pendingApproval: null,
      approvalLoading: false,
      approvalError: "",
      approvalPollingInterval: null
    });
  },

  resetExecution: () => {
    const state = get();
    if (state.approvalPollingInterval) {
      clearInterval(state.approvalPollingInterval);
    }
    
    set({
      currentExecution: null,
      executionLoading: false,
      executionError: "",
      pendingApproval: null,
      approvalLoading: false,
      approvalError: "",
      approvalPollingInterval: null
    });
  },

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

