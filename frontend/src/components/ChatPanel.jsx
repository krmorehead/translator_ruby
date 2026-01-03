import React from "react";
import { useAgentStore } from "../store/agentStore";
import "./ChatPanel.css";

/**
 * ChatPanel displays conversation history with the agent.
 * Shows user and agent messages with timestamps and thoughts.
 */
const ChatPanel = () => {
  const [inputMessage, setInputMessage] = React.useState("");
  const sessionId = useAgentStore((state) => state.currentSessionId);
  // Subscribe to conversationThread changes - React will re-render when this changes
  const conversationThread = useAgentStore((state) => state.conversationThread);
  const chatLoading = useAgentStore((state) => state.chatLoading);
  const sendMessage = useAgentStore((state) => state.sendMessage);
  const loadConversationHistory = useAgentStore((state) => state.loadConversationHistory);

  // Extract messages - will cause re-render when conversationThread updates
  const messages = conversationThread.messages;
  
  console.log("[ChatPanel] RENDER - Session:", sessionId?.slice(0,8), "Messages:", messages.length, "First message:", messages[0]?.content?.slice(0,20));

  // Load conversation on mount and when sessionId changes
  React.useEffect(() => {
    console.log("[ChatPanel] useEffect triggered - sessionId:", sessionId);
    if (sessionId) {
      loadConversationHistory();
    }
  }, [sessionId, loadConversationHistory]);

  const handleSendMessage = async (e) => {
    e.preventDefault();
    if (!inputMessage.trim() || !sessionId) return;

    await sendMessage(inputMessage);
    setInputMessage("");
  };

  const renderMessage = (message, index) => {
    const isUser = message.role === "user";
    const isSystem = message.role === "system";

    return (
      <div
        key={message.id || index}
        className={`chat-message ${isUser ? "user-message" : ""} ${
          isSystem ? "system-message" : ""
        }`}
      >
        <div className="message-header">
          <span className="message-role">
            {isUser ? "👤 You" : isSystem ? "⚙️ System" : "🤖 Agent"}
          </span>
          <span className="message-timestamp">
            {message.getFormattedTimestamp()}
          </span>
        </div>
        <div className="message-content">{message.content}</div>
        {message.hasThoughts() && (
          <details className="message-thoughts">
            <summary>💭 Agent Reasoning</summary>
            <pre className="thoughts-content">{message.thoughts}</pre>
          </details>
        )}
      </div>
    );
  };

  if (!sessionId) {
    return (
      <div className="chat-panel">
        <div className="chat-empty-state">
          <p>No active session. Please initialize a session first.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="chat-panel">
      <div className="chat-header">
        <h3>💬 Conversation</h3>
        <span className="session-id">Session: {sessionId.slice(0, 8)}...</span>
      </div>

      <div className="chat-messages">
        {messages.length === 0 ? (
          <div className="chat-empty-state">
            <p>No messages yet. Start the conversation!</p>
          </div>
        ) : (
          messages.map((message, index) => renderMessage(message, index))
        )}
        {chatLoading && (
          <div className="chat-loading">
            <span className="loading-indicator">⏳ Agent is thinking...</span>
          </div>
        )}
      </div>

      <form className="chat-input-form" onSubmit={handleSendMessage}>
        <input
          type="text"
          className="chat-input"
          placeholder="Type your message..."
          value={inputMessage}
          onChange={(e) => setInputMessage(e.target.value)}
          disabled={chatLoading}
          aria-label="Message input"
        />
        <button
          type="submit"
          className="chat-send-button"
          disabled={!inputMessage.trim() || chatLoading}
          aria-label="Send message"
        >
          📤 Send
        </button>
      </form>
    </div>
  );
};

export default ChatPanel;
