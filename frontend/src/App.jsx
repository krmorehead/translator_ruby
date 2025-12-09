import { useEffect } from "react";
import ChatPage from "./components/ChatPage";
import InspectorPage from "./pages/InspectorPage";
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

  useEffect(() => {
    fetchConversation();
    fetchAgentState();
    startVersionPolling();
    return () => stopVersionPolling();
  }, [fetchConversation, fetchAgentState, startVersionPolling, stopVersionPolling]);

  const path = window.location.pathname;
  if (path.startsWith("/inspector")) {
    return <InspectorPage />;
  }

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

