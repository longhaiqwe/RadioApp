import { fireEvent, render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  AudioPlayerProvider,
  useAudioPlayer,
} from "@/features/player/AudioPlayerProvider";
import {
  downloadShareCard,
  prepareShareCardData,
  shareOrDownloadShareCard,
} from "@/lib/shareCardImage";
import { secondStationFixture, stationFixture } from "@/test/fixtures";
import { PlayerPanel } from "./PlayerPanel";

vi.mock("@/lib/shareCardImage", async () => {
  const actual = await vi.importActual<typeof import("@/lib/shareCardImage")>(
    "@/lib/shareCardImage"
  );

  return {
    ...actual,
    createShareCardSvgDataUrl: vi.fn(
      (data: Parameters<typeof actual.createShareCardSvgDataUrl>[0]) =>
        `data:image/svg+xml;charset=utf-8,${encodeURIComponent(
          data.artworkDataUrl ? "<svg>artwork</svg>" : "<svg>fallback</svg>"
        )}`
    ),
    prepareShareCardData: vi.fn(
      async (data: Parameters<typeof actual.prepareShareCardData>[0]) => data
    ),
    downloadShareCard: vi.fn(async () => undefined),
    shareOrDownloadShareCard: vi.fn(async () => undefined),
  };
});

class MockAudio {
  src = "";
  volume = 0.5;
  play = vi.fn(async () => undefined);
  pause = vi.fn();
  load = vi.fn();

  addEventListener() {}

  removeEventListener() {}
}

const idleRecognition = {
  status: "idle" as const,
  result: null,
  error: null,
};

const successRecognition = {
  status: "success" as const,
  error: null,
  startedAt: Date.parse("2026-06-11T10:00:00.000Z"),
  result: {
    method: "lyrics_asr" as const,
    transcript: "需要勇气来面对决心 写下不管多少时间我会等你",
    snippets: [
      {
        text: "需要勇气来面对决心",
        confidenceScore: 0.92,
      },
    ],
    candidates: [
      {
        id: "123",
        title: "爱情讯息",
        artist: "郭静",
        album: "下一个天亮",
        artworkUrl: "https://p1.music.126.net/love-message.jpg",
        releaseDate: "2008-05-09",
        source: "netease" as const,
        url: "https://music.163.com/song?id=123",
      },
    ],
    lyrics: {
      source: "qq" as const,
      rawLrc:
        "[00:10.00]需要勇气来面对决心\n[00:18.00]写下不管多少时间我会等你",
      estimatedOffsetSeconds: 10,
      platformSongIds: { qq: "003hAqji4DQa0x", netease: "123" },
      lines: [
        { id: "0-10", time: 10, text: "需要勇气来面对决心" },
        { id: "1-18", time: 18, text: "写下不管多少时间我会等你" },
      ],
    },
  },
};

const mismatchedRecognition = {
  ...successRecognition,
  result: {
    ...successRecognition.result,
    candidates: [
      {
        id: "wrong-1",
        title: "愿你余生漫长",
        artist: "王贰浪",
        album: "愿你余生漫长",
        source: "netease" as const,
        url: "https://music.163.com/song?id=wrong-1",
      },
      {
        id: "right-1",
        title: "好久不见",
        artist: "陈奕迅",
        album: "认了吧",
        source: "netease" as const,
        url: "https://music.163.com/song?id=right-1",
      },
    ],
    lyrics: {
      ...successRecognition.result.lyrics,
      matchedCandidate: {
        id: "right-1",
        title: "好久不见",
        artist: "陈奕迅",
        album: "认了吧",
        source: "netease" as const,
        url: "https://music.163.com/song?id=right-1",
      },
    },
  },
};

