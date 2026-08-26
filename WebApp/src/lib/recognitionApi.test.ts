import { stationFixture } from "@/test/fixtures";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { recognizeStationFromStream } from "./recognitionApi";

describe("recognizeStationFromStream", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it("posts the current station stream URL and metadata", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          method: "lyrics_asr",
          transcript: "我怀念的是无话不说",
          snippets: [],
          candidates: [],
        })
      )
    );

    await recognizeStationFromStream(stationFixture);

    expect(fetchSpy).toHaveBeenCalledWith(
      "/api/recognize",
      expect.objectContaining({
        method: "POST",
        headers: { "Content-Type": "application/json" },
      })
    );
    expect(JSON.parse(String(fetchSpy.mock.calls[0]?.[1]?.body))).toEqual({
      streamUrl: stationFixture.urlResolved,
      stationId: stationFixture.id,
      stationName: stationFixture.name,
      languageHint: "zh",
    });
  });

  it("throws the server error message when recognition fails", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ error: "暂时没听清歌词" }), { status: 502 })
    );

    await expect(recognizeStationFromStream(stationFixture)).rejects.toThrow(
      "暂时没听清歌词"
    );
  });
});
