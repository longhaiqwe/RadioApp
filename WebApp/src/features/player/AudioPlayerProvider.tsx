"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useReducer,
  useRef,
  type ReactNode,
} from "react";
import type { Station } from "@/features/stations/stationTypes";
import { readJson, writeJson } from "@/lib/localJsonStorage";
import { audioPlayerReducer, initialAudioPlayerState } from "./audioPlayerReducer";
import type { AudioPlayerState } from "./audioPlayerTypes";

type AudioPlayerContextValue = {
  state: AudioPlayerState;
  playStation: (station: Station, playlist: Station[], playlistTitle: string) => void;
  togglePlayPause: () => void;
  next: () => void;
  previous: () => void;
  setVolume: (volume: number) => void;
  setExpanded: (expanded: boolean) => void;
};

const AudioPlayerContext = createContext<AudioPlayerContextValue | null>(null);
const PLAYBACK_ERROR_MESSAGE = "该电台暂不支持浏览器播放。";
const USER_ACTION_REQUIRED_MESSAGE = "请点击播放以开始收听。";

type StartPlaybackOptions = {
  forceReload?: boolean;
};

function currentPlaylistIndex(state: AudioPlayerState): number {
  if (!state.currentStation) {
    return -1;
  }

  return state.playlist.findIndex(
    (station) => station.id === state.currentStation?.id
  );
}

export function AudioPlayerProvider({
  children,
  onPlayedStation,
}: {
  children: ReactNode;
  onPlayedStation?: (station: Station) => void;
}) {
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const onPlayedStationRef = useRef(onPlayedStation);
  const playAttemptIdRef = useRef(0);
  const reportedPlayAttemptIdRef = useRef(0);
  const [state, dispatch] = useReducer(
    audioPlayerReducer,
    initialAudioPlayerState,
    (initialState) => ({
      ...initialState,
      volume: readJson<number>("radioapp:web:volume", 0.5),
    })
  );
  const stateRef = useRef(state);

  useEffect(() => {
    stateRef.current = state;
  }, [state]);

  useEffect(() => {
    onPlayedStationRef.current = onPlayedStation;
  }, [onPlayedStation]);

  const startPlayback = useCallback(async (
    station: Station,
    options: StartPlaybackOptions = {}
  ) => {
    const audio = audioRef.current;
    if (!audio) {
      return;
    }

    const source = station.urlResolved || station.url;
    if (options.forceReload || audio.src !== source) {
      audio.src = source;
      audio.load();
    }
    audio.volume = stateRef.current.volume;

    const playAttemptId = ++playAttemptIdRef.current;

    try {
      await audio.play();
    } catch (error) {
      if (playAttemptId !== playAttemptIdRef.current) {
        return;
      }

      if (error instanceof DOMException && error.name === "AbortError") {
        return;
      }

      dispatch({
        type: "playbackError",
        message:
          error instanceof DOMException && error.name === "NotAllowedError"
            ? USER_ACTION_REQUIRED_MESSAGE
            : PLAYBACK_ERROR_MESSAGE,
      });
    }
  }, []);

  useEffect(() => {
    const audio = new Audio();
    audioRef.current = audio;
    audio.volume = stateRef.current.volume;

    const onPlaying = () => {
      dispatch({ type: "playbackStarted" });
      const currentStation = stateRef.current.currentStation;
      if (
        currentStation &&
        reportedPlayAttemptIdRef.current !== playAttemptIdRef.current
      ) {
        reportedPlayAttemptIdRef.current = playAttemptIdRef.current;
        onPlayedStationRef.current?.(currentStation);
      }
    };
    const onError = () => {
      dispatch({
        type: "playbackError",
        message: PLAYBACK_ERROR_MESSAGE,
      });
    };

    audio.addEventListener("playing", onPlaying);
    audio.addEventListener("error", onError);

    return () => {
      audio.removeEventListener("playing", onPlaying);
      audio.removeEventListener("error", onError);
      audio.pause();
      audioRef.current = null;
    };
  }, []);

  useEffect(() => {
    if (audioRef.current) {
      audioRef.current.volume = state.volume;
    }

    writeJson("radioapp:web:volume", state.volume);
  }, [state.volume]);

  const playStation = useCallback(
    (station: Station, playlist: Station[], playlistTitle: string) => {
      const shouldForceReload = stateRef.current.currentStation?.id === station.id;
      dispatch({ type: "playStation", station, playlist, playlistTitle });
      void startPlayback(station, { forceReload: shouldForceReload });
    },
    [startPlayback]
  );

  const togglePlayPause = useCallback(() => {
    const audio = audioRef.current;
    const currentStation = stateRef.current.currentStation;
    if (!audio || !currentStation) return;

    if (stateRef.current.isPlaying) {
      audio.pause();
      dispatch({ type: "pause" });
      return;
    }

    void startPlayback(currentStation, {
      forceReload: stateRef.current.playbackError !== null,
    });
  }, [startPlayback]);

  const next = useCallback(() => {
    const currentState = stateRef.current;
    const index = currentPlaylistIndex(currentState);
    if (index < 0 || currentState.playlist.length === 0) {
      return;
    }

    const station =
      currentState.playlist[(index + 1) % currentState.playlist.length];
    if (!station) {
      return;
    }

    dispatch({ type: "next" });
    void startPlayback(station, {
      forceReload: currentState.currentStation?.id === station.id,
    });
  }, [startPlayback]);

  const previous = useCallback(() => {
    const currentState = stateRef.current;
    const index = currentPlaylistIndex(currentState);
    if (index < 0 || currentState.playlist.length === 0) {
      return;
    }

    const station =
      currentState.playlist[
        (index - 1 + currentState.playlist.length) % currentState.playlist.length
      ];
    if (!station) {
      return;
    }

    dispatch({ type: "previous" });
    void startPlayback(station, {
      forceReload: currentState.currentStation?.id === station.id,
    });
  }, [startPlayback]);

  const value = useMemo<AudioPlayerContextValue>(
    () => ({
      state,
      playStation,
      togglePlayPause,
      next,
      previous,
      setVolume: (volume: number) => dispatch({ type: "setVolume", volume }),
      setExpanded: (expanded: boolean) =>
        dispatch({ type: "setExpanded", expanded }),
    }),
    [next, playStation, previous, state, togglePlayPause],
  );

  return (
    <AudioPlayerContext.Provider value={value}>
      {children}
    </AudioPlayerContext.Provider>
  );
}

export function useAudioPlayer() {
  const value = useContext(AudioPlayerContext);
  if (!value) {
    throw new Error("useAudioPlayer must be used inside AudioPlayerProvider");
  }

  return value;
}
