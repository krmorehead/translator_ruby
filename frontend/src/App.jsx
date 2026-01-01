import { useEffect } from "react";
import ChatPage from "./components/ChatPage";
import InspectorPage from "./pages/InspectorPage";
import ProjectPlanPage from "./components/ProjectPlanPage";
import DaedalusPage from "./components/DaedalusPage";
import SisyphusPage from "./components/SisyphusPage";
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

  // Sisyphus Agent Worker mode - no initialization needed
  if (path.startsWith("/sisyphus")) {
    return <SisyphusPage />;
  }

  // Project Planning mode - skip D&D initialization
  if (path.startsWith("/project_planning")) {
    return <ProjectPlanPage />;
  }

  // Daedalus mode - skip D&D initialization
  if (path.startsWith("/daedalus")) {
    return <DaedalusPage />;
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

