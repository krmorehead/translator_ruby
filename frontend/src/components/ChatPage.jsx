import ChatLog from "./ChatLog";
import MessageInput from "./MessageInput";
import LoadingIndicator from "./LoadingIndicator";
import AgentInspector from "./AgentInspector";
import "./chat.css";

function ChatPage({ messages, onSend, loading, agentState, error }) {
  return (
    <div className="chat-page">
      <main className="chat-main">
        <section className="chat-log-panel">
          <header className="chat-header">
            <div>
              <p className="eyebrow">DnD Chat</p>
              <h2>Darkwood Adventure</h2>
            </div>
            {loading && <LoadingIndicator />}
          </header>
          <ChatLog messages={messages} />
          {error && <div className="banner banner-error">{error}</div>}
          <MessageInput onSend={onSend} disabled={loading} />
        </section>
        <aside className="agent-inspector-panel">
          <AgentInspector agentState={agentState} />
        </aside>
      </main>
    </div>
  );
}

export default ChatPage;

