import { act, fireEvent, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { stationFixture } from "@/test/fixtures";
import { recognizeStationFromStream } from "@/lib/recognitionApi";
import Home from "./page";

class MockAudio {
  src = "";
  volume = 0.5;
  play = vi.fn(async () => undefined);
  pause = vi.fn();
  load = vi.fn();

  addEventListener() {}

  removeEventListener() {}
}

const recognizedSongResult = {
  method: "lyrics_asr" as const,
  transcript: "需要勇气来面对决心",
  snippets: [{ text: "需要勇气来面对决心", confidenceScore: 0.92 }],
  candidates: [
    {
      id: "123",
      title: "爱情讯息",
      artist: "郭静",
      album: "下一个天亮",
      source: "netease" as const,
      url: "https://music.163.com/song?id=123",
    },
  ],
  lyrics: {
    source: "qq" as const,
    rawLrc: "[00:10.00]需要勇气来面对决心",
    estimatedOffsetSeconds: 10,
    platformSongIds: { qq: "003hAqji4DQa0x", netease: "123" },
    lines: [{ id: "0-10", time: 10, text: "需要勇气来面对决心" }],
  },
};

vi.mock("@/hooks/useStations", () => ({
  useTopStations: () => ({
    data: undefined,
    error: null,
    isLoading: false,
    mutate: vi.fn(),
  }),
  useStationSearch: () => ({
    data: [],
    error: null,
    isLoading: false,
  }),
}));

vi.mock("@/lib/recognitionApi", () => ({
  recognizeStationFromStream: vi.fn(),
}));

vi.stubGlobal("Audio", vi.fn(() => new MockAudio()));

describe("Home page", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.mocked(recognizeStationFromStream).mockReset();
  });

  it("shows favorites preview on the home tab when local favorites exist", () => {
    window.localStorage.setItem(
      "radioapp:web:favorites",
      JSON.stringify([stationFixture]),
    );

    render(<Home />);

    expect(screen.getByRole("heading", { name: "你的收藏" })).toBeInTheDocument();
    expect(screen.getByText("下次回来，不用重新找。")).toBeInTheDocument();
    expect(screen.getAllByText("清晨音乐台").length).toBeGreaterThan(0);
  });

  it("renders the RadioApp web shell", () => {
    render(<Home />);

    expect(screen.getByRole("heading", { name: "发现" })).toBeInTheDocument();
    expect(screen.getByText("探索全球电台")).toBeInTheDocument();
    expect(
      screen.getByPlaceholderText("搜索电台、风格、地区...")
    ).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "推荐电台" })).toBeInTheDocument();
  });

  it("renders the morning station welcome prompt", () => {
    render(<Home />);

    const greeting = screen.getByRole("region", { name: "欢迎语" });
    expect(greeting).toHaveTextContent(
      "是缘分让我们偶遇，从「清晨音乐台」开始吧，希望你能遇到心仪的歌曲～",
    );
    expect(within(greeting).getByText("今日第一站")).toBeInTheDocument();
  });

  it("opens the playback screen immediately after selecting a station", async () => {
    const user = userEvent.setup();

    render(<Home />);

    await user.click(screen.getByRole("button", { name: "播放 清晨音乐台" }));

    const dialog = screen.getByRole("dialog", { name: "播放器" });
    expect(
      within(dialog).getByRole("heading", { name: stationFixture.name })
    ).toBeInTheDocument();
  });

  it("shows a no-results state after entering a search query with no matches", async () => {
    const user = userEvent.setup();

    render(<Home />);

    await user.type(
      screen.getByPlaceholderText("搜索电台、风格、地区..."),
      "ambient"
    );

    expect(screen.getByText("还没有找到匹配电台")).toBeInTheDocument();
    expect(
      screen.getByText("换个关键词，或者试试地区和频率。")
    ).toBeInTheDocument();
  });

  it("opens recent stations from the top-right action instead of showing them by default", async () => {
    const user = userEvent.setup();

    window.localStorage.setItem(
      "radioapp:web:recent",
      JSON.stringify([stationFixture]),
    );

    render(<Home />);

    expect(
      screen.queryByRole("heading", { name: "最近听过" }),
    ).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "查看最近听过" }));

    expect(screen.getByRole("heading", { name: "最近听过" })).toBeInTheDocument();
    expect(
      screen.getByText("刚刚路过的好声音，会先留在这里。")
    ).toBeInTheDocument();
  });

  it("ignores duplicate recognition taps while the first request is still in flight", async () => {
    const user = userEvent.setup();
    vi.mocked(recognizeStationFromStream).mockReturnValue(new Promise(() => {}));

    render(<Home />);

    await user.click(screen.getByRole("button", { name: "播放 清晨音乐台" }));

    const recognizeButton = screen.getByRole("button", { name: "识别当前歌曲" });
    await act(async () => {
      fireEvent.click(recognizeButton);
      fireEvent.click(recognizeButton);
    });

    expect(recognizeStationFromStream).toHaveBeenCalledTimes(1);
  });

  it("returns to the playback screen instead of the home page when closing a recognized song", async () => {
    const user = userEvent.setup();
    vi.mocked(recognizeStationFromStream).mockResolvedValue(recognizedSongResult);

    render(<Home />);

    await user.click(screen.getByRole("button", { name: "播放 清晨音乐台" }));
    await user.click(screen.getByRole("button", { name: "识别当前歌曲" }));

    expect(await screen.findByRole("region", { name: "识别结果" })).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /关闭/ }));

    const dialog = screen.getByRole("dialog", { name: "播放器" });
    expect(
      within(dialog).getByRole("heading", { name: stationFixture.name })
    ).toBeInTheDocument();
    expect(
      within(dialog).queryByRole("region", { name: "识别结果" })
    ).not.toBeInTheDocument();
  });
});