const ambiguousRecognition = {
  ...successRecognition,
  result: {
    ...successRecognition.result,
    candidates: [
      {
        id: "200",
        title: "一生中最爱",
        artist: "李健",
        album: "我是歌手",
        source: "netease" as const,
        url: "https://music.163.com/song?id=200",
      },
      {
        id: "100",
        title: "一生中最爱",
        artist: "谭咏麟",
        album: "神话1991",
        source: "netease" as const,
        url: "https://music.163.com/song?id=100",
      },
    ],
    lyrics: {
      ...successRecognition.result.lyrics,
      rawLrc: "[00:10.00]如果痴痴的等某日\n[00:18.00]李健版本",
      matchedCandidate: {
        id: "200",
        title: "一生中最爱",
        artist: "李健",
        album: "我是歌手",
        source: "netease" as const,
        url: "https://music.163.com/song?id=200",
      },
      platformSongIds: { netease: "200" },
      lines: [
        { id: "0-10", time: 10, text: "如果痴痴的等某日" },
        { id: "1-18", time: 18, text: "李健版本" },
      ],
    },
    versions: [
      {
        id: "netease:200",
        candidate: {
          id: "200",
          title: "一生中最爱",
          artist: "李健",
          album: "我是歌手",
          source: "netease" as const,
          url: "https://music.163.com/song?id=200",
        },
        lyrics: {
          ...successRecognition.result.lyrics,
          rawLrc: "[00:10.00]如果痴痴的等某日\n[00:18.00]李健版本",
          matchedCandidate: {
            id: "200",
            title: "一生中最爱",
            artist: "李健",
            album: "我是歌手",
            source: "netease" as const,
            url: "https://music.163.com/song?id=200",
          },
          platformSongIds: { netease: "200" },
          lines: [
            { id: "0-10", time: 10, text: "如果痴痴的等某日" },
            { id: "1-18", time: 18, text: "李健版本" },
          ],
        },
      },
      {
        id: "netease:100",
        candidate: {
          id: "100",
          title: "一生中最爱",
          artist: "谭咏麟",
          album: "神话1991",
          source: "netease" as const,
          url: "https://music.163.com/song?id=100",
        },
        lyrics: {
          ...successRecognition.result.lyrics,
          rawLrc: "[00:10.00]如果痴痴的等某日\n[00:18.00]谭咏麟版本",
          matchedCandidate: {
            id: "100",
            title: "一生中最爱",
            artist: "谭咏麟",
            album: "神话1991",
            source: "netease" as const,
            url: "https://music.163.com/song?id=100",
          },
          platformSongIds: { netease: "100" },
          lines: [
            { id: "0-10", time: 10, text: "如果痴痴的等某日" },
            { id: "1-18", time: 18, text: "谭咏麟版本" },
          ],
        },
      },
    ],
  },
};

const qqCorrectedRecognition = {
  ...successRecognition,
  result: {
    ...successRecognition.result,
    candidates: [
      {
        id: "wrong-net-ease-id",
        title: "庙堂之外",
        artist: "说晚安",
        album: "陈楚生南京演唱会",
        source: "netease" as const,
        url: "https://music.163.com/song?id=wrong-net-ease-id",
      },
    ],
    lyrics: {
      ...successRecognition.result.lyrics,
      source: "qq" as const,
      rawLrc:
        "[00:10.00]庙堂之外《长安的荔枝》电影片尾曲 - 陈楚生\n[00:20.00]万家灯火映山河",
      platformSongIds: { qq: "004TempleSong" },
      matchedCandidate: {
        id: "004TempleSong",
        title: "庙堂之外",
        artist: "陈楚生",
        album: "长安的荔枝原声带",
        source: "qq" as const,
        url: "https://y.qq.com/n/ryqq/songDetail/004TempleSong",
      },
      lines: [
        {
          id: "0-10",
          time: 10,
          text: "庙堂之外《长安的荔枝》电影片尾曲 - 陈楚生",
        },
        { id: "1-20", time: 20, text: "万家灯火映山河" },
      ],
    },
    versions: [
      {
        id: "qq:004TempleSong",
        candidate: {
          id: "004TempleSong",
          title: "庙堂之外",
          artist: "陈楚生",
          album: "长安的荔枝原声带",
          source: "qq" as const,
          url: "https://y.qq.com/n/ryqq/songDetail/004TempleSong",
        },
        lyrics: {
          ...successRecognition.result.lyrics,
          source: "qq" as const,
          rawLrc:
            "[00:10.00]庙堂之外《长安的荔枝》电影片尾曲 - 陈楚生\n[00:20.00]万家灯火映山河",
          platformSongIds: { qq: "004TempleSong" },
          matchedCandidate: {
            id: "004TempleSong",
            title: "庙堂之外",
            artist: "陈楚生",
            album: "长安的荔枝原声带",
            source: "qq" as const,
            url: "https://y.qq.com/n/ryqq/songDetail/004TempleSong",
          },
          lines: [
            {
              id: "0-10",
              time: 10,
              text: "庙堂之外《长安的荔枝》电影片尾曲 - 陈楚生",
            },
            { id: "1-20", time: 20, text: "万家灯火映山河" },
          ],
        },
      },
    ],
  },
};

