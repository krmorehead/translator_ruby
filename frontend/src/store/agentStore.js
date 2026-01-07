import { create } from "zustand";
import { Message } from "../models/Message";
import { ConversationThread } from "../models/ConversationThread";
import { ThoughtStream } from "../models/ThoughtStream";
import { Memory } from "../models/Memory";
import { Context } from "../models/Context";
import * as sisyphusApi from "../api/sisyphusApi";
import { daedalusApi } from "../api/daedalusApi";
import { ApprovalRequest } from "../models/ApprovalRequest";

// Unified agent store combining Daedalus (planning) and Sisyphus (execution)
export const useAgentStore = create((set, get) => ({
  // ============================================================================
  // MODE SELECTION
  // ============================================================================
  mode: "daedalus", // 'daedalus' or 'sisyphus'
  setMode: (mode) => set({ mode }),

  // ============================================================================
  // SHARED PATH STATE
  // ============================================================================
  projectPath: "",
  setProjectPath: (path) => set({ projectPath: path }),

  // ============================================================================
  // DAEDALUS STATE (Plan Generation)
  // ============================================================================
  daedalus: {
    goal: "",
    contextHint: "",
    loading: false,
    error: null,
    result: null,
  },

  setDaedalusGoal: (goal) =>
    set((state) => ({
      daedalus: { ...state.daedalus, goal },
    })),

  setDaedalusContextHint: (contextHint) =>
    set((state) => ({
      daedalus: { ...state.daedalus, contextHint },
    })),

  createPlan: async () => {
    const { daedalus, projectPath, persistentContext } = get();
    set({
      daedalus: {
        ...daedalus,
        loading: true,
        error: null,
        result: null,
      },
    });

    try {
      const context = { 
        hint: daedalus.contextHint,
        persistent: persistentContext || null
      };
      const response = await daedalusApi.createPlan({
        goal: daedalus.goal,
        path: projectPath,
        context,
      });
      set({
        daedalus: { ...get().daedalus, result: response, loading: false },
      });
    } catch (error) {
      set({
        daedalus: { ...get().daedalus, error: error.message, loading: false },
      });
    }
  },

  resetDaedalus: () =>
    set({
      daedalus: {
        goal: "",
        contextHint: "",
        loading: false,
        error: null,
        result: null,
      },
    }),

  // ============================================================================
  // SISYPHUS STATE (Execution)
  // ============================================================================
  sisyphus: {
    executions: [],
    currentExecution: null,
    executionLoading: false,
    executionError: "",
    planPath: "",
    dryRun: false,
    approvalMode: "autonomous",

    // File browser
    currentPath: "",
    fileTree: null,
    selectedFile: null,
    fileContent: "",
    fileLoading: false,
    fileError: "",

    // Search
    searchPattern: "",
    searchPath: "",
    searchResults: null,
    searchLoading: false,

    // Approval
    pendingApproval: null,
    approvalLoading: false,
    approvalError: "",
  },

  setPlanPath: (path) =>
    set((state) => ({
      sisyphus: { ...state.sisyphus, planPath: path },
    })),

  setDryRun: (enabled) =>
    set((state) => ({
      sisyphus: { ...state.sisyphus, dryRun: enabled },
    })),

  setApprovalMode: (mode) =>
    set((state) => ({
      sisyphus: { ...state.sisyphus, approvalMode: mode },
    })),

  startExecution: async (planPath, projectPath, options = {}) => {
    const { sisyphus, persistentContext } = get();
    set({
      sisyphus: {
        ...sisyphus,
        executionLoading: true,
        executionError: "",
      },
    });
    try {
      const result = await sisyphusApi.createExecution({
        planPath,
        projectPath,
        options: {
          ...options,
          persistent_context: persistentContext || null
        },
      });
      set({
        sisyphus: {
          ...get().sisyphus,
          currentExecution: result.state,
          executionLoading: false,
        },
      });
      get().addExecution(result.state);
      return result;
    } catch (error) {
      set({
        sisyphus: {
          ...get().sisyphus,
          executionError: error.message,
          executionLoading: false,
        },
      });
      throw error;
    }
  },

  fetchExecutionState: async (executionId) => {
    const { sisyphus } = get();
    set({
      sisyphus: {
        ...sisyphus,
        executionLoading: true,
        executionError: "",
      },
    });
    try {
      const result = await sisyphusApi.getExecutionState(executionId);
      set({
        sisyphus: {
          ...get().sisyphus,
          currentExecution: result.state,
          executionLoading: false,
        },
      });
    } catch (error) {
      set({
        sisyphus: {
          ...get().sisyphus,
          executionError: error.message,
          executionLoading: false,
        },
      });
    }
  },

  fetchExecutions: async (limit = 50) => {
    const { sisyphus } = get();
    set({
      sisyphus: {
        ...sisyphus,
        executionLoading: true,
        executionError: "",
      },
    });
    try {
      const result = await sisyphusApi.listExecutions(limit);
      set({
        sisyphus: {
          ...get().sisyphus,
          executions: result.executions,
          executionLoading: false,
        },
      });
    } catch (error) {
      set({
        sisyphus: {
          ...get().sisyphus,
          executionError: error.message,
          executionLoading: false,
        },
      });
    }
  },

  cancelExecution: async (executionId) => {
    const { sisyphus } = get();
    set({
      sisyphus: {
        ...sisyphus,
        executionLoading: true,
        executionError: "",
      },
    });
    try {
      await sisyphusApi.cancelExecution(executionId);
      if (sisyphus.currentExecution?.execution_id === executionId) {
        set({
          sisyphus: {
            ...get().sisyphus,
            currentExecution: {
              ...sisyphus.currentExecution,
              status: "failed",
              error: "Cancelled by user",
            },
            executionLoading: false,
          },
        });
      } else {
        set({
          sisyphus: { ...get().sisyphus, executionLoading: false },
        });
      }
    } catch (error) {
      set({
        sisyphus: {
          ...get().sisyphus,
          executionError: error.message,
          executionLoading: false,
        },
      });
    }
  },

  addExecution: (execution) =>
    set((state) => ({
      sisyphus: {
        ...state.sisyphus,
        executions: [execution, ...state.sisyphus.executions],
      },
    })),

  loadFileTree: async (path, options = {}) => {
    const { sisyphus } = get();
    set({
      sisyphus: {
        ...sisyphus,
        fileLoading: true,
        fileError: "",
        currentPath: path,
      },
    });
    try {
      const result = await sisyphusApi.getFileTree({ path, ...options });
      
      // API returns { data: { tree: {...} } }, we need just the tree
      const tree = result.data?.tree || result.data;
      
      set({
        sisyphus: {
          ...get().sisyphus,
          fileTree: tree,
          fileLoading: false,
        },
      });
    } catch (error) {
      set({
        sisyphus: {
          ...get().sisyphus,
          fileError: error.message,
          fileLoading: false,
        },
      });
    }
  },

  readFile: async (path) => {
    const { sisyphus } = get();
    set({
      sisyphus: {
        ...sisyphus,
        fileLoading: true,
        fileError: "",
        selectedFile: path,
      },
    });
    try {
      const result = await sisyphusApi.readFile(path);
      set({
        sisyphus: {
          ...get().sisyphus,
          fileContent: result.data,
          fileLoading: false,
        },
      });
    } catch (error) {
      set({
        sisyphus: {
          ...get().sisyphus,
          fileError: error.message,
          fileLoading: false,
          fileContent: "",
        },
      });
    }
  },

  searchFiles: async (pattern, path, options = {}) => {
    const { sisyphus } = get();
    set({
      sisyphus: {
        ...sisyphus,
        searchLoading: true,
        searchPattern: pattern,
        searchPath: path,
      },
    });
    try {
      const result = await sisyphusApi.searchFiles({ pattern, path, ...options });
      set({
        sisyphus: {
          ...get().sisyphus,
          searchResults: result.data,
          searchLoading: false,
        },
      });
    } catch (error) {
      set({
        sisyphus: {
          ...get().sisyphus,
          fileError: error.message,
          searchLoading: false,
          searchResults: null,
        },
      });
    }
  },

  clearFileSelection: () =>
    set((state) => ({
      sisyphus: {
        ...state.sisyphus,
        selectedFile: null,
        fileContent: "",
        fileError: "",
      },
    })),

  fetchPendingApproval: async (executionId) => {
    if (!executionId || typeof executionId !== "string") {
      const error = "executionId must be a non-empty string";
      set((state) => ({
        sisyphus: {
          ...state.sisyphus,
          approvalError: error,
          pendingApproval: null,
        },
      }));
      throw new Error(error);
    }

    try {
      const approval = await sisyphusApi.getPendingApproval(executionId);

      if (approval !== null && !(approval instanceof ApprovalRequest)) {
        throw new Error(
          "API must return ApprovalRequest instance or null - got: " +
            typeof approval
        );
      }

      set((state) => ({
        sisyphus: {
          ...state.sisyphus,
          pendingApproval: approval,
          approvalError: "",
        },
      }));
      return approval;
    } catch (error) {
      set((state) => ({
        sisyphus: {
          ...state.sisyphus,
          approvalError: error.message,
          pendingApproval: null,
        },
      }));
      throw error;
    }
  },

  approveRequest: async (requestId) => {
    if (!requestId || typeof requestId !== "string") {
      const error = "requestId must be a non-empty string";
      set((state) => ({
        sisyphus: { ...state.sisyphus, approvalError: error },
      }));
      throw new Error(error);
    }

    set((state) => ({
      sisyphus: {
        ...state.sisyphus,
        approvalLoading: true,
        approvalError: "",
      },
    }));
    try {
      const updatedApproval = await sisyphusApi.approveRequest(requestId, "user");

      if (!(updatedApproval instanceof ApprovalRequest)) {
        throw new Error(
          "API must return ApprovalRequest instance - got: " +
            typeof updatedApproval
        );
      }

      if (!updatedApproval.isApproved()) {
        throw new Error("Approval request was not marked as approved");
      }

      set((state) => ({
        sisyphus: {
          ...state.sisyphus,
          pendingApproval: null,
          approvalLoading: false,
        },
      }));
      return true;
    } catch (error) {
      set((state) => ({
        sisyphus: {
          ...state.sisyphus,
          approvalError: error.message,
          approvalLoading: false,
        },
      }));
      throw error;
    }
  },

  rejectRequest: async (requestId) => {
    if (!requestId || typeof requestId !== "string") {
      const error = "requestId must be a non-empty string";
      set((state) => ({
        sisyphus: { ...state.sisyphus, approvalError: error },
      }));
      throw new Error(error);
    }

    set((state) => ({
      sisyphus: {
        ...state.sisyphus,
        approvalLoading: true,
        approvalError: "",
      },
    }));
    try {
      const updatedApproval = await sisyphusApi.rejectRequest(requestId, "user");

      if (!(updatedApproval instanceof ApprovalRequest)) {
        throw new Error(
          "API must return ApprovalRequest instance - got: " +
            typeof updatedApproval
        );
      }

      if (!updatedApproval.isRejected()) {
        throw new Error("Approval request was not marked as rejected");
      }

      set((state) => ({
        sisyphus: {
          ...state.sisyphus,
          pendingApproval: null,
          approvalLoading: false,
        },
      }));
      return true;
    } catch (error) {
      set((state) => ({
        sisyphus: {
          ...state.sisyphus,
          approvalError: error.message,
          approvalLoading: false,
        },
      }));
      throw error;
    }
  },


  clearApproval: () =>
    set((state) => ({
      sisyphus: {
        ...state.sisyphus,
        pendingApproval: null,
        approvalError: "",
      },
    })),

  resetSisyphus: () => {
    set({
      sisyphus: {
        executions: [],
        currentExecution: null,
        executionLoading: false,
        executionError: "",
        planPath: "",
        dryRun: false,
        approvalMode: "autonomous",
        currentPath: "",
        fileTree: null,
        selectedFile: null,
        fileContent: "",
        fileLoading: false,
        fileError: "",
        searchPattern: "",
        searchPath: "",
        searchResults: null,
        searchLoading: false,
        pendingApproval: null,
        approvalLoading: false,
        approvalError: "",
      },
    });
  },

  resetSisyphusExecution: () => {
    set((state) => ({
      sisyphus: {
        ...state.sisyphus,
        currentExecution: null,
        executionLoading: false,
        executionError: "",
        pendingApproval: null,
        approvalLoading: false,
        approvalError: "",
      },
    }));
  },

  resetSisyphusFileBrowser: () =>
    set((state) => ({
      sisyphus: {
        ...state.sisyphus,
        currentPath: "",
        fileTree: null,
        selectedFile: null,
        fileContent: "",
        fileLoading: false,
        fileError: "",
        searchPattern: "",
        searchPath: "",
        searchResults: null,
        searchLoading: false,
      },
    })),

  // ============================================================================
  // CONFIGURATION STATE
  // ============================================================================
  config: null,
  configLoading: false,
  configError: "",
  testResults: {},

  loadConfig: async () => {
    set({ configLoading: true, configError: "" });
    try {
      const response = await fetch("/api/agent/config");
      const data = await response.json();
      if (!data.success) {
        throw new Error(data.error || "Failed to load configuration");
      }
      set({ config: data.config, configLoading: false });
    } catch (error) {
      set({ configError: error.message, configLoading: false });
    }
  },

  validateCapability: async (capability) => {
    set({ configLoading: true, configError: "" });
    try {
      const response = await fetch("/api/agent/config/validate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ capabilities: { [capability.name]: capability } }),
      });
      const data = await response.json();
      set({ configLoading: false });
      return data;
    } catch (error) {
      set({ configError: error.message, configLoading: false });
      throw error;
    }
  },

  testConnection: async (capabilityName) => {
    set({ configLoading: true });
    try {
      const response = await fetch("/api/agent/config/test", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ capability_name: capabilityName }),
      });
      const result = await response.json();
      set((state) => ({
        testResults: { ...state.testResults, [capabilityName]: result },
        configLoading: false,
      }));
      return result;
    } catch (error) {
      set((state) => ({
        testResults: {
          ...state.testResults,
          [capabilityName]: { success: false, error: error.message },
        },
        configLoading: false,
      }));
      throw error;
    }
  },

  // ============================================================================
  // AGENT SESSION STATE (Chat, Thoughts, Memory, Context)
  // ============================================================================
  // ============================================================================
  // AGENT SESSION STATE (Chat, Thoughts, Memory, Context)
  // ALWAYS initialized to valid domain objects, NEVER null
  // ============================================================================
  currentSessionId: null,
  conversationThread: ConversationThread.empty("temp"), 
  thoughtStream: ThoughtStream.empty("temp"),
  memory: Memory.empty("temp"),
  context: Context.empty("temp"),
  
  sessionLoading: false,
  sessionError: "",
  chatLoading: false,

  // ============================================================================
  // PERSISTENT CONTEXT - Sent with every request
  // ============================================================================
  persistentContext: localStorage.getItem("persistentContext") || "",
  
  setPersistentContext: (context) => {
    localStorage.setItem("persistentContext", context);
    set({ persistentContext: context });
  },

  // ============================================================================
  // COMPUTED ACCESSORS - Components use these, not raw state
  // NO optional checks - objects are ALWAYS valid
  // ============================================================================
  
  /**
   * Get messages array directly
   * @returns {Array<Message>} Array of Message instances
   */
  getMessages: () => {
    return get().conversationThread.messages;
  },

  /**
   * Get thoughts array directly
   * @returns {Array<Thought>} Array of Thought instances
   */
  getThoughts: () => {
    return get().thoughtStream.thoughts;
  },

  /**
   * Get memory sections array directly
   * @returns {Array<MemorySection>} Array of MemorySection instances
   */
  getMemorySections: () => {
    return get().memory.sections;
  },

  /**
   * Get context entries array directly
   * @returns {Array<ContextEntry>} Array of ContextEntry instances
   */
  getContextEntries: () => {
    return get().context.entries;
  },

  // Initialize or load session
  initializeSession: async (agentType = "daedalus") => {
    const { projectPath } = get();
    set({ sessionLoading: true, sessionError: "" });
    console.log("[initializeSession] Creating session with agent_type:", agentType, "project_path:", projectPath);
    try {
      const response = await fetch("/api/agent_sessions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ 
          agent_type: agentType, 
          owner_id: "default_user",
          project_path: projectPath || null
        }),
      });
      const data = await response.json();
      
      console.log("[initializeSession] Response:", data);
      
      if (!data.success) {
        throw new Error(data.error || "Failed to create session");
      }

      set({
        currentSessionId: data.session_id,
        conversationThread: ConversationThread.empty(data.session_id),
        thoughtStream: ThoughtStream.empty(data.session_id),
        memory: Memory.empty("daedalus"), // Will be updated when memory is loaded
        context: Context.empty(data.session_id),
        sessionLoading: false,
      });
      
      console.log("[initializeSession] Session initialized:", data.session_id);
      return data.session_id;
    } catch (error) {
      console.error("[initializeSession] Error:", error);
      set({ sessionError: error.message, sessionLoading: false });
      throw error;
    }
  },

  // Load conversation history
  loadConversationHistory: async () => {
    const { currentSessionId } = get();
    if (!currentSessionId) return;

    console.log("[loadConversationHistory] Loading for session:", currentSessionId);
    try {
      const response = await fetch(`/api/agent_sessions/${currentSessionId}/messages`);
      const data = await response.json();
      
      console.log("[loadConversationHistory] API response:", data);
      
      if (data.success && Array.isArray(data.messages)) {
        // Convert raw JSON to domain objects
        const messages = data.messages.map(msgData => Message.fromJSON(msgData));
        console.log("[loadConversationHistory] Parsed messages:", messages.length);
        
        const conversationThread = new ConversationThread({
          sessionId: currentSessionId,
          messages: messages
        });
        
        console.log("[loadConversationHistory] Setting conversation thread with", conversationThread.messages.length, "messages");
        set({ conversationThread });
      }
    } catch (error) {
      console.error("Failed to load conversation:", error);
    }
  },

  // Send message
  sendMessage: async (content) => {
    const { currentSessionId, persistentContext, projectPath } = get();
    if (!currentSessionId) return;

    set({ chatLoading: true });
    console.log("[sendMessage] Sending message for session:", currentSessionId);
    console.log("[sendMessage] Including persistent context:", persistentContext ? "YES" : "NO");
    console.log("[sendMessage] Including project path:", projectPath || "NO");
    try {
      const response = await fetch(`/api/agent_sessions/${currentSessionId}/messages`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ 
          role: "user", 
          content,
          persistent_context: persistentContext || null,
          project_path: projectPath || null
        }),
      });
      const data = await response.json();
      
      console.log("[sendMessage] API response:", data);
      
      if (data.success) {
        // Backend returns both user and agent messages
        // Reload conversation to get updated history
        console.log("[sendMessage] Message sent successfully, reloading conversation");
        await get().loadConversationHistory();
      } else {
        console.error("[sendMessage] API returned error:", data.error);
      }
    } catch (error) {
      console.error("Failed to send message:", error);
    } finally {
      set({ chatLoading: false });
    }
  },

  // Load thoughts
  loadThoughts: async () => {
    const { currentSessionId } = get();
    if (!currentSessionId) return;

    try {
      const response = await fetch(`/api/agent_sessions/${currentSessionId}/thoughts`);
      const data = await response.json();
      
      if (data.success) {
        // TODO: Convert to ThoughtStream instance
        set({ thoughtStream: data.thoughts });
      }
    } catch (error) {
      console.error("Failed to load thoughts:", error);
    }
  },

  // Load memory
  loadMemory: async () => {
    const { currentSessionId } = get();
    if (!currentSessionId) return;

    try {
      const response = await fetch(`/api/agent_sessions/${currentSessionId}/memories`);
      const data = await response.json();
      
      if (data.success) {
        // TODO: Convert to Memory instance
        set({ memory: data.sections });
      }
    } catch (error) {
      console.error("Failed to load memory:", error);
    }
  },

  // Clear memory section
  clearMemorySection: async (sectionName) => {
    const { currentSessionId } = get();
    if (!currentSessionId) return;

    try {
      const response = await fetch(
        `/api/agent_sessions/${currentSessionId}/memories/clear?section=${sectionName}`,
        { method: "DELETE" }
      );
      const data = await response.json();
      
      if (data.success) {
        // Reload memory
        get().loadMemory();
      }
    } catch (error) {
      console.error("Failed to clear memory:", error);
    }
  },

  // Update context (add/remove entries)
  updateContext: (contextInstance) => {
    set({ context: contextInstance });
  },

  // Clear session state
  clearSession: () => {
    set({
      currentSessionId: null,
      conversationThread: null,
      thoughtStream: null,
      memory: null,
      context: null,
      sessionError: "",
    });
  },

  // ============================================================================
  // GLOBAL RESET
  // ============================================================================
  reset: () => {
    get().resetDaedalus();
    get().resetSisyphus();
    get().clearSession();
    set({
      mode: "daedalus",
      projectPath: "",
      config: null,
      configLoading: false,
      configError: "",
      testResults: {},
    });
  },
}));

