"use client";

import { Heart, Play } from "lucide-react";
import type { Station } from "@/features/stations/stationTypes";
import { GlassCard } from "./GlassCard";
import { IconButton } from "./IconButton";
import { StationAvatar } from "./StationAvatar";

type StationCardProps = {
  station: Station;
  isPlaying: boolean;
  isFavorite: boolean;
  onPlay: (station: Station) => void;
  onToggleFavorite: (station: Station) => void;
};

export function StationCard({
  station,
  isPlaying,
  isFavorite,
  onPlay,
  onToggleFavorite,
}: StationCardProps) {
  return (
    <GlassCard active={isPlaying} className="p-3">
      <div className="flex gap-3">
        <button
          type="button"
          aria-label={`播放 ${station.name}`}
          className="min-w-0 flex flex-1 gap-3 text-left"
          onClick={() => onPlay(station)}
        >
          <StationAvatar
            name={station.name}
            stationId={station.id}
            favicon={station.favicon}
            sizeClassName="h-16 w-16"
          />
          <span className="min-w-0 flex-1">
            <span className="block truncate font-bold text-white">{station.name}</span>
            <span className="mt-1 block truncate text-xs text-[var(--neon-cyan)]">
              {station.tags || station.country || "Radio"}
            </span>
            <span className="mt-2 inline-flex items-center gap-1 text-xs text-white/50">
              <Play size={12} />
              {station.codec || "STREAM"}
            </span>
          </span>
        </button>
        <IconButton
          label={`${isFavorite ? "取消收藏" : "收藏"} ${station.name}`}
          active={isFavorite}
          aria-pressed={isFavorite}
          onClick={() => onToggleFavorite(station)}
        >
          <Heart size={18} fill={isFavorite ? "currentColor" : "none"} />
        </IconButton>
      </div>
    </GlassCard>
  );
}
