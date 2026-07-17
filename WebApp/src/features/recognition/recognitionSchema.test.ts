import { describe, expect, it } from "vitest";
import { parseRecognitionRequest } from "./recognitionSchema";

describe("parseRecognitionRequest", () => {
  it("accepts a playable stream URL and trims optional station metadata", () => {
    const result = parseRecognitionRequest({
      streamUrl: " https://example.com/live.mp3 ",
      stationId: " cnr-3 ",
      stationName: " 音乐之声 ",
      languageHint: " zh-Hans ",
    });

    expect(result).toEqual({
      ok: true,
      value: {
        streamUrl: "https://example.com/live.mp3",
        stationId: "cnr-3",
        stationName: "音乐之声",
        languageHint: "zh",
      },
    });
  });

  it("rejects missing or unsafe stream URLs", () => {
    expect(parseRecognitionRequest({ streamUrl: "" })).toEqual({
      ok: false,
      error: "请选择正在播放的电台后再识别。",
    });

    expect(parseRecognitionRequest({ streamUrl: "file:///tmp/song.wav" })).toEqual({
      ok: false,
      error: "当前电台地址无法用于识别。",
    });
  });
});
