import { describe, expect, it } from "vitest";
import { getPrompt, listPrompts } from "../src/prompts.js";

describe("project prompts", () => {
  it("exposes the top-down cardinal generation audit", () => {
    const names = listPrompts().prompts.map((prompt) => prompt.name);
    expect(names).toContain("audit_top_down_generation");
  });

  it("keeps perspective volume separate from the orthogonal ground", () => {
    const prompt = getPrompt("audit_top_down_generation");
    const text = prompt.messages[0].content.text;
    expect(text).toContain("coordinate_system=orthogonal_top_down");
    expect(text).toContain("volume_style=controlled_perspective");
    expect(text).toContain("screen-aligned and cardinal");
  });
});
