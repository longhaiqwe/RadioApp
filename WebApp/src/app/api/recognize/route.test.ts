import { recognizeStation } from "@/server/recognitionService";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { POST } from "./route";

vi.mock("@/server/recognitionService", () => ({
  recognizeStation: vi.fn(),
}));

async function readJson(response: Response) {
  return response.json() as Promise<unknown>;
}

describe("/api/recognize", () => {
  beforeEach(() => {
    vi.mocked(recognizeStation).mockClear();
  });

  it("keeps web recognition disabled and points users to the macOS app", async () => {
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

    expect(response.status).toBe(410);
    expect(await readJson(response)).toEqual({
      error: "Web 版暂不提供听歌识曲，请下载 macOS 客户端使用完整识曲。",
      downloadUrl:
        "https://longhaixueai-1258687935.cos.ap-guangzhou.myqcloud.com/downloads/ShiyinFM-0.1.6-build7-universal.dmg",
    });
    expect(recognizeStation).not.toHaveBeenCalled();
  });
});
