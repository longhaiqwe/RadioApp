import type { SyncedLyrics } from "@/features/recognition/recognitionTypes";
import { fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { SyncedLyricsPanel } from "./SyncedLyricsPanel";

const lyrics: SyncedLyrics = {
  source: "qq",
  rawLrc: "[00:10.00]可以恨你 全力痛恨你\n[00:20.00]无非想放下你 还是挂念你",
  estimatedOffsetSeconds: 8,
  matchedSnippet: "可以恨你 全力痛恨你",
  lines: [
    { id: "0-10", time: 10, text: "可以恨你 全力痛恨你" },
    { id: "1-20", time: 20, text: "无非想放下你 还是挂念你" },
  ],
};

describe("SyncedLyricsPanel", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("highlights the active lyric line with the default two-second correction", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-06-11T10:00:12.000Z"));

    render(
      <SyncedLyricsPanel
        lyrics={lyrics}
        recognitionStartedAt={Date.parse("2026-06-11T10:00:00.000Z")}
      />
    );

    expect(
      screen.getByText("歌词来源于QQ音乐/网易云音乐，仅供参考")
    ).toBeInTheDocument();
    expect(screen.getByText("可以恨你 全力痛恨你")).toHaveAttribute(
      "aria-current",
      "true"
    );
    expect(screen.getByText("可以恨你 全力痛恨你")).toHaveClass(
      "text-base"
    );
    expect(screen.getByText("无非想放下你 还是挂念你")).toHaveClass("text-sm");
  });

  it("keeps the lyric scroll area tall without moving playback controls over it", () => {
    render(<SyncedLyricsPanel lyrics={lyrics} />);

    expect(screen.getByTestId("lyrics-scroll-viewport")).toHaveClass(
      "h-[clamp(15rem,38vh,24rem)]"
    );
  });

  it("matches the iOS lyric timing controls and adjusts the highlighted line", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-06-11T10:00:14.000Z"));

    render(
      <SyncedLyricsPanel
        lyrics={lyrics}
        recognitionStartedAt={Date.parse("2026-06-11T10:00:00.000Z")}
      />
    );

    expect(
      screen.getByRole("button", { name: "歌词后退 1 秒" })
    ).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "重置歌词偏移" })).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "歌词前进 1 秒" })
    ).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "歌词后退 1 秒" }));

    expect(screen.getByText("可以恨你 全力痛恨你")).toHaveAttribute(
      "aria-current",
      "true"
    );
  });

  it("keeps scrolling timed lyrics when no matched snippet offset is available", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-06-11T10:00:22.000Z"));

    render(
      <SyncedLyricsPanel
        lyrics={{
          ...lyrics,
          estimatedOffsetSeconds: undefined,
          matchedSnippet: undefined,
        }}
        recognitionStartedAt={Date.parse("2026-06-11T10:00:00.000Z")}
      />
    );

    expect(screen.getByText("无非想放下你 还是挂念你")).toHaveAttribute(
      "aria-current",
      "true"
    );
  });
});
