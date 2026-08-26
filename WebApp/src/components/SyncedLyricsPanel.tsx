"use client";

import type { SyncedLyrics } from "@/features/recognition/recognitionTypes";
import { RefreshCcw, RotateCcw, RotateCw } from "lucide-react";
import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";

type SyncedLyricsPanelProps = {
  lyrics: SyncedLyrics;
  recognitionStartedAt?: number;
};

const LYRICS_DISCLAIMER = "歌词来源于QQ音乐/网易云音乐，仅供参考";
const DEFAULT_LYRICS_SYNC_OFFSET_SECONDS = -2;

export function SyncedLyricsPanel({
  lyrics,
  recognitionStartedAt,
}: SyncedLyricsPanelProps) {
  const [manualOffsetSeconds, setManualOffsetSeconds] = useState(
    DEFAULT_LYRICS_SYNC_OFFSET_SECONDS
  );
  const [currentSongTime, setCurrentSongTime] = useState(() =>
    readCurrentSongTime(
      lyrics,
      recognitionStartedAt,
      DEFAULT_LYRICS_SYNC_OFFSET_SECONDS
    )
  );
  const isUserScrolling = useRef(false);
  const scrollResumeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lineRefs = useRef(new Map<string, HTMLParagraphElement>());

  const activeLineId = useMemo(() => {
    const activeLine = lyrics.lines.findLast((line) => line.time <= currentSongTime);
    return activeLine?.id;
  }, [currentSongTime, lyrics.lines]);

  useEffect(() => {
    const interval = setInterval(() => {
      setCurrentSongTime(
        readCurrentSongTime(lyrics, recognitionStartedAt, manualOffsetSeconds)
      );
    }, 500);

    return () => clearInterval(interval);
  }, [lyrics, manualOffsetSeconds, recognitionStartedAt]);

  useEffect(() => {
    return () => {
      if (scrollResumeTimer.current) clearTimeout(scrollResumeTimer.current);
    };
  }, []);

  useEffect(() => {
    if (!activeLineId || isUserScrolling.current) return;

    lineRefs.current.get(activeLineId)?.scrollIntoView?.({
      block: "center",
      behavior: "smooth",
    });
  }, [activeLineId]);

  const adjustLyricsTiming = (deltaSeconds: number) => {
    const nextOffset = manualOffsetSeconds + deltaSeconds;
    setManualOffsetSeconds(nextOffset);
    setCurrentSongTime(readCurrentSongTime(lyrics, recognitionStartedAt, nextOffset));
  };

  const resetLyricsTiming = () => {
    setManualOffsetSeconds(DEFAULT_LYRICS_SYNC_OFFSET_SECONDS);
    setCurrentSongTime(
      readCurrentSongTime(
        lyrics,
        recognitionStartedAt,
        DEFAULT_LYRICS_SYNC_OFFSET_SECONDS
      )
    );
  };

  return (
    <section
      aria-label="同步歌词"
      className="w-full overflow-hidden rounded-[20px] border border-[rgba(0,217,255,0.18)] bg-black/90 shadow-[0_0_32px_rgba(0,217,255,0.08)]"
    >
      <div
        data-testid="lyrics-scroll-viewport"
        className="relative h-[clamp(15rem,38vh,24rem)]"
        onPointerDown={() => {
          isUserScrolling.current = true;
          if (scrollResumeTimer.current) clearTimeout(scrollResumeTimer.current);
        }}
        onPointerUp={() => {
          if (scrollResumeTimer.current) clearTimeout(scrollResumeTimer.current);
          scrollResumeTimer.current = setTimeout(() => {
            isUserScrolling.current = false;
          }, 4000);
        }}
        onPointerCancel={() => {
          isUserScrolling.current = false;
        }}
      >
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-x-0 top-0 z-10 h-20 bg-gradient-to-b from-black via-black/75 to-transparent"
        />
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-x-0 bottom-0 z-10 h-20 bg-gradient-to-t from-black via-black/75 to-transparent"
        />
        <div className="scrollbar-none h-full overflow-y-auto px-5">
          <div className="space-y-3 py-16 text-center sm:py-20">
            {lyrics.lines.map((line) => {
              const isActive = line.id === activeLineId;

              return (
                <p
                  key={line.id}
                  ref={(element) => {
                    if (element) lineRefs.current.set(line.id, element);
                    else lineRefs.current.delete(line.id);
                  }}
                  aria-current={isActive ? "true" : undefined}
                  className={
                    isActive
                      ? "mx-auto max-w-xl scale-[1.06] break-words text-base font-bold leading-snug text-white drop-shadow-[0_0_14px_rgba(0,217,255,0.28)] transition duration-300"
                      : "mx-auto max-w-xl break-words text-sm leading-snug text-white/60 transition duration-300"
                  }
                >
                  {line.text}
                </p>
              );
            })}
          </div>
        </div>
      </div>
      <div className="border-t border-white/10 bg-white/[0.03] px-4 pb-3 pt-2">
        <div className="flex items-start justify-center gap-8">
          <LyricTimingButton
            label="歌词后退 1 秒"
            caption="-1s"
            onClick={() => adjustLyricsTiming(-1)}
          >
            <RotateCcw size={18} />
          </LyricTimingButton>
          <LyricTimingButton
            label="重置歌词偏移"
            caption="重置"
            onClick={resetLyricsTiming}
          >
            <RefreshCcw size={18} />
          </LyricTimingButton>
          <LyricTimingButton
            label="歌词前进 1 秒"
            caption="+1s"
            onClick={() => adjustLyricsTiming(1)}
          >
            <RotateCw size={18} />
          </LyricTimingButton>
        </div>
        <p className="mt-3 text-center text-xs text-white/40">
          {LYRICS_DISCLAIMER}
        </p>
      </div>
    </section>
  );
}

function readCurrentSongTime(
  lyrics: Pick<SyncedLyrics, "estimatedOffsetSeconds">,
  recognitionStartedAt?: number,
  manualOffsetSeconds = 0
) {
  const elapsedSeconds =
    typeof recognitionStartedAt === "number"
      ? (Date.now() - recognitionStartedAt) / 1000
      : undefined;

  if (typeof lyrics.estimatedOffsetSeconds !== "number") {
    return typeof elapsedSeconds === "number"
      ? elapsedSeconds + manualOffsetSeconds
      : manualOffsetSeconds;
  }

  return (
    lyrics.estimatedOffsetSeconds +
    (elapsedSeconds ?? 0) +
    manualOffsetSeconds
  );
}

function LyricTimingButton({
  children,
  caption,
  label,
  onClick,
}: {
  children: ReactNode;
  caption: string;
  label: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      onClick={onClick}
      className="group flex min-w-12 flex-col items-center gap-1 text-white/70 outline-none"
    >
      <span className="grid h-10 w-10 place-items-center rounded-full bg-white/10 text-white transition group-hover:bg-white/15 group-hover:text-[var(--neon-cyan)] group-focus-visible:ring-2 group-focus-visible:ring-[var(--neon-cyan)]">
        {children}
      </span>
      <span className="text-[11px] leading-none">{caption}</span>
    </button>
  );
}
