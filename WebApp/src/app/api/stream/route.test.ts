import { beforeEach, describe, expect, it, vi } from "vitest";
import { transcodeStreamToMp3 } from "@/server/audioTranscode";
import { GET } from "./route";

vi.mock("@/server/audioTranscode", () => ({
  transcodeStreamToMp3: vi.fn(() => {
    const encoder = new TextEncoder();
    return new ReadableStream({
      start(controller) {
        controller.enqueue(encoder.encode("mp3-bytes"));
        controller.close();
      },
    });
  }),
}));

describe("/api/stream", () => {
  beforeEach(() => {
    vi.unstubAllGlobals();
    vi.mocked(transcodeStreamToMp3).mockClear();
  });

  it("proxies public audio streams without injecting ICY metadata into browser playback", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(
        async () =>
          new Response("audio-bytes", {
            headers: {
              "content-type": "audio/aacp",
              "icy-name": "AsiaFM HD",
              "icy-metaint": "16000",
            },
          })
      )
    );

    const source = "http://asiafm.hk:8000/asiahd";
    const response = await GET(
      new Request(`http://localhost/api/stream?url=${encodeURIComponent(source)}`)
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe("audio/aacp");
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(response.headers.get("icy-name")).toBe("AsiaFM HD");
    expect(response.headers.get("icy-metaint")).toBeNull();
    expect(await response.text()).toBe("audio-bytes");
    const [, init] = vi.mocked(fetch).mock.calls[0] ?? [];
    const headers = init?.headers as Record<string, string>;
    expect(headers.Accept).toContain("audio/*");
    expect(headers["User-Agent"]).toEqual(expect.any(String));
    expect(headers).not.toHaveProperty("Icy-MetaData");
  });

  it("forwards browser range requests to the upstream stream", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(
        async () =>
          new Response("partial-audio", {
            status: 206,
            headers: {
              "content-type": "audio/mpeg",
              "content-range": "bytes 0-1023/*",
            },
          })
      )
    );

    const source = "http://example.com/live.mp3";
    const response = await GET(
      {
        url: `http://localhost/api/stream?url=${encodeURIComponent(source)}`,
        headers: {
          get: (name: string) =>
            name.toLowerCase() === "range" ? "bytes=0-1023" : null,
        },
      } as Request
    );

    expect(response.status).toBe(206);
    expect(response.headers.get("content-range")).toBe("bytes 0-1023/*");
    const [, init] = vi.mocked(fetch).mock.calls[0] ?? [];
    const headers = init?.headers as Record<string, string>;
    expect(fetch).toHaveBeenCalledWith(source, {
      headers: expect.objectContaining({
        Range: "bytes=0-1023",
      }),
      signal: expect.any(AbortSignal),
      cache: "no-store",
    });
    expect(headers.Range).toBe("bytes=0-1023");
  });

  it("rejects local stream targets", async () => {
    const response = await GET(
      new Request(
        "http://localhost/api/stream?url=http%3A%2F%2Flocalhost%3A8000%2Flive"
      )
    );

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "INVALID_STREAM_URL" });
  });

  it("rejects non-audio upstream responses", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(
        async () =>
          new Response("<html></html>", {
            headers: { "content-type": "text/html; charset=utf-8" },
          })
      )
    );

    const source = "http://example.com/not-a-stream";
    const response = await GET(
      new Request(`http://localhost/api/stream?url=${encodeURIComponent(source)}`)
    );

    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: "STREAM_FETCH_FAILED" });
  });

  it("transcodes requested streams to browser-playable MP3", async () => {
    vi.stubGlobal("fetch", vi.fn());

    const source = "http://asiafm.hk:8000/asiahd";
    const response = await GET(
      new Request(
        `http://localhost/api/stream?url=${encodeURIComponent(source)}&transcode=mp3`
      )
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe("audio/mpeg");
    expect(response.headers.get("cache-control")).toBe("no-store");
    expect(await response.text()).toBe("mp3-bytes");
    expect(fetch).not.toHaveBeenCalled();
    expect(transcodeStreamToMp3).toHaveBeenCalledWith({
      streamUrl: source,
      signal: expect.any(AbortSignal),
    });
  });
});
