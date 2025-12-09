function Message({ source, message }) {
  const isUser = source === "user";
  return (
    <div className={`message-row ${isUser ? "from-user" : "from-assistant"}`}>
      <div className="message-bubble">
        <p className="message-source">{isUser ? "You" : "DM"}</p>
        <div className="message-text">{message}</div>
      </div>
    </div>
  );
}

export default Message;

