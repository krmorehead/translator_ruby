import { render, screen } from "@testing-library/react";
import AgentInspector from "../AgentInspector";

describe("AgentInspector", () => {
  test("renders version and sections", () => {
    render(
      <AgentInspector
        agentState={{
          version: 2,
          state: {
            memories: { quests: ["Rescue the ranger"] },
            inventory: [{ name: "Torch", quantity: 2 }]
          }
        }}
      />
    );

    expect(screen.getByText(/Version 2/i)).toBeInTheDocument();
    expect(screen.getByText(/quests/i)).toBeInTheDocument();
    expect(screen.getByText(/Torch/i)).toBeInTheDocument();
  });
});


