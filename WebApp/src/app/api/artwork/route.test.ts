import { beforeEach, describe, expect, it, vi } from "vitest";
import { GET } from "./route";

describe("/api/artwork", () => {
  beforeEach(() => {
    vi.unstubAllGlobals();
  });

  it("proxies allowlisted artwork images with cache headers", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => new Response("image-bytes", {
        headers: { "content-type": "image/jpeg" },
      }))
    );

    const response = await GET(
      new Request(
        "http://localhost/api/artwork?url=https%3A%2F%2Fp1.music.126.net%2Falbum.jpg"
      )
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe("image/jpeg");
    expect(response.headers.get("cache-control")).toContain("max-age=86400");
    expect(await response.text()).toBe("image-bytes");
    expect(fetch).toHaveBeenCalledWith(
      "https://p1.music.126.net/album.jpg?param=300y300",
      {
        headers: expect.objectContaining({ "User-Agent": expect.any(String) }),
        signal: expect.any(AbortSignal),
      }
    );
  });

  it("requests compact NetEase artwork even when the client sends the original file URL", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(
        async () =>
          new Response("image-bytes", {
            headers: { "content-type": "image/jpeg" },
          })
      )
    );

    const response = await GET(
      new Request(
        "http://localhost/api/artwork?url=https%3A%2F%2Fp1.music.126.net%2F2SKyO_NjdYOdsmLiqUyPhQ%3D%3D%2F109951167893538409.jpg"
      )
    );

    expect(response.status).toBe(200);
    expect(fetch).toHaveBeenCalledWith(
      "https://p1.music.126.net/2SKyO_NjdYOdsmLiqUyPhQ==/109951167893538409.jpg?param=300y300",
      {
        headers: expect.objectContaining({ "User-Agent": expect.any(String) }),
        signal: expect.any(AbortSignal),
      }
    );
  });

  it("upgrades allowlisted http artwork URLs before proxying them", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(
        async () =>
          new Response("image-bytes", {
            headers: { "content-type": "image/jpeg" },
          })
      )
    );

    const response = await GET(
      new Request(
        "http://localhost/api/artwork?url=http%3A%2F%2Fp1.music.126.net%2Falbum.jpg"
      )
    );

    expect(response.status).toBe(200);
    expect(fetch).toHaveBeenCalledWith(
      "https://p1.music.126.net/album.jpg?param=300y300",
      {
        headers: expect.objectContaining({ "User-Agent": expect.any(String) }),
        signal: expect.any(AbortSignal),
      }
    );
  });

  it("rejects non-artwork hosts", async () => {
    const response = await GET(
      new Request(
        "http://localhost/api/artwork?url=https%3A%2F%2Fexample.com%2Fcover.jpg"
      )
    );

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({ error: "INVALID_ARTWORK_URL" });
  });
});
