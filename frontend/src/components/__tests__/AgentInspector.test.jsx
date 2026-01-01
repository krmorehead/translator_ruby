import { describe, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { speed_profile } from "../../test/speedProfile";
import AgentInspector from "../AgentInspector";

describe("AgentInspector", () => {
  speed_profile("fast")("renders version and sections", () => {
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
