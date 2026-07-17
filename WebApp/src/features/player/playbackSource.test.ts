import { describe, expect, it } from "vitest";
import { stationFixture } from "@/test/fixtures";
import { resolvePlaybackSource } from "./playbackSource";

describe("resolvePlaybackSource", () => {
  it("routes generic insecure station streams through the same-origin stream proxy", () => {
    const source = "http://example.com/radio.mp3";

    expect(
      resolvePlaybackSource({
        ...stationFixture,
        url: source,
        urlResolved: source,
      })
    ).toBe(`/api/stream?url=${encodeURIComponent(source)}`);
  });

  it("upgrades verified Qingting MP3 streams to HTTPS instead of proxying them", () => {
    expect(resolvePlaybackSource(stationFixture)).toBe(
      "https://lhttp.qingting.fm/live/4915/64k.mp3"
    );
  });

  it("keeps secure station streams direct", () => {
    expect(
      resolvePlaybackSource({
        ...stationFixture,
        url: "https://example.com/radio.mp3",
        urlResolved: "https://example.com/radio.mp3",
      })
    ).toBe("https://example.com/radio.mp3");
  });

  it("requests MP3 transcoding for AAC+ streams that browsers commonly reject", () => {
    const source = "http://asiafm.hk:8000/asiahd";

    expect(
      resolvePlaybackSource({
        ...stationFixture,
        codec: "AAC+",
        url: source,
        urlResolved: source,
      })
    ).toBe(`/api/stream?url=${encodeURIComponent(source)}&transcode=mp3`);
  });

  it("requests MP3 transcoding for HLS streams on the HTML audio path", () => {
    const source = "https://example.com/live/index.m3u8";

    expect(
      resolvePlaybackSource({
        ...stationFixture,
        codec: "UNKNOWN",
        hls: 1,
        url: source,
        urlResolved: source,
      })
    ).toBe(`/api/stream?url=${encodeURIComponent(source)}&transcode=mp3`);
  });
});
