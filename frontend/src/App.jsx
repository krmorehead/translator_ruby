import { useEffect } from "react";
import ChatPage from "./components/ChatPage";
import InspectorPage from "./pages/InspectorPage";
import ProjectPlanPage from "./components/ProjectPlanPage";
import AgentWorkspace from "./components/AgentWorkspace";
import CheckpointManager from "./components/CheckpointManager";
import { useChatStore } from "./store/chatStore";
import "./App.css";

function App() {
  const messages = useChatStore((state) => state.messages);
  const agentState = useChatStore((state) => state.agentState);
  const loading = useChatStore((state) => state.loading);
  const error = useChatStore((state) => state.error);

  const fetchConversation = useChatStore((state) => state.fetchConversation);
  const fetchAgentState = useChatStore((state) => state.fetchAgentState);
  const sendChatMessage = useChatStore((state) => state.sendChatMessage);
  const startVersionPolling = useChatStore((state) => state.startVersionPolling);
  const stopVersionPolling = useChatStore((state) => state.stopVersionPolling);

  const path = window.location.pathname;

  // Checkpoint Manager mode
  if (path.startsWith("/checkpoints")) {
    return <CheckpointManager />;
  }

  // Agent Workspace mode (unified Daedalus + Sisyphus)
  if (path.startsWith("/agent") || path.startsWith("/daedalus") || path.startsWith("/sisyphus")) {
    return <AgentWorkspace />;
  }

  // Project Planning mode - skip D&D initialization
  if (path.startsWith("/project_planning")) {
    return <ProjectPlanPage />;
  }

  // Inspector mode - skip D&D initialization
  if (path.startsWith("/inspector")) {
    return <InspectorPage />;
  }

  // D&D Chat mode - initialize chat state
  useEffect(() => {
    fetchConversation();
    fetchAgentState();
    startVersionPolling();
    return () => stopVersionPolling();
  }, [fetchConversation, fetchAgentState, startVersionPolling, stopVersionPolling]);

  return (
    <ChatPage
      messages={messages}
      onSend={sendChatMessage}
      loading={loading}
      agentState={agentState}
      error={error}
    />
  );
}

export default App;

