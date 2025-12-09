import { useRef, useState } from "react";

function MessageInput({ onSend, disabled }) {
  const [text, setText] = useState("");
  const inputRef = useRef(null);

  const handleSend = () => {
    const current = inputRef.current?.value ?? text;
    const trimmed = current.trim();
    if (!trimmed) return;
    onSend(trimmed);
    setText("");
    if (inputRef.current) {
      inputRef.current.value = "";
      inputRef.current.focus();
    }
  };

  return (
    <div className="message-input">
      <input
        ref={inputRef}
        type="text"
        placeholder="Type your action or ask the DM..."
        value={text}
        onChange={(e) => setText(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            e.preventDefault();
            handleSend();
          }
        }}
        disabled={disabled}
        aria-disabled={disabled}
      />
      <button type="button" onClick={handleSend} disabled={disabled} aria-disabled={disabled}>
        Send
      </button>
    </div>
  );
}

export default MessageInput;

