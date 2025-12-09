import { render, screen, fireEvent } from "@testing-library/react";
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

  test("renders messages and inspector", () => {
    render(<ChatPage {...baseProps} onSend={vi.fn()} />);

    expect(screen.getByText(/Welcome!/i)).toBeInTheDocument();
    expect(screen.getByText(/Hello/i)).toBeInTheDocument();
    expect(screen.getByText(/Agent Inspector/i)).toBeInTheDocument();
  });

  test("submits input via onSend", () => {
    const handleSend = vi.fn();
    render(<ChatPage {...baseProps} onSend={handleSend} />);

    const input = screen.getByPlaceholderText(/Type your action/i);
    fireEvent.change(input, { target: { value: "Attack" } });
    fireEvent.click(screen.getByRole("button", { name: /send/i }));

    expect(handleSend).toHaveBeenCalledWith("Attack");
  });
});

