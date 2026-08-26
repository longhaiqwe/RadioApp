import type { AudioPlayerAction, AudioPlayerState } from "./audioPlayerTypes";

export const initialAudioPlayerState: AudioPlayerState = {
  currentStation: null,
  playlist: [],
  playlistTitle: "播放列表",
  isPlaying: false,
  isLoading: false,
  playbackError: null,
  volume: 0.5,
  isExpanded: false,
};

function currentIndex(state: AudioPlayerState): number {
  if (!state.currentStation) return -1;

  return state.playlist.findIndex(
    (station) => station.id === state.currentStation?.id,
  );
}

export function audioPlayerReducer(
  state: AudioPlayerState,
  action: AudioPlayerAction,
): AudioPlayerState {
  switch (action.type) {
    case "playStation":
      return {
        ...state,
        currentStation: action.station,
        playlist: action.playlist,
        playlistTitle: action.playlistTitle,
        isLoading: true,
        isPlaying: false,
        playbackError: null,
      };
    case "playbackStarted":
      return { ...state, isLoading: false, isPlaying: true, playbackError: null };
    case "pause":
      return { ...state, isPlaying: false, isLoading: false };
    case "playbackError":
      return {
        ...state,
        isPlaying: false,
        isLoading: false,
        playbackError: action.message,
      };
    case "next": {
      const index = currentIndex(state);
      if (index < 0 || state.playlist.length === 0) return state;

      const station = state.playlist[(index + 1) % state.playlist.length];
      return station
        ? {
            ...state,
            currentStation: station,
            isLoading: true,
            playbackError: null,
          }
        : state;
    }
    case "previous": {
      const index = currentIndex(state);
      if (index < 0 || state.playlist.length === 0) return state;

      const station =
        state.playlist[(index - 1 + state.playlist.length) % state.playlist.length];
      return station
        ? {
            ...state,
            currentStation: station,
            isLoading: true,
            playbackError: null,
          }
        : state;
    }
    case "setVolume":
      return { ...state, volume: Math.min(1, Math.max(0, action.volume)) };
    case "setExpanded":
      return { ...state, isExpanded: action.expanded };
    default:
      return state;
  }
}
