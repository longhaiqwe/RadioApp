import { describe, expect, it } from "vitest";
import { buildSyncedLyrics } from "./syncedLyrics";

describe("syncedLyrics", () => {
  it("parses LRC lines and estimates song offset from a matched ASR snippet", () => {
    const lyrics = buildSyncedLyrics({
      source: "netease",
      rawLrc: [
        "[00:10.00]可以恨你 全力痛恨你",
        "[00:13.50]连遇上亦要躲避",
        "[00:18.00]无非想放下你 还是挂念你",
      ].join("\n"),
      snippets: [
        {
          text: "如何可以恨你 全力痛恨你 連遇上亦要躲避",
          start: 2,
          confidenceScore: 0.9,
        },
      ],
    });

    expect(lyrics).toMatchObject({
      source: "netease",
      matchedSnippet: "如何可以恨你 全力痛恨你 連遇上亦要躲避",
      estimatedOffsetSeconds: 8,
    });
    expect(lyrics?.lines.map((line) => line.text)).toEqual([
      "可以恨你 全力痛恨你",
      "连遇上亦要躲避",
      "无非想放下你 还是挂念你",
    ]);
  });

  it("returns null when the LRC does not match any lyric snippet", () => {
    const lyrics = buildSyncedLyrics({
      source: "qq",
      rawLrc: "[00:01.00]完全不相关的歌词",
      snippets: [{ text: "我怀念的是无话不说", confidenceScore: 0.8 }],
    });

    expect(lyrics).toBeNull();
  });

  it("can still return timed LRC lines without an estimated offset when fallback is allowed", () => {
    const lyrics = buildSyncedLyrics({
      source: "qq",
      rawLrc: [
        "[00:15.01]转眼天要亮了 我还辗转反侧",
        "[00:21.89]被放大的情绪 跟谁讲呢",
      ].join("\n"),
      snippets: [{ text: "一时的选择 林俊杰", confidenceScore: 0.8 }],
      allowUnmatchedLyrics: true,
    });

    expect(lyrics).toMatchObject({
      source: "qq",
      lines: [
        { time: 15.01, text: "转眼天要亮了 我还辗转反侧" },
        { time: 21.89, text: "被放大的情绪 跟谁讲呢" },
      ],
    });
    expect(lyrics?.estimatedOffsetSeconds).toBeUndefined();
    expect(lyrics?.matchedSnippet).toBeUndefined();
  });

  it("accepts noisy ASR snippets when a substantial lyric fragment matches", () => {
    const lyrics = buildSyncedLyrics({
      source: "netease",
      rawLrc: [
        "[01:10.40]如果可以恨你 全力痛恨你",
        "[01:14.97]连遇上亦要躲避",
        "[01:17.72]无非想放下你 还是挂念你",
        "[01:21.53]谁又会及我伤悲",
      ].join("\n"),
      snippets: [
        {
          text: "雨非 雨過 我已恨你 全力痛恨你 連遇上亦要躲避 無非想放下你 還是掛念你 誰又會及我傷悲",
          start: 1.2,
          confidenceScore: 0.85,
        },
      ],
    });

    expect(lyrics).toMatchObject({
      source: "netease",
      matchedSnippet:
        "雨非 雨過 我已恨你 全力痛恨你 連遇上亦要躲避 無非想放下你 還是掛念你 誰又會及我傷悲",
      estimatedOffsetSeconds: 69.2,
    });
  });

  it("estimates offset from snippet order when ASR timestamps are missing", () => {
    const lyrics = buildSyncedLyrics({
      source: "qq",
      rawLrc: [
        "[01:10.40]如果可以恨你 全力痛恨你",
        "[01:14.97]连遇上亦要躲避",
        "[01:17.72]无非想放下你 还是挂念你",
        "[01:21.53]谁又会及我伤悲",
      ].join("\n"),
      snippets: [
        { text: "雨飞 雨过 可以恨你", confidenceScore: 0.9 },
        { text: "全力痛恨你 连遇上亦要躲避", confidenceScore: 0.9 },
        { text: "无非想放下你 还是挂念你", confidenceScore: 0.9 },
        { text: "谁又会及我伤悲", confidenceScore: 0.9 },
      ],
      captureDurationSeconds: 15,
    });

    expect(lyrics).toMatchObject({
      matchedSnippet: "无非想放下你 还是挂念你",
      estimatedOffsetSeconds: 70.22,
    });
  });
});
