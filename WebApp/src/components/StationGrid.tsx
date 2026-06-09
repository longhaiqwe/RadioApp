"use client";

import type { Station } from "@/features/stations/stationTypes";
import { StationCard } from "./StationCard";

type StationGridProps = {
  stations: Station[];
  currentStationId?: string;
  favoriteIds: Set<string>;
  playlistTitle: string;
  onPlayStation: (station: Station, playlist: Station[], playlistTitle: string) => void;
  onToggleFavorite: (station: Station) => void;
};

export function StationGrid({
  stations,
  currentStationId,
  favoriteIds,
  playlistTitle,
  onPlayStation,
  onToggleFavorite,
}: StationGridProps) {
  return (
    <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
      {stations.map((station) => (
        <StationCard
          key={station.id}
          station={station}
          isPlaying={station.id === currentStationId}
          isFavorite={favoriteIds.has(station.id)}
          onPlay={() => onPlayStation(station, stations, playlistTitle)}
          onToggleFavorite={onToggleFavorite}
        />
      ))}
    </div>
  );
}