const metadataFallbackRecognition = {
  ...successRecognition,
  result: {
    ...successRecognition.result,
    candidates: [
      {
        id: "003bt5481j67sO",
        title: "好眼泪坏眼泪",
        artist: "徐若瑄",
        album: "最爱是V 新歌+精选",
        artworkUrl:
          "https://y.gtimg.cn/music/photo_new/T002R300x300M000001Xa4Lr23COxH.jpg?max_age=2592000",
        releaseDate: "2007-02-14",
        source: "qq" as const,
        url: "https://y.qq.com/n/ryqq/songDetail/003bt5481j67sO",
      },
    ],
    lyrics: {
      ...successRecognition.result.lyrics,
      source: "qq" as const,
      rawLrc: "[00:10.00]眼泪是因为你的爱\n[00:18.00]还是因为你离开",
      matchedCandidate: {
        id: "003bt5481j67sO",
        title: "好眼泪坏眼泪",
        artist: "徐若瑄",
        album: "最爱是V 新歌+精选",
        artworkUrl:
          "https://y.gtimg.cn/music/photo_new/T002R300x300M000001Xa4Lr23COxH.jpg?max_age=2592000",
        source: "qq" as const,
        url: "https://y.qq.com/n/ryqq/songDetail/003bt5481j67sO",
      },
      platformSongIds: { qq: "003bt5481j67sO" },
      lines: [
        { id: "0-10", time: 10, text: "眼泪是因为你的爱" },
        { id: "1-18", time: 18, text: "还是因为你离开" },
      ],
    },
    versions: [
      {
        id: "qq:003bt5481j67sO",
        candidate: {
          id: "003bt5481j67sO",
          title: "好眼泪坏眼泪",
          artist: "徐若瑄",
          album: "最爱是V 新歌+精选",
          artworkUrl:
            "https://y.gtimg.cn/music/photo_new/T002R300x300M000001Xa4Lr23COxH.jpg?max_age=2592000",
          source: "qq" as const,
          url: "https://y.qq.com/n/ryqq/songDetail/003bt5481j67sO",
        },
        lyrics: {
          ...successRecognition.result.lyrics,
          source: "qq" as const,
          rawLrc: "[00:10.00]眼泪是因为你的爱\n[00:18.00]还是因为你离开",
          matchedCandidate: {
            id: "003bt5481j67sO",
            title: "好眼泪坏眼泪",
            artist: "徐若瑄",
            album: "最爱是V 新歌+精选",
            artworkUrl:
              "https://y.gtimg.cn/music/photo_new/T002R300x300M000001Xa4Lr23COxH.jpg?max_age=2592000",
            source: "qq" as const,
            url: "https://y.qq.com/n/ryqq/songDetail/003bt5481j67sO",
          },
          platformSongIds: { qq: "003bt5481j67sO" },
          lines: [
            { id: "0-10", time: 10, text: "眼泪是因为你的爱" },
            { id: "1-18", time: 18, text: "还是因为你离开" },
          ],
        },
      },
    ],
  },
};

const artworkFallbackRecognition = {
  ...successRecognition,
  result: {
    ...successRecognition.result,
    candidates: [
      {
        id: "383073",
        title: "我很想爱他",
        artist: "Twins",
        album: "八十块环游世界",
        artworkUrl:
          "https://p2.music.126.net/Y4g2s63o5MNqlFb-17X2IQ==/109951170340575525.jpg?param=300y300",
        releaseDate: "2006-06-15",
        source: "netease" as const,
        url: "https://music.163.com/song?id=383073",
      },
    ],
    lyrics: {
      ...successRecognition.result.lyrics,
      source: "netease" as const,
      rawLrc: "[00:10.00]我很想爱他\n[00:18.00]但是眼睛在说谎",
      matchedCandidate: {
        id: "383073",
        title: "我很想爱他",
        artist: "Twins",
        album: "八十块环游世界",
        releaseDate: "2006-06-15",
        source: "netease" as const,
        url: "https://music.163.com/song?id=383073",
      },
      platformSongIds: { netease: "383073" },
      lines: [
        { id: "0-10", time: 10, text: "我很想爱他" },
        { id: "1-18", time: 18, text: "但是眼睛在说谎" },
      ],
    },
    versions: [
      {
        id: "netease:383073",
        candidate: {
          id: "383073",
          title: "我很想爱他",
          artist: "Twins",
          album: "八十块环游世界",
          releaseDate: "2006-06-15",
          source: "netease" as const,
          url: "https://music.163.com/song?id=383073",
        },
        lyrics: {
          ...successRecognition.result.lyrics,
          source: "netease" as const,
          rawLrc: "[00:10.00]我很想爱他\n[00:18.00]但是眼睛在说谎",
          matchedCandidate: {
            id: "383073",
            title: "我很想爱他",
            artist: "Twins",
            album: "八十块环游世界",
            releaseDate: "2006-06-15",
            source: "netease" as const,
            url: "https://music.163.com/song?id=383073",
          },
          platformSongIds: { netease: "383073" },
          lines: [
            { id: "0-10", time: 10, text: "我很想爱他" },
            { id: "1-18", time: 18, text: "但是眼睛在说谎" },
          ],
        },
      },
    ],
  },
};

const loadingRecognition = {
  status: "loading" as const,
  result: null,
  error: null,
};

