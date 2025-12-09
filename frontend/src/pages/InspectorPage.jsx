import { useEffect } from "react";
import AgentInspector from "../components/AgentInspector";
import { useChatStore } from "../store/chatStore";
import "../components/chat.css";

function InspectorPage() {
  const agentState = useChatStore((state) => state.agentState);
  const fetchAgentState = useChatStore((state) => state.fetchAgentState);
  const startVersionPolling = useChatStore((state) => state.startVersionPolling);
  const stopVersionPolling = useChatStore((state) => state.stopVersionPolling);

  useEffect(() => {
    fetchAgentState();
    startVersionPolling();
    return () => stopVersionPolling();
  }, [fetchAgentState, startVersionPolling, stopVersionPolling]);

  return (
    <div className="chat-page">
      <main className="chat-main">
        <aside className="agent-inspector-panel" style={{ width: "100%" }}>
          <header className="chat-header">
            <div>
              <p className="eyebrow">Inspector</p>
              <h2>Agent State</h2>
            </div>
            <button className="refresh-btn" onClick={fetchAgentState}>
              Refresh
            </button>
          </header>
          <AgentInspector agentState={agentState} />
        </aside>
      </main>
    </div>
  );
}

export default InspectorPage;

