import { recognizeStation } from "@/server/recognitionService";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { POST } from "./route";

vi.mock("@/server/recognitionService", () => ({
  recognizeStation: vi.fn(async () => ({
    method: "lyrics_asr",
    transcript: "我怀念的是无话不说",
    snippets: [{ text: "我怀念的是无话不说", confidenceScore: 0.83 }],
    candidates: [
      {
        id: "123",
        title: "我怀念的",
        artist: "孙燕姿",
        source: "netease",
        url: "https://music.163.com/song?id=123",
        matchedSnippet: "我怀念的是无话不说",
        confidenceScore: 0.83,
      },
    ],
  })),
}));

async function readJson(response: Response) {
  return response.json() as Promise<unknown>;
}

describe("/api/recognize", () => {
  beforeEach(() => {
    vi.mocked(recognizeStation).mockClear();
  });

  it("validates request body before starting recognition", async () => {
    const response = await POST(
      new Request("http://localhost/api/recognize", {
        method: "POST",
        body: JSON.stringify({ streamUrl: "" }),
      })
    );

    expect(response.status).toBe(400);
    expect(await readJson(response)).toEqual({
      error: "请选择正在播放的电台后再识别。",
    });
    expect(recognizeStation).not.toHaveBeenCalled();
  });

  it("returns lyric recognition results for valid stream URLs", async () => {
    const response = await POST(
      new Request("http://localhost/api/recognize", {
        method: "POST",
        body: JSON.stringify({
          streamUrl: "https://example.com/live.mp3",
          stationId: "station-1",
          stationName: "音乐之声",
        }),
      })
    );

    expect(response.status).toBe(200);
    expect(await readJson(response)).toMatchObject({
      method: "lyrics_asr",
      transcript: "我怀念的是无话不说",
      candidates: [{ title: "我怀念的", artist: "孙燕姿" }],
    });
    expect(recognizeStation).toHaveBeenCalledWith({
      streamUrl: "https://example.com/live.mp3",
      stationId: "station-1",
      stationName: "音乐之声",
      languageHint: undefined,
    });
  });

  it("returns a safe error when recognition fails", async () => {
    vi.mocked(recognizeStation).mockRejectedValue(new Error("secret detail"));

    const response = await POST(
      new Request("http://localhost/api/recognize", {
        method: "POST",
        body: JSON.stringify({ streamUrl: "https://example.com/live.mp3" }),
      })
    );

    expect(response.status).toBe(502);
    expect(await readJson(response)).toEqual({
      error: "暂时没能识别出歌词，请换一段人声更清楚的位置再试。",
    });
  });
});