function PlayerPanelHarness() {
  const { playStation, setExpanded } = useAudioPlayer();

  return (
    <>
      <button
        type="button"
        onClick={() => {
          playStation(stationFixture, [stationFixture, secondStationFixture], "发现");
          setExpanded(true);
        }}
      >
        打开测试播放器
      </button>
      <PlayerPanel
        isFavorite={false}
        onToggleFavorite={vi.fn()}
        recognition={idleRecognition}
        onRecognize={vi.fn()}
        onDismissRecognition={vi.fn()}
      />
    </>
  );
}

function LoadingPlayerPanelHarness() {
  const { playStation, setExpanded } = useAudioPlayer();

  return (
    <>
      <button
        type="button"
        onClick={() => {
          playStation(stationFixture, [stationFixture], "发现");
          setExpanded(true);
        }}
      >
        打开识别中播放器
      </button>
      <PlayerPanel
        isFavorite={false}
        onToggleFavorite={vi.fn()}
        recognition={loadingRecognition}
        onRecognize={vi.fn()}
        onDismissRecognition={vi.fn()}
      />
    </>
  );
}

function RecognizedPlayerPanelHarness() {
  const { playStation, setExpanded } = useAudioPlayer();

  return (
    <>
      <button
        type="button"
        onClick={() => {
          playStation(stationFixture, [stationFixture], "发现");
          setExpanded(true);
        }}
      >
        打开识别后播放器
      </button>
      <PlayerPanel
        isFavorite={false}
        onToggleFavorite={vi.fn()}
        recognition={successRecognition}
        onRecognize={vi.fn()}
        onDismissRecognition={vi.fn()}
      />
    </>
  );
}

function MismatchedRecognizedPlayerPanelHarness() {
  const { playStation, setExpanded } = useAudioPlayer();

  return (
    <>
      <button
        type="button"
        onClick={() => {
          playStation(stationFixture, [stationFixture], "发现");
          setExpanded(true);
        }}
      >
        打开错配识别播放器
      </button>
      <PlayerPanel
        isFavorite={false}
        onToggleFavorite={vi.fn()}
        recognition={mismatchedRecognition}
        onRecognize={vi.fn()}
        onDismissRecognition={vi.fn()}
      />
    </>
  );
}

function AmbiguousRecognizedPlayerPanelHarness() {
  const { playStation, setExpanded } = useAudioPlayer();

  return (
    <>
      <button
        type="button"
        onClick={() => {
          playStation(stationFixture, [stationFixture], "发现");
          setExpanded(true);
        }}
      >
        打开多版本识别播放器
      </button>
      <PlayerPanel
        isFavorite={false}
        onToggleFavorite={vi.fn()}
        recognition={ambiguousRecognition}
        onRecognize={vi.fn()}
        onDismissRecognition={vi.fn()}
      />
    </>
  );
}

function QQCorrectedRecognizedPlayerPanelHarness() {
  const { playStation, setExpanded } = useAudioPlayer();

  return (
    <>
      <button
        type="button"
        onClick={() => {
          playStation(stationFixture, [stationFixture], "发现");
          setExpanded(true);
        }}
      >
        打开QQ修正识别播放器
      </button>
      <PlayerPanel
        isFavorite={false}
        onToggleFavorite={vi.fn()}
        recognition={qqCorrectedRecognition}
        onRecognize={vi.fn()}
        onDismissRecognition={vi.fn()}
      />
    </>
  );
}

function MetadataFallbackRecognizedPlayerPanelHarness() {
  const { playStation, setExpanded } = useAudioPlayer();

  return (
    <>
      <button
        type="button"
        onClick={() => {
          playStation(stationFixture, [stationFixture], "发现");
          setExpanded(true);
        }}
      >
        打开元数据补全播放器
      </button>
      <PlayerPanel
        isFavorite={false}
        onToggleFavorite={vi.fn()}
        recognition={metadataFallbackRecognition}
        onRecognize={vi.fn()}
        onDismissRecognition={vi.fn()}
      />
    </>
  );
}

function ArtworkFallbackRecognizedPlayerPanelHarness() {
  const { playStation, setExpanded } = useAudioPlayer();

  return (
    <>
      <button
        type="button"
        onClick={() => {
          playStation(stationFixture, [stationFixture], "发现");
          setExpanded(true);
        }}
      >
        打开封面补全播放器
      </button>
      <PlayerPanel
        isFavorite={false}
        onToggleFavorite={vi.fn()}
        recognition={artworkFallbackRecognition}
        onRecognize={vi.fn()}
        onDismissRecognition={vi.fn()}
      />
    </>
  );
}

