import { describe, expect } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { speed_profile } from "../../test/speedProfile";
import ChatPage from "../ChatPage";

describe("ChatPage", () => {
  const baseProps = {
    messages: [
      { source: "assistant", target: "user", message: "Welcome!" },
      { source: "user", target: "assistant", message: "Hello" }
    ],
    loading: false,
    agentState: { version: 1, state: { memories: {}, inventory: [] } },
    error: ""
  };

  speed_profile("fast")("renders messages and inspector", () => {
    const handleSend = () => {};
    render(<ChatPage {...baseProps} onSend={handleSend} />);

    expect(screen.getByText(/Welcome!/i)).toBeInTheDocument();
    expect(screen.getByText(/Hello/i)).toBeInTheDocument();
    expect(screen.getByText(/Agent Inspector/i)).toBeInTheDocument();
  });

  speed_profile("fast")("submits input via onSend", () => {
    let sentMessage = null;
    const handleSend = (msg) => { sentMessage = msg; };
    
    render(<ChatPage {...baseProps} onSend={handleSend} />);

    const input = screen.getByPlaceholderText(/Type your action/i);
    fireEvent.change(input, { target: { value: "Attack" } });
    fireEvent.click(screen.getByRole("button", { name: /send/i }));

    expect(sentMessage).toBe("Attack");
  });
});
