"use client";

import {
  Heart,
  Pause,
  Play,
  RotateCcw,
  SkipBack,
  SkipForward,
  Sparkles,
  X,
} from "lucide-react";
import { useAudioPlayer } from "@/features/player/AudioPlayerProvider";
import type { Station } from "@/features/stations/stationTypes";
import { IconButton } from "./IconButton";
import { StationAvatar } from "./StationAvatar";

type PlayerPanelProps = {
  isFavorite: boolean;
  onToggleFavorite: (station: Station) => void;
  onOpenWaitlist: () => void;
};

export function PlayerPanel({
  isFavorite,
  onToggleFavorite,
  onOpenWaitlist,
}: PlayerPanelProps) {
  const {
    state,
    togglePlayPause,
    previous,
    next,
    setVolume,
    setExpanded,
    playStation,
  } = useAudioPlayer();

  if (!state.isExpanded || !state.currentStation) return null;

  const currentStation = state.currentStation;

  return (
    <div className="fixed inset-0 z-50 bg-[rgba(10,10,15,0.94)] p-5 backdrop-blur-2xl">
      <div className="mx-auto flex h-full max-w-3xl flex-col">
        <div className="flex justify-end">
          <IconButton label="关闭播放器" onClick={() => setExpanded(false)}>
            <X size={20} />
          </IconButton>
        </div>

        <div className="flex flex-1 flex-col items-center justify-center gap-6 text-center">
          <StationAvatar
            name={currentStation.name}
            stationId={currentStation.id}
            favicon={currentStation.favicon}
            sizeClassName="h-44 w-44"
          />
          <div>
            <h2 className="text-3xl font-black text-white">{currentStation.name}</h2>
            <p className="mt-2 text-sm text-[var(--neon-cyan)]">
              {currentStation.tags || currentStation.country}
            </p>
            {state.playbackError ? (
              <p className="mt-3 rounded-full border border-[rgba(255,59,48,0.35)] bg-[rgba(255,59,48,0.12)] px-4 py-2 text-sm text-white/80">
                {state.playbackError}
              </p>
            ) : null}
          </div>

          <div className="flex items-center gap-4">
            <IconButton label="上一台" onClick={previous}>
              <SkipBack size={20} />
            </IconButton>
            <button
              type="button"
              aria-label={state.isPlaying ? "暂停" : "播放"}
              onClick={togglePlayPause}
              className="neon-glow-magenta grid h-20 w-20 place-items-center rounded-full bg-[linear-gradient(135deg,var(--neon-magenta),var(--neon-purple))] text-white active:scale-95"
            >
              {state.isPlaying ? <Pause size={30} /> : <Play size={30} />}
            </button>
            <IconButton label="下一台" onClick={next}>
              <SkipForward size={20} />
            </IconButton>
          </div>

          <div className="flex items-center gap-3">
            <IconButton
              label={isFavorite ? "取消收藏" : "收藏"}
              active={isFavorite}
              onClick={() => onToggleFavorite(currentStation)}
            >
              <Heart size={20} fill={isFavorite ? "currentColor" : "none"} />
            </IconButton>
            <IconButton
              label="重试播放"
              onClick={() => playStation(currentStation, state.playlist, state.playlistTitle)}
            >
              <RotateCcw size={20} />
            </IconButton>
            <IconButton label="识别歌曲" onClick={onOpenWaitlist}>
              <Sparkles size={20} />
            </IconButton>
          </div>

          <label className="flex w-full max-w-xs items-center gap-3 text-sm text-white/60">
            音量
            <input
              aria-label="音量"
              type="range"
              min="0"
              max="1"
              step="0.01"
              value={state.volume}
              onChange={(event) => setVolume(Number(event.target.value))}
              className="w-full accent-[var(--neon-cyan)]"
            />
          </label>
        </div>
      </div>
    </div>
  );
}
