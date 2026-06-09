import type { Station } from "@/features/stations/stationTypes";

export type AudioPlayerState = {
  currentStation: Station | null;
  playlist: Station[];
  playlistTitle: string;
  isPlaying: boolean;
  isLoading: boolean;
  playbackError: string | null;
  volume: number;
  isExpanded: boolean;
};

export type AudioPlayerAction =
  | {
      type: "playStation";
      station: Station;
      playlist: Station[];
      playlistTitle: string;
    }
  | { type: "playbackStarted" }
  | { type: "pause" }
  | { type: "playbackError"; message: string }
  | { type: "next" }
  | { type: "previous" }
  | { type: "setVolume"; volume: number }
  | { type: "setExpanded"; expanded: boolean };
