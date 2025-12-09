import { useEffect, useRef } from "react";
import Message from "./Message";

function ChatLog({ messages }) {
  const logRef = useRef(null);

  useEffect(() => {
    if (!logRef.current) return;
    logRef.current.scrollTop = logRef.current.scrollHeight;
  }, [messages]);

  return (
    <div className="chat-log" ref={logRef}>
      {messages.map((msg, idx) => (
        <Message key={idx} {...msg} />
      ))}
    </div>
  );
}

export default ChatLog;

