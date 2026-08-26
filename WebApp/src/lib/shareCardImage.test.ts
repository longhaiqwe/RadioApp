import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  createShareCardSvg,
  createShareCardSvgDataUrl,
  downloadShareCard,
  formatReleaseMemory,
  prepareShareCardData,
} from "./shareCardImage";

describe("shareCardImage", () => {
  beforeEach(() => {
    vi.unstubAllGlobals();
  });

  it("renders the iOS-style song share card as a fixed 360px SVG", () => {
    const svg = createShareCardSvg({
      title: "爱情讯息",
      artist: "郭静",
      album: "下一个天亮",
      stationName: "清晨音乐台",
      timestamp: new Date(2026, 5, 11, 10, 0),
      releaseDate: "2008-05-09",
      artworkDataUrl: "data:image/jpeg;base64,album-cover",
    });

    expect(svg).toContain('<svg width="360" height="620"');
    expect(svg).toContain("#0A0A0F");
    expect(svg).toContain("#00D9FF");
    expect(svg).toContain("#8338EC");
    expect(svg).toContain("#FF006E");
    expect(svg).toContain("爱情讯息");
    expect(svg).toContain("郭静  ·  下一个天亮");
    expect(svg).toContain("发行于 2008 · 18年前");
    expect(svg).toContain('href="data:image/jpeg;base64,album-cover"');
    expect(svg).toContain("清晨音乐台");
    expect(svg).toContain("2026.06.11 10:00");
    expect(svg).toContain("拾音FM");
    expect(svg).toContain("www.shiyinfm.cn");
    expect(svg).toContain('id="shareSiteQr"');
    expect(svg.match(/class="qrModule"/g)?.length).toBeGreaterThan(100);
  });

  it("can be embedded as a preview data url", () => {
    const dataUrl = createShareCardSvgDataUrl({
      title: "好久不见",
      artist: "陈奕迅",
      album: "认了吧",
      stationName: "清晨音乐台",
      timestamp: new Date(2026, 5, 11, 10, 0),
    });

    expect(dataUrl).toMatch(/^data:image\/svg\+xml;charset=utf-8,/);
    expect(decodeURIComponent(dataUrl)).toContain("好久不见");
  });

  it("prepares remote artwork as an embeddable data URL for previews", async () => {
    class MockFileReader {
      result = "data:image/jpg;base64,album-cover";
      onload: (() => void) | null = null;
      onerror: (() => void) | null = null;

      readAsDataURL() {
        this.onload?.();
      }
    }

    vi.stubGlobal("FileReader", MockFileReader);
    vi.stubGlobal(
      "fetch",
      vi.fn(
        async () =>
          new Response("album-cover", {
            headers: { "content-type": "image/jpg" },
          })
      )
    );

    const prepared = await prepareShareCardData({
      title: "小小的太阳",
      artist: "张宇",
      album: "月亮 太阳",
      artworkUrl:
        "https://p1.music.126.net/2SKyO_NjdYOdsmLiqUyPhQ==/109951167893538409.jpg?param=300y300",
      stationName: "两广之声音乐台",
      timestamp: new Date(2026, 5, 12, 12, 4),
    });

    expect(fetch).toHaveBeenCalledWith(
      "/api/artwork?url=https%3A%2F%2Fp1.music.126.net%2F2SKyO_NjdYOdsmLiqUyPhQ%3D%3D%2F109951167893538409.jpg%3Fparam%3D300y300"
    );
    expect(prepared.artworkDataUrl).toMatch(/^data:image\/jpg;base64,/);
    expect(createShareCardSvg(prepared)).toContain(
      'href="data:image/jpg;base64,'
    );
  });

  it("downloads the share card directly without invoking the Web Share API", async () => {
    class MockImage {
      onload: (() => void) | null = null;
      onerror: (() => void) | null = null;

      set src(_value: string) {
        this.onload?.();
      }
    }

    const share = vi.fn();
    const canShare = vi.fn(() => true);
    Object.defineProperty(navigator, "share", {
      configurable: true,
      value: share,
    });
    Object.defineProperty(navigator, "canShare", {
      configurable: true,
      value: canShare,
    });
    vi.stubGlobal("Image", MockImage);
    Object.defineProperty(URL, "createObjectURL", {
      configurable: true,
      value: vi.fn(),
    });
    Object.defineProperty(URL, "revokeObjectURL", {
      configurable: true,
      value: vi.fn(),
    });
    vi.mocked(URL.createObjectURL)
      .mockReturnValueOnce("blob:share-svg")
      .mockReturnValueOnce("blob:share-png");
    vi.spyOn(HTMLCanvasElement.prototype, "getContext").mockReturnValue({
      scale: vi.fn(),
      drawImage: vi.fn(),
    } as unknown as CanvasRenderingContext2D);
    vi.spyOn(HTMLCanvasElement.prototype, "toBlob").mockImplementation(
      (callback) => callback(new Blob(["png"], { type: "image/png" }))
    );
    const click = vi
      .spyOn(HTMLAnchorElement.prototype, "click")
      .mockImplementation(() => undefined);
    let appendedAnchor: HTMLAnchorElement | null = null;
    vi.spyOn(document.body, "append").mockImplementation((node) => {
      appendedAnchor = node as HTMLAnchorElement;
    });

    await downloadShareCard({
      title: "水手",
      artist: "郑智化",
      album: "私房歌",
      stationName: "怀集音乐台",
      timestamp: new Date(2026, 5, 12, 15, 10),
      artworkDataUrl: "data:image/jpeg;base64,cover",
    });

    expect(share).not.toHaveBeenCalled();
    expect(canShare).not.toHaveBeenCalled();
    expect(appendedAnchor?.download).toBe("水手-拾音FM.png");
    expect(appendedAnchor?.href).toBe("blob:share-png");
    expect(click).toHaveBeenCalled();
  });

  it("formats release memories using full elapsed years", () => {
    expect(
      formatReleaseMemory("2004-07-23", new Date(2026, 1, 14, 11, 46))
    ).toBe("发行于 2004 · 21年前");
    expect(
      formatReleaseMemory("2026-01-01", new Date(2026, 5, 11, 10, 0))
    ).toBe("发行于 2026 · 今年");
  });
});
