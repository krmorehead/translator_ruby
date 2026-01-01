import { create } from "zustand";
import * as sisyphusApi from "../api/sisyphusApi";

export const useSisyphusStore = create((set, get) => ({
  // Execution state
  executions: [],
  currentExecution: null,
  executionLoading: false,
  executionError: "",

  // File browser state
  currentPath: "",
  fileTree: null,
  selectedFile: null,
  fileContent: "",
  fileLoading: false,
  fileError: "",

  // Configuration state
  config: null,
  configLoading: false,
  configError: "",
  testResults: {},

  // Search state
  searchPattern: "",
  searchPath: "",
  searchResults: null,
  searchLoading: false,

  // Project selection state
  projectPath: "",
  planPath: "",

  // === Execution Actions ===

  /**
   * Start a new execution
   * @param {string} planPath - Path to the execution plan
   * @param {string} projectPath - Path to the project
   * @param {Object} options - Additional options
   */
  startExecution: async (planPath, projectPath, options = {}) => {
    set({ executionLoading: true, executionError: "" });

    try {
      const result = await sisyphusApi.createExecution({
        planPath,
        projectPath,
        options
      });

      if (result.success) {
        set({
          currentExecution: result.state,
          executionLoading: false,
          executionError: ""
        });
        // Add to executions list
        get().addExecution(result.state);
      } else {
        set({
          executionError: result.error || "Failed to start execution",
          executionLoading: false
        });
      }
    } catch (error) {
      set({
        executionError: error.message || "Failed to start execution",
        executionLoading: false
      });
    }
  },

  /**
   * Get execution state
   * @param {string} executionId - Execution identifier
   */
  fetchExecutionState: async (executionId) => {
    set({ executionLoading: true, executionError: "" });

    try {
      const result = await sisyphusApi.getExecutionState(executionId);

      if (result.success) {
        set({
          currentExecution: result.state,
          executionLoading: false,
          executionError: ""
        });
      } else {
        set({
          executionError: result.error || "Failed to get execution state",
          executionLoading: false
        });
      }
    } catch (error) {
      set({
        executionError: error.message || "Failed to get execution state",
        executionLoading: false
      });
    }
  },

  /**
   * List recent executions
   * @param {number} limit - Maximum number of executions
   */
  fetchExecutions: async (limit = 50) => {
    set({ executionLoading: true, executionError: "" });

    try {
      const result = await sisyphusApi.listExecutions(limit);

      if (result.success) {
        set({
          executions: result.executions || [],
          executionLoading: false,
          executionError: ""
        });
      } else {
        set({
          executionError: result.error || "Failed to list executions",
          executionLoading: false
        });
      }
    } catch (error) {
      set({
        executionError: error.message || "Failed to list executions",
        executionLoading: false
      });
    }
  },

  /**
   * Cancel an execution
   * @param {string} executionId - Execution identifier
   */
  cancelExecution: async (executionId) => {
    set({ executionLoading: true, executionError: "" });

    try {
      const result = await sisyphusApi.cancelExecution(executionId);

      if (result.success) {
        // Update execution state if it's the current one
        if (get().currentExecution?.execution_id === executionId) {
          set({
            currentExecution: {
              ...get().currentExecution,
              status: "failed",
              error: "Cancelled by user"
            }
          });
        }
        set({ executionLoading: false, executionError: "" });
      } else {
        set({
          executionError: result.error || "Failed to cancel execution",
          executionLoading: false
        });
      }
    } catch (error) {
      set({
        executionError: error.message || "Failed to cancel execution",
        executionLoading: false
      });
    }
  },

  /**
   * Add execution to list
   * @param {Object} execution - Execution state
   */
  addExecution: (execution) => {
    set((state) => ({
      executions: [execution, ...state.executions]
    }));
  },

  // === File System Actions ===

  /**
   * Load directory tree
   * @param {string} path - Directory path
   * @param {Object} options - Tree options (maxDepth, extensions, etc.)
   */
  loadFileTree: async (path, options = {}) => {
    set({ fileLoading: true, fileError: "", currentPath: path });

    try {
      const result = await sisyphusApi.getFileTree({ path, ...options });

      set({
        fileTree: result.data,
        fileLoading: false,
        fileError: ""
      });
    } catch (error) {
      set({
        fileError: error.message || "Failed to load directory tree",
        fileLoading: false
      });
    }
  },

  /**
   * Read file contents
   * @param {string} path - File path
   */
  readFile: async (path) => {
    set({ fileLoading: true, fileError: "", selectedFile: path });

    try {
      const result = await sisyphusApi.readFile(path);

      set({
        fileContent: result.data,
        fileLoading: false,
        fileError: ""
      });
    } catch (error) {
      set({
        fileError: error.message || "Failed to read file",
        fileLoading: false,
        fileContent: ""
      });
    }
  },

  /**
   * Search files
   * @param {string} pattern - Search pattern
   * @param {string} path - Directory path
   * @param {Object} options - Search options
   */
  searchFiles: async (pattern, path, options = {}) => {
    set({
      searchLoading: true,
      searchPattern: pattern,
      searchPath: path
    });

    try {
      const result = await sisyphusApi.searchFiles({ pattern, path, ...options });

      set({
        searchResults: result.data,
        searchLoading: false
      });
    } catch (error) {
      set({
        fileError: error.message || "Search failed",
        searchLoading: false,
        searchResults: null
      });
    }
  },

  /**
   * Clear file selection
   */
  clearFileSelection: () => {
    set({
      selectedFile: null,
      fileContent: "",
      fileError: ""
    });
  },

  // === Configuration Actions ===

  /**
   * Load agent configuration
   */
  loadConfig: async () => {
    set({ configLoading: true, configError: "" });

    try {
      const result = await sisyphusApi.getConfig();

      set({
        config: result,
        configLoading: false,
        configError: ""
      });
    } catch (error) {
      set({
        configError: error.message || "Failed to load configuration",
        configLoading: false
      });
    }
  },

  /**
   * Validate capability configuration
   * @param {Object} capability - Capability to validate
   */
  validateCapability: async (capability) => {
    set({ configLoading: true, configError: "" });

    try {
      const result = await sisyphusApi.validateConfig(capability);

      set({ configLoading: false, configError: "" });
      return result;
    } catch (error) {
      set({
        configError: error.message || "Validation failed",
        configLoading: false
      });
      return { valid: false, errors: [error.message] };
    }
  },

  /**
   * Test connection to LLM capability
   * @param {string} capabilityName - Capability name
   */
  testConnection: async (capabilityName) => {
    set({ configLoading: true });

    try {
      const result = await sisyphusApi.testConnection(capabilityName);

      set((state) => ({
        testResults: {
          ...state.testResults,
          [capabilityName]: result
        },
        configLoading: false
      }));

      return result;
    } catch (error) {
      set((state) => ({
        testResults: {
          ...state.testResults,
          [capabilityName]: { success: false, error: error.message }
        },
        configLoading: false
      }));
      return { success: false, error: error.message };
    }
  },

  // === Project Selection Actions ===

  /**
   * Set project path
   * @param {string} path - Project directory path
   */
  setProjectPath: (path) => set({ projectPath: path }),

  /**
   * Set plan path
   * @param {string} path - Plan file path
   */
  setPlanPath: (path) => set({ planPath: path }),

  // === Reset Actions ===

  /**
   * Reset all state
   */
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

  /**
   * Reset execution state only
   */
  resetExecution: () => set({
    currentExecution: null,
    executionLoading: false,
    executionError: ""
  }),

  /**
   * Reset file browser state only
   */
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

