import { describe, expect, it } from "vitest";
import manifest from "./manifest";

describe("web app manifest", () => {
  it("uses installable app icons that match the native desktop icon", () => {
    const appManifest = manifest();

    expect(appManifest.name).toBe("拾音 FM");
    expect(appManifest.short_name).toBe("拾音 FM");
    expect(appManifest.display).toBe("standalone");
    expect(appManifest.background_color).toBe("#0a0a0f");
    expect(appManifest.theme_color).toBe("#0a0a0f");
    expect(appManifest.icons).toEqual(
      expect.arrayContaining([
        {
          src: "/icons/shiyin-icon-192.png",
          sizes: "192x192",
          type: "image/png",
          purpose: "any",
        },
        {
          src: "/icons/shiyin-icon-512.png",
          sizes: "512x512",
          type: "image/png",
          purpose: "any",
        },
        {
          src: "/icons/shiyin-maskable-512.png",
          sizes: "512x512",
          type: "image/png",
          purpose: "maskable",
        },
      ])
    );
  });
});
