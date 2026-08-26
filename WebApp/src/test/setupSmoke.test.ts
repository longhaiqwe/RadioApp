import { describe, expect, it } from "vitest";

describe("test setup", () => {
  it("runs Vitest with project aliases available", async () => {
    const setupModule = await import("@/test/setupTests");
    expect(setupModule).toBeDefined();
  });
});
