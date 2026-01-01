import { describe, expect } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import { speed_profile } from "../../test/speedProfile";
import MessageInput from "../MessageInput";

describe("MessageInput", () => {
  speed_profile("fast")("sends trimmed input", () => {
    let sentMessage = null;
    const handleSend = (msg) => { sentMessage = msg; };
    
    render(<MessageInput onSend={handleSend} disabled={false} />);

    const input = screen.getByPlaceholderText(/Type your action/i);
    fireEvent.change(input, { target: { value: "  hello  " } });
    fireEvent.click(screen.getByRole("button", { name: /send/i }));

    expect(sentMessage).toBe("hello");
  });

  speed_profile("fast")("disables button when disabled prop is true", () => {
    const handleSend = () => {};
    render(<MessageInput onSend={handleSend} disabled />);
    
    expect(screen.getByRole("button", { name: /send/i })).toBeDisabled();
    expect(screen.getByPlaceholderText(/Type your action/i)).toBeDisabled();
  });
});
