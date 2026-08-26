import { beforeEach, describe, expect, it, vi } from "vitest";
import { captureStreamAudio } from "./audioCapture";
import { fetchSyncedLyricsVersionsForCandidates } from "./musicLyrics";
import {
  extractLikelyLyricSnippets,
  transcribeLyricsWithOpenRouter,
} from "./openRouterLyrics";
import { searchQQSongCandidates } from "./qqSongSearch";
import { recognizeStation } from "./recognitionService";
import { searchNetEaseSongCandidates } from "./neteaseSongSearch";
import { fetchStreamTrackMetadata } from "./streamMetadata";

vi.mock("./audioCapture", () => ({
  captureStreamAudio: vi.fn(async () => Buffer.from("wav")),
}));

vi.mock("./openRouterLyrics", async () => {
  const actual =
    await vi.importActual<typeof import("./openRouterLyrics")>(
      "./openRouterLyrics"
    );

  return {
    ...actual,
    transcribeLyricsWithOpenRouter: vi.fn(async () => ({
      text: "可以恨你 全力痛恨你",
      segments: [
        {
          text: "可以恨你 全力痛恨你",
          start: 2,
          confidence: 0.95,
        },
      ],
    })),
    extractLikelyLyricSnippets: vi.fn(() => [
      {
        text: "可以恨你 全力痛恨你",
        start: 2,
        confidenceScore: 0.95,
      },
    ]),
  };
});

vi.mock("./neteaseSongSearch", () => ({
  searchNetEaseSongCandidates: vi.fn(async () => [
    {
      id: "113373",
      title: "爱在记忆中找你",
      artist: "林峯",
      source: "netease",
      url: "https://music.163.com/song?id=113373",
      matchedSnippet: "可以恨你 全力痛恨你",
      confidenceScore: 0.95,
    },
  ]),
}));

vi.mock("./qqSongSearch", () => ({
  searchQQSongCandidates: vi.fn(async () => []),
}));

vi.mock("./musicLyrics", () => ({
  fetchSyncedLyricsVersionsForCandidates: vi.fn(async () => [
    {
      id: "netease:113373",
      candidate: {
        id: "113373",
        title: "爱在记忆中找你",
        artist: "林峯",
        source: "netease",
        url: "https://music.163.com/song?id=113373",
      },
      lyrics: {
        source: "netease",
        rawLrc: "[00:10.00]可以恨你 全力痛恨你",
        lines: [{ id: "0-10", time: 10, text: "可以恨你 全力痛恨你" }],
        matchedSnippet: "可以恨你 全力痛恨你",
        estimatedOffsetSeconds: 8,
      },
    },
  ]),
}));

vi.mock("./streamMetadata", () => ({
  fetchStreamTrackMetadata: vi.fn(async () => null),
}));

