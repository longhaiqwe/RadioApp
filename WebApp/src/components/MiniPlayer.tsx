"use client";

import { Pause, Play } from "lucide-react";
import { useAudioPlayer } from "@/features/player/AudioPlayerProvider";
import { StationAvatar } from "./StationAvatar";

export function MiniPlayer() {
  const { state, togglePlayPause, setExpanded } = useAudioPlayer();

  if (!state.currentStation) return null;

  return (
    <div className="neon-glow-cyan fixed inset-x-4 bottom-4 z-40 mx-auto max-w-2xl rounded-3xl border border-[rgba(0,217,255,0.35)] bg-[rgba(12,14,24,0.94)] p-3 backdrop-blur-xl">
      <div className="flex items-center gap-3">
        <button
          type="button"
          className="flex min-w-0 flex-1 items-center gap-3 text-left"
          onClick={() => setExpanded(true)}
        >
          <StationAvatar
            name={state.currentStation.name}
            stationId={state.currentStation.id}
            favicon={state.currentStation.favicon}
            sizeClassName="h-12 w-12"
          />
          <div className="min-w-0">
            <p className="truncate text-sm font-bold text-white">
              {state.currentStation.name}
            </p>
            <p className="truncate text-xs text-[var(--neon-cyan)]">
              {state.playbackError ?? state.playlistTitle}
            </p>
          </div>
        </button>
        <button
          type="button"
          aria-label={state.isPlaying ? "暂停" : "播放"}
          onClick={togglePlayPause}
          className="neon-glow-magenta grid h-12 w-12 place-items-center rounded-full bg-[linear-gradient(135deg,var(--neon-magenta),var(--neon-purple))] text-white"
        >
          {state.isPlaying ? <Pause size={20} /> : <Play size={20} />}
        </button>
      </div>
    </div>
  );
}
