import { describe, expect, it } from "vitest";
import { buildSearchKeywords, stationMatchesKeywords } from "./stationSearch";

describe("stationSearch", () => {
  it("splits trimmed keywords", () => {
    expect(buildSearchKeywords("  CNR  音乐  ")).toEqual(["CNR", "音乐"]);
  });

  it("inserts a boundary between letters and digits", () => {
    expect(buildSearchKeywords("FM1017")).toEqual(["FM", "1017"]);
  });

  it("matches frequency numbers with decimal form", () => {
    expect(
      stationMatchesKeywords(
        { name: "FM 101.7 City Radio", tags: "" },
        ["1017"]
      )
    ).toBe(true);
  });

  it("requires all keywords to match", () => {
    expect(
      stationMatchesKeywords(
        { name: "CNR 音乐之声", tags: "music" },
        ["CNR", "音乐"]
      )
    ).toBe(true);

    expect(
      stationMatchesKeywords(
        { name: "CNR 音乐之声", tags: "music" },
        ["CNR", "交通"]
      )
    ).toBe(false);
  });
});
