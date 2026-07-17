import { describe, expect, it } from "vitest";
import { makeMusicPlatformTargets } from "./musicPlatformLinks";

describe("musicPlatformLinks", () => {
  it("prefers NetEase app deep links for known songs and keeps a web fallback", () => {
    expect(
      makeMusicPlatformTargets({
        platform: "netease",
        songId: " 113373 ",
        title: "爱在记忆中找你",
        artist: "林峯",
      })
    ).toEqual({
      primaryHref: "orpheus://song/113373",
      fallbackHref: "https://music.163.com/#/song?id=113373",
    });
  });

  it("builds QQ Music playSonglist deep links for known song mids", () => {
    const targets = makeMusicPlatformTargets({
      platform: "qq",
      songId: "003hAqji4DQa0x",
      title: "爱在记忆中找你",
      artist: "林峯",
    });

    expect(targets?.primaryHref).toContain(
      "qqmusic://qq.com/media/playSonglist?p="
    );
    const payload = decodeURIComponent(targets?.primaryHref.split("p=")[1] ?? "");
    expect(JSON.parse(payload)).toEqual({
      song: [{ type: "0", songmid: "003hAqji4DQa0x" }],
      action: "play",
    });
    expect(targets?.fallbackHref).toBe(
      "https://y.qq.com/n/ryqq/songDetail/003hAqji4DQa0x"
    );
  });

  it("falls back to app search when a platform song id is not available", () => {
    expect(
      makeMusicPlatformTargets({
        platform: "qq",
        songId: null,
        title: "爱情讯息",
        artist: "郭静",
      })
    ).toEqual({
      primaryHref:
        "qqmusic://qq.com/ui/search?w=%E7%88%B1%E6%83%85%E8%AE%AF%E6%81%AF%20%E9%83%AD%E9%9D%99",
      fallbackHref:
        "https://y.qq.com/n/ryqq/search?w=%E7%88%B1%E6%83%85%E8%AE%AF%E6%81%AF%20%E9%83%AD%E9%9D%99",
    });
  });
});