describe("recognitionService", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns synced lyrics for the best recognized song candidate", async () => {
    const result = await recognizeStation({
      streamUrl: "https://example.com/live.mp3",
      stationId: "station-1",
      languageHint: "zh",
    });

    expect(captureStreamAudio).toHaveBeenCalledWith({
      streamUrl: "https://example.com/live.mp3",
    });
    expect(transcribeLyricsWithOpenRouter).toHaveBeenCalled();
    expect(extractLikelyLyricSnippets).toHaveBeenCalled();
    expect(searchQQSongCandidates).toHaveBeenCalledWith(result.snippets, {
      trackMetadata: null,
    });
    expect(searchNetEaseSongCandidates).toHaveBeenCalledWith(result.snippets, {
      trackMetadata: null,
    });
    expect(fetchSyncedLyricsVersionsForCandidates).toHaveBeenCalledWith(
      result.candidates,
      result.snippets
    );
    expect(result.versions).toHaveLength(1);
    expect(result.lyrics).toMatchObject({
      source: "netease",
      estimatedOffsetSeconds: 8,
      lines: [{ text: "可以恨你 全力痛恨你" }],
    });
  });

  it("uses QQ lyric search candidates before trying NetEase", async () => {
    const qqCandidate = {
      id: "001L1lqm4UAdyo",
      title: "退后",
      artist: "周杰伦",
      album: "依然范特西",
      source: "qq" as const,
      url: "https://y.qq.com/n/ryqq/songDetail/001L1lqm4UAdyo",
      matchedSnippet: "天空灰得像哭过 离开你以后并没有更自由",
      confidenceScore: 0.94,
    };

    vi.mocked(extractLikelyLyricSnippets).mockReturnValueOnce([
      {
        text: "天空灰得像哭过 离开你以后并没有更自由",
        start: 2,
        confidenceScore: 0.94,
      },
    ]);
    vi.mocked(searchQQSongCandidates).mockResolvedValueOnce([qqCandidate]);
    vi.mocked(fetchSyncedLyricsVersionsForCandidates).mockResolvedValueOnce([
      {
        id: "qq:001L1lqm4UAdyo",
        candidate: qqCandidate,
        lyrics: {
          source: "qq",
          rawLrc:
            "[00:10.00]天空灰得像哭过\n[00:14.00]离开你以后并没有更自由",
          lines: [
            { id: "0-10", time: 10, text: "天空灰得像哭过" },
            { id: "1-14", time: 14, text: "离开你以后并没有更自由" },
          ],
          matchedSnippet: "天空灰得像哭过 离开你以后并没有更自由",
          matchedCandidate: qqCandidate,
        },
      },
    ] as never);

    const result = await recognizeStation({
      streamUrl: "https://example.com/live.mp3",
      stationId: "station-1",
      languageHint: "zh",
    });

    expect(searchQQSongCandidates).toHaveBeenCalledWith(result.snippets, {
      trackMetadata: null,
    });
    expect(searchNetEaseSongCandidates).not.toHaveBeenCalled();
    expect(fetchSyncedLyricsVersionsForCandidates).toHaveBeenCalledWith(
      [qqCandidate],
      result.snippets
    );
    expect(result.candidates[0]).toMatchObject({
      source: "qq",
      title: "退后",
      artist: "周杰伦",
    });
    expect(result.lyrics).toMatchObject({
      source: "qq",
      matchedCandidate: { title: "退后", artist: "周杰伦" },
    });
  });

  it("promotes the candidate that actually produced the synced lyrics", async () => {
    const wrongCandidate = {
      id: "wrong-1",
      title: "愿你余生漫长",
      artist: "王贰浪",
      source: "netease" as const,
      url: "https://music.163.com/song?id=wrong-1",
      matchedSnippet: "一句好久不见",
      confidenceScore: 0.92,
    };
    const lyricMatchedCandidate = {
      id: "right-1",
      title: "好久不见",
      artist: "陈奕迅",
      source: "netease" as const,
      url: "https://music.163.com/song?id=right-1",
      matchedSnippet: "一句好久不见",
      confidenceScore: 0.88,
    };

    vi.mocked(searchNetEaseSongCandidates).mockResolvedValueOnce([
      wrongCandidate,
      lyricMatchedCandidate,
    ]);
    vi.mocked(fetchSyncedLyricsVersionsForCandidates).mockResolvedValueOnce([
      {
        id: "netease:right-1",
        candidate: lyricMatchedCandidate,
        lyrics: {
          source: "qq",
          rawLrc: "[00:00.00]好久不见 - 陈奕迅\n[00:10.00]一句好久不见",
          lines: [
            { id: "0-0", time: 0, text: "好久不见 - 陈奕迅" },
            { id: "1-10", time: 10, text: "一句好久不见" },
          ],
          matchedSnippet: "一句好久不见",
          matchedCandidate: lyricMatchedCandidate,
        },
      },
    ] as never);

    const result = await recognizeStation({
      streamUrl: "https://example.com/live.mp3",
      stationId: "station-1",
      languageHint: "zh",
    });

    expect(result.candidates.map((candidate) => candidate.title)).toEqual([
      "好久不见",
      "愿你余生漫长",
    ]);
  });

  it("passes stream metadata into lyric candidate ranking", async () => {
    vi.mocked(fetchStreamTrackMetadata).mockResolvedValueOnce({
      rawTitle: "谭咏麟 - 一生中最爱",
      artist: "谭咏麟",
      title: "一生中最爱",
    });

    const result = await recognizeStation({
      streamUrl: "https://example.com/live.mp3",
      stationId: "station-1",
      languageHint: "zh",
    });

    expect(searchNetEaseSongCandidates).toHaveBeenCalledWith(result.snippets, {
      trackMetadata: {
        rawTitle: "谭咏麟 - 一生中最爱",
        artist: "谭咏麟",
        title: "一生中最爱",
      },
    });
    expect(result.streamMetadata).toMatchObject({ artist: "谭咏麟" });
  });

  it("retries transient capture failures before returning an error to the user", async () => {
    vi.mocked(captureStreamAudio)
      .mockRejectedValueOnce(new Error("ffmpeg_exit_255"))
      .mockResolvedValueOnce(Buffer.from("wav"));

    const result = await recognizeStation({
      streamUrl: "https://example.com/live.mp3",
      stationId: "station-1",
      languageHint: "zh",
    });

    expect(result.lyrics).toMatchObject({ source: "netease" });
    expect(captureStreamAudio).toHaveBeenCalledTimes(2);
  });

  it("retries empty ASR transcripts with a fresh audio capture", async () => {
    vi.mocked(transcribeLyricsWithOpenRouter)
      .mockRejectedValueOnce(new Error("empty_lyrics_transcript"))
      .mockResolvedValueOnce({
        text: "可以恨你 全力痛恨你",
        segments: [
          {
            text: "可以恨你 全力痛恨你",
            start: 2,
            confidence: 0.95,
          },
        ],
      });

    const result = await recognizeStation({
      streamUrl: "https://example.com/live.mp3",
      stationId: "station-1",
      languageHint: "zh",
    });

    expect(result.snippets).toHaveLength(1);
    expect(captureStreamAudio).toHaveBeenCalledTimes(2);
    expect(transcribeLyricsWithOpenRouter).toHaveBeenCalledTimes(2);
  });
});
