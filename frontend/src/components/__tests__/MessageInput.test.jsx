import { render, screen, fireEvent } from "@testing-library/react";
import MessageInput from "../MessageInput";

describe("MessageInput", () => {
  test("sends trimmed input", () => {
    const handleSend = vi.fn();
    render(<MessageInput onSend={handleSend} disabled={false} />);

    const input = screen.getByPlaceholderText(/Type your action/i);
    fireEvent.change(input, { target: { value: "  hello  " } });
    fireEvent.submit(input.closest("form"));

    expect(handleSend).toHaveBeenCalledWith("hello");
  });

  test("disables button when disabled", () => {
    render(<MessageInput onSend={vi.fn()} disabled />);
    expect(screen.getByRole("button", { name: /send/i })).toBeDisabled();
  });
});