describe("PlayerPanel", () => {
  beforeEach(() => {
    vi.stubGlobal("Audio", vi.fn(() => new MockAudio()));
    vi.mocked(prepareShareCardData).mockClear();
    vi.mocked(prepareShareCardData).mockImplementation(async (data) => data);
    vi.mocked(downloadShareCard).mockClear();
    vi.mocked(shareOrDownloadShareCard).mockClear();
  });

  afterEach(() => {
    document.body.style.overflow = "";
    document.documentElement.style.overflow = "";
  });

  it("matches the iOS player layout with recognition on top and playback controls in one row", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <PlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开测试播放器" }));

    expect(screen.getByRole("button", { name: "歌曲识别" })).toBeInTheDocument();

    const controls = screen.getByRole("group", { name: "播放控制" });
    expect(within(controls).getByRole("button", { name: "收藏" })).toBeInTheDocument();
    expect(within(controls).getByRole("button", { name: "上一台" })).toBeInTheDocument();
    expect(within(controls).getByRole("button", { name: "播放" })).toBeInTheDocument();
    expect(within(controls).getByRole("button", { name: "下一台" })).toBeInTheDocument();
    expect(
      within(controls).getByRole("button", { name: "查看播放列表" })
    ).toBeInTheDocument();
    expect(
      within(controls).queryByRole("button", { name: "歌曲识别" })
    ).not.toBeInTheDocument();
  });

  it("opens the current station list from the list button and plays a selected station", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <PlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开测试播放器" }));
    await user.click(screen.getByRole("button", { name: "查看播放列表" }));

    const dialog = screen.getByRole("dialog", { name: "播放列表" });
    expect(within(dialog).getByRole("heading", { name: "发现" })).toBeInTheDocument();
    expect(
      within(dialog).getByRole("button", { name: /清晨音乐台/ })
    ).toHaveAttribute("aria-current", "true");
    expect(
      within(dialog).getByRole("button", { name: /CNR-3 音乐之声/ })
    ).toBeInTheDocument();

    await user.click(within(dialog).getByRole("button", { name: /CNR-3 音乐之声/ }));

    expect(screen.queryByRole("dialog", { name: "播放列表" })).not.toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "CNR-3 音乐之声" })).toBeInTheDocument();
  });

  it("keeps the regular playback typography compact like the station list", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <PlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开测试播放器" }));

    expect(screen.getByText("歌曲识别")).toHaveClass("text-base");
    expect(screen.getByText("选取歌词清晰片段开始识别")).toHaveClass(
      "text-[11px]"
    );
    expect(screen.getByRole("heading", { name: stationFixture.name })).toHaveClass(
      "text-xl",
      "sm:text-2xl"
    );
    expect(screen.getByText(stationFixture.tags)).toHaveClass(
      "text-xs",
      "sm:text-sm"
    );
    expect(screen.getByRole("button", { name: "播放" })).toHaveClass(
      "h-20",
      "w-20"
    );
  });

  it("locks page scroll while the playback screen is open so desktop content stays centered", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <PlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开测试播放器" }));

    expect(document.body.style.overflow).toBe("hidden");
    expect(document.documentElement.style.overflow).toBe("hidden");

    await user.click(screen.getByRole("button", { name: "关闭播放器" }));

    expect(document.body.style.overflow).toBe("");
    expect(document.documentElement.style.overflow).toBe("");
  });

  it("places recognized song, platform links, synced lyrics, and playback controls in the iOS result order", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <RecognizedPlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开识别后播放器" }));

    const result = screen.getByRole("region", { name: "识别结果" });
    const platforms = screen.getByRole("group", { name: "音乐平台" });
    const lyrics = screen.getByRole("region", { name: "同步歌词" });
    const controls = screen.getByRole("group", { name: "播放控制" });

    expect(within(result).getByRole("heading", { name: "爱情讯息" })).toHaveClass(
      "text-base",
      "sm:text-lg"
    );
    expect(within(result).getByText(/郭静/)).toHaveClass("text-[11px]", "sm:text-xs");
    expect(within(result).getByText("发行于 2008 · 18年前")).toHaveClass(
      "text-[10px]",
      "sm:text-[11px]"
    );
    expect(
      within(result).getByRole("img", { name: "爱情讯息封面" })
    ).toBeInTheDocument();
    expect(
      within(result).queryByText(successRecognition.result.transcript)
    ).not.toBeInTheDocument();
    expect(
      within(result).getByRole("button", { name: "生成分享图" })
    ).toBeInTheDocument();
    expect(within(platforms).getByRole("link", { name: "网易云音乐" })).toHaveAttribute(
      "href",
      "orpheus://song/123"
    );
    const qqHref =
      within(platforms).getByRole("link", { name: "QQ音乐" }).getAttribute("href") ??
      "";
    expect(qqHref).toContain("qqmusic://qq.com/media/playSonglist?p=");
    expect(decodeURIComponent(qqHref)).toContain("003hAqji4DQa0x");
    expect(
      decodeURIComponent(
        within(platforms)
          .getByRole("img", { name: "网易云音乐图标" })
          .getAttribute("src") ?? ""
      )
    ).toContain("/platform-icons/netease-music.png");
    expect(
      decodeURIComponent(
        within(platforms)
          .getByRole("img", { name: "QQ音乐图标" })
          .getAttribute("src") ?? ""
      )
    ).toContain("/platform-icons/qq-music.png");
    expect(within(platforms).getByRole("link", { name: "Apple Music" })).toHaveClass(
      "h-11",
      "w-11",
      "sm:h-12",
      "sm:w-12"
    );
    expect(
      within(platforms).getByRole("img", { name: "Apple Music图标" })
    ).toHaveClass("h-full", "w-full");
    expect(
      within(platforms).getByRole("img", { name: "网易云音乐图标" })
    ).toHaveClass("scale-[1.18]");
    expect(within(platforms).getByRole("img", { name: "QQ音乐图标" })).toHaveClass(
      "h-9",
      "w-9",
      "sm:h-10",
      "sm:w-10",
      "object-contain"
    );
    expect(
      within(platforms).getByRole("link", { name: "打开搜索结果" })
    ).toHaveClass("h-11", "w-11", "sm:h-12", "sm:w-12");
    expect(result.compareDocumentPosition(platforms) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(platforms.compareDocumentPosition(lyrics) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(lyrics.compareDocumentPosition(controls) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  });

  it("previews and shares the recognized song with the iOS share card design", async () => {
    const user = userEvent.setup();
    const preparedShareData = {
      title: "爱情讯息",
      artist: "郭静",
      album: "下一个天亮",
      artworkUrl: "https://p1.music.126.net/love-message.jpg",
      artworkDataUrl: "data:image/jpeg;base64,prepared-cover",
      releaseDate: "2008-05-09",
      stationName: "清晨音乐台",
      timestamp: new Date(successRecognition.startedAt),
    };
    vi.mocked(prepareShareCardData).mockResolvedValue(preparedShareData);

    render(
      <AudioPlayerProvider>
        <RecognizedPlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开识别后播放器" }));
    await user.click(screen.getByRole("button", { name: "生成分享图" }));

    const dialog = screen.getByRole("dialog", { name: "分享图预览" });
    expect(
      within(dialog).getByRole("img", {
        name: "爱情讯息 - 郭静 分享图预览",
      })
    ).toBeInTheDocument();

    await user.click(within(dialog).getByRole("button", { name: "分享" }));

    expect(shareOrDownloadShareCard).toHaveBeenCalledWith(preparedShareData);
  });

  it("downloads the recognized song share card directly from the preview", async () => {
    const user = userEvent.setup();
    const preparedShareData = {
      title: "爱情讯息",
      artist: "郭静",
      album: "下一个天亮",
      artworkUrl: "https://p1.music.126.net/love-message.jpg",
      artworkDataUrl: "data:image/jpeg;base64,prepared-cover",
      releaseDate: "2008-05-09",
      stationName: "清晨音乐台",
      timestamp: new Date(successRecognition.startedAt),
    };
    vi.mocked(prepareShareCardData).mockResolvedValue(preparedShareData);

    render(
      <AudioPlayerProvider>
        <RecognizedPlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开识别后播放器" }));
    await user.click(screen.getByRole("button", { name: "生成分享图" }));

    const dialog = screen.getByRole("dialog", { name: "分享图预览" });
    await user.click(within(dialog).getByRole("button", { name: "下载" }));

    expect(downloadShareCard).toHaveBeenCalledWith(preparedShareData);
    expect(shareOrDownloadShareCard).not.toHaveBeenCalled();
  });

  it("uses the already loaded result artwork data when opening the share preview", async () => {
    const user = userEvent.setup();
    const drawImage = vi.fn();
    const getContextSpy = vi
      .spyOn(HTMLCanvasElement.prototype, "getContext")
      .mockImplementation(
        () => ({ drawImage } as unknown as CanvasRenderingContext2D)
      );
    const toDataURLSpy = vi
      .spyOn(HTMLCanvasElement.prototype, "toDataURL")
      .mockReturnValue("data:image/png;base64,reused-cover");

    try {
      render(
        <AudioPlayerProvider>
          <RecognizedPlayerPanelHarness />
        </AudioPlayerProvider>
      );

      await user.click(screen.getByRole("button", { name: "打开识别后播放器" }));

      const result = screen.getByRole("region", { name: "识别结果" });
      const artwork = within(result).getByRole("img", {
        name: "爱情讯息封面",
      }) as HTMLImageElement;
      Object.defineProperty(artwork, "complete", {
        configurable: true,
        value: true,
      });
      Object.defineProperty(artwork, "naturalWidth", {
        configurable: true,
        value: 300,
      });
      Object.defineProperty(artwork, "naturalHeight", {
        configurable: true,
        value: 300,
      });

      fireEvent.load(artwork);
      await user.click(screen.getByRole("button", { name: "生成分享图" }));

      await waitFor(() =>
        expect(prepareShareCardData).toHaveBeenCalledWith(
          expect.objectContaining({
            title: "爱情讯息",
            artist: "郭静",
            artworkUrl: "https://p1.music.126.net/love-message.jpg",
            artworkDataUrl: "data:image/png;base64,reused-cover",
          })
        )
      );
      expect(drawImage).toHaveBeenCalledWith(artwork, 0, 0);
    } finally {
      getContextSpy.mockRestore();
      toDataURLSpy.mockRestore();
    }
  });

  it("reuses artwork from the matching candidate when the active lyric version omits it", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <ArtworkFallbackRecognizedPlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开封面补全播放器" }));

    const result = screen.getByRole("region", { name: "识别结果" });
    expect(
      decodeURIComponent(
        within(result)
          .getByRole("img", { name: "我很想爱他封面" })
          .getAttribute("src") ?? ""
      )
    ).toContain(
      "/api/artwork?url=https://p2.music.126.net/Y4g2s63o5MNqlFb-17X2IQ==/109951170340575525.jpg?param=300y300"
    );

    await user.click(screen.getByRole("button", { name: "生成分享图" }));

    expect(prepareShareCardData).toHaveBeenCalledWith(
      expect.objectContaining({
        title: "我很想爱他",
        artist: "Twins",
        album: "八十块环游世界",
        artworkUrl:
          "https://p2.music.126.net/Y4g2s63o5MNqlFb-17X2IQ==/109951170340575525.jpg?param=300y300",
      })
    );
  });

  it("waits for album artwork preparation before opening the share preview", async () => {
    const user = userEvent.setup();
    let resolvePrepared:
      | ((data: Awaited<ReturnType<typeof prepareShareCardData>>) => void)
      | undefined;
    const prepared = {
      title: "爱情讯息",
      artist: "郭静",
      album: "下一个天亮",
      artworkUrl: "https://p1.music.126.net/love-message.jpg",
      artworkDataUrl: "data:image/jpeg;base64,album-cover",
      releaseDate: "2008-05-09",
      stationName: "清晨音乐台",
      timestamp: new Date(successRecognition.startedAt),
    };
    vi.mocked(prepareShareCardData).mockImplementationOnce(
      () =>
        new Promise((resolve) => {
          resolvePrepared = resolve;
        })
    );

    render(
      <AudioPlayerProvider>
        <RecognizedPlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开识别后播放器" }));
    await user.click(screen.getByRole("button", { name: "生成分享图" }));

    expect(screen.queryByRole("dialog", { name: "分享图预览" })).toBeNull();

    resolvePrepared?.(prepared);

    const dialog = await screen.findByRole("dialog", { name: "分享图预览" });
    expect(
      within(dialog).getByRole("img", {
        name: "爱情讯息 - 郭静 分享图预览",
      })
    ).toBeInTheDocument();
  });

  it("does not show an artwork-less preview while a second artwork preparation is still pending", async () => {
    const user = userEvent.setup();
    const rawShareData = {
      title: "爱情讯息",
      artist: "郭静",
      album: "下一个天亮",
      artworkUrl: "https://p1.music.126.net/love-message.jpg",
      releaseDate: "2008-05-09",
      stationName: "清晨音乐台",
      timestamp: new Date(successRecognition.startedAt),
    };
    const preparedShareData = {
      ...rawShareData,
      artworkDataUrl: "data:image/jpeg;base64,prepared-cover",
    };
    let resolvePrepared:
      | ((data: Awaited<ReturnType<typeof prepareShareCardData>>) => void)
      | undefined;

    vi.mocked(prepareShareCardData)
      .mockResolvedValueOnce(rawShareData)
      .mockImplementationOnce(
        () =>
          new Promise((resolve) => {
            resolvePrepared = resolve;
          })
      );

    render(
      <AudioPlayerProvider>
        <RecognizedPlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开识别后播放器" }));
    await user.click(screen.getByRole("button", { name: "生成分享图" }));

    const dialog = await screen.findByRole("dialog", { name: "分享图预览" });
    expect(within(dialog).getByText("正在准备封面...")).toBeInTheDocument();
    expect(
      within(dialog).queryByRole("img", {
        name: "爱情讯息 - 郭静 分享图预览",
      })
    ).toBeNull();
    expect(within(dialog).getByRole("button", { name: "分享" })).toBeDisabled();

    resolvePrepared?.(preparedShareData);

    const preview = await within(dialog).findByRole("img", {
      name: "爱情讯息 - 郭静 分享图预览",
    });
    expect(decodeURIComponent(preview.getAttribute("src") ?? "")).toContain(
      "<svg>artwork</svg>"
    );

    await user.click(within(dialog).getByRole("button", { name: "分享" }));

    expect(shareOrDownloadShareCard).toHaveBeenCalledWith(preparedShareData);
  });

  it("hides native scrollbars while recognition is loading", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <LoadingPlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开识别中播放器" }));

    expect(screen.getByText("正在听取歌词...")).toBeInTheDocument();
    expect(screen.getByTestId("player-panel-scroll-frame")).toHaveClass(
      "scrollbar-none",
      "overflow-x-hidden"
    );
  });

  it("keeps the loading recognition pill in a stable clipped frame to avoid iOS repaint ghosts", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <LoadingPlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开识别中播放器" }));

    const action = screen.getByRole("button", { name: "歌曲识别" });
    expect(action).toHaveClass("w-72", "min-h-12", "overflow-hidden", "transition-colors");
    expect(screen.getByText("识别中")).toBeInTheDocument();
    expect(screen.getByText("正在听取歌词")).toBeInTheDocument();
    expect(screen.queryByText("选取歌词清晰片段开始识别")).not.toBeInTheDocument();
  });

  it("shows the lyric-matched candidate instead of a stale first candidate", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <MismatchedRecognizedPlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开错配识别播放器" }));

    const result = screen.getByRole("region", { name: "识别结果" });
    const platforms = screen.getByRole("group", { name: "音乐平台" });

    expect(within(result).getByRole("heading", { name: "好久不见" })).toBeInTheDocument();
    expect(within(result).queryByRole("heading", { name: "愿你余生漫长" })).not.toBeInTheDocument();
    expect(within(platforms).getByRole("link", { name: "网易云音乐" })).toHaveAttribute(
      "href",
      "orpheus://song/right-1"
    );
  });

  it("lets the user switch ambiguous song versions and updates the displayed lyrics", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <AmbiguousRecognizedPlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开多版本识别播放器" }));

    const initialResult = screen.getByRole("region", { name: "识别结果" });
    expect(screen.queryByRole("group", { name: "可能版本" })).not.toBeInTheDocument();
    const versionToggle = screen.getByRole("button", {
      name: "当前版本可能不对，查看 2 个候选版本",
    });
    expect(versionToggle).toHaveClass("font-normal");
    expect(versionToggle).toHaveStyle({ fontSize: "11px", lineHeight: "1" });
    expect(within(initialResult).getByText(/李健/)).toHaveClass(
      "text-[11px]",
      "sm:text-xs"
    );
    expect(screen.getByText("李健版本")).toBeInTheDocument();

    await user.click(versionToggle);

    expect(screen.getByRole("group", { name: "可能版本" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "谭咏麟 神话1991" }));

    const result = screen.getByRole("region", { name: "识别结果" });
    expect(within(result).getByText(/谭咏麟/)).toHaveClass(
      "text-[11px]",
      "sm:text-xs"
    );
    expect(screen.getByText("谭咏麟版本")).toBeInTheDocument();
    expect(screen.queryByText("李健版本")).not.toBeInTheDocument();
  });

  it("shows QQ-corrected song metadata and avoids opening a stale NetEase song id", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <QQCorrectedRecognizedPlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开QQ修正识别播放器" }));

    const result = screen.getByRole("region", { name: "识别结果" });
    const platforms = screen.getByRole("group", { name: "音乐平台" });

    expect(within(result).getByRole("heading", { name: "庙堂之外" })).toBeInTheDocument();
    expect(
      within(result).getByText("陈楚生 | 长安的荔枝原声带")
    ).toBeInTheDocument();
    expect(within(platforms).getByRole("link", { name: "QQ音乐" })).toHaveAttribute(
      "href",
      expect.stringContaining("004TempleSong")
    );
    expect(within(platforms).getByRole("link", { name: "网易云音乐" })).toHaveAttribute(
      "href",
      expect.stringContaining("orpheus://search?keyword=")
    );
    expect(
      within(platforms).getByRole("link", { name: "网易云音乐" })
    ).not.toHaveAttribute("href", expect.stringContaining("wrong-net-ease-id"));
  });

  it("fills missing release information from matching candidate metadata", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <MetadataFallbackRecognizedPlayerPanelHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "打开元数据补全播放器" }));

    const result = screen.getByRole("region", { name: "识别结果" });
    expect(
      within(result).getByRole("heading", { name: "好眼泪坏眼泪" })
    ).toBeInTheDocument();
    expect(within(result).getByText("徐若瑄 | 最爱是V 新歌+精选")).toBeInTheDocument();
    expect(within(result).getByText("发行于 2007 · 19年前")).toBeInTheDocument();
  });
});
