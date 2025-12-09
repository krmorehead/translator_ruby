import { create } from "zustand";
import {
  sendMessage,
  getConversation,
  getAgentState,
  getAgentVersion
} from "../api/dndChatApi";

const POLL_INTERVAL_MS = 2500;

export const useChatStore = create((set, get) => ({
  messages: [],
  agentState: { version: 0, state: { memories: {}, inventory: [] } },
  loading: false,
  error: "",
  polling: null,

  fetchConversation: async () => {
    if (get().messages.length > 0) return;
    try {
      const convo = await getConversation();
      set({ messages: convo.messages || [] });
    } catch (err) {
      set({ error: err.message || "Failed to load conversation" });
    }
  },

  fetchAgentState: async () => {
    try {
      const agent = await getAgentState();
      set({ agentState: agent, error: "" });
    } catch (err) {
      set({ error: err.message || "Failed to load agent state" });
    }
  },

  sendChatMessage: async (text) => {
    const optimistic = { source: "user", target: "assistant", message: text };
    set((state) => ({
      loading: true,
      error: "",
      messages: [...state.messages, optimistic]
    }));
    try {
      const result = await sendMessage(text);
      if (result?.conversation?.messages) {
        set({ messages: result.conversation.messages });
      }
      await get().fetchAgentState();
      set({ loading: false });
    } catch (err) {
      set({ error: err.message || "Failed to send message", loading: false });
    }
  },

  startVersionPolling: () => {
    const existing = get().polling;
    if (existing) return;

    const intervalId = setInterval(async () => {
      try {
        const versionPayload = await getAgentVersion();
        const currentVersion = get().agentState.version || 0;
        if (versionPayload.version > currentVersion) {
          await get().fetchAgentState();
        }
      } catch (err) {
        set({ error: err.message || "Version polling failed" });
      }
    }, POLL_INTERVAL_MS);

    set({ polling: intervalId });
  },

  stopVersionPolling: () => {
    const existing = get().polling;
    if (existing) {
      clearInterval(existing);
      set({ polling: null });
    }
  }
}));

