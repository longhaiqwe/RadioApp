import { describe, expect, it } from "vitest";
import nextConfig from "../../next.config";

describe("next config", () => {
  it("blocks insecure remote image loads", async () => {
    const headers = await nextConfig.headers?.();

    expect(headers).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          source: "/:path*",
          headers: expect.arrayContaining([
            expect.objectContaining({
              key: "Content-Security-Policy",
              value: expect.stringContaining("img-src 'self' https: data: blob:"),
            }),
          ]),
        }),
      ]),
    );
  });
});
