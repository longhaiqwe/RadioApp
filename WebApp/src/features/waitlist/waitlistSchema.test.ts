import { describe, expect, it } from "vitest";
import { parseWaitlistRequest } from "./waitlistSchema";

describe("waitlistSchema", () => {
  it("normalizes valid email and source", () => {
    const result = parseWaitlistRequest({
      email: "  USER@Example.COM ",
      source: "recognition",
      stationId: "station-1",
      userAgent: "Mozilla",
    });

    expect(result).toEqual({
      ok: true,
      value: {
        email: "user@example.com",
        source: "recognition",
        stationId: "station-1",
        userAgent: "Mozilla",
      },
    });
  });

  it("rejects invalid email", () => {
    const result = parseWaitlistRequest({
      email: "not-email",
      source: "recognition",
    });

    expect(result).toEqual({
      ok: false,
      error: "请输入有效邮箱地址。",
    });
  });

  it("uses recognition source when source is missing", () => {
    const result = parseWaitlistRequest({
      email: "user@example.com",
    });

    expect(result).toEqual({
      ok: true,
      value: {
        email: "user@example.com",
        source: "recognition",
        stationId: null,
        userAgent: null,
      },
    });
  });
});
