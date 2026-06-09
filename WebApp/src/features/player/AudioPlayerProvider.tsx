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

export function AudioPlayerProvider({
  children,
  onPlayedStation,
}: {
  children: ReactNode;
  onPlayedStation?: (station: Station) => void;
}) {
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const [state, dispatch] = useReducer(audioPlayerReducer, {
    ...initialAudioPlayerState,
    volume: readJson<number>("radioapp:web:volume", 0.5),
  });

  useEffect(() => {
    const audio = new Audio();
    audioRef.current = audio;

    return () => {
      audio.pause();
      audioRef.current = null;
    };
  }, []);

  useEffect(() => {
    if (!audioRef.current || !state.currentStation) return;

    const audio = audioRef.current;
    const currentStation = state.currentStation;

    audio.src = currentStation.urlResolved || currentStation.url;
    audio.volume = state.volume;

    const onPlaying = () => {
      dispatch({ type: "playbackStarted" });
      onPlayedStation?.(currentStation);
    };
    const onError = () => {
      dispatch({
        type: "playbackError",
        message: "该电台暂不支持浏览器播放。",
      });
    };

    audio.addEventListener("playing", onPlaying);
    audio.addEventListener("error", onError);
    void audio.play().catch(() => onError());

    return () => {
      audio.removeEventListener("playing", onPlaying);
      audio.removeEventListener("error", onError);
    };
  }, [onPlayedStation, state.currentStation, state.volume]);

  useEffect(() => {
    if (audioRef.current) {
      audioRef.current.volume = state.volume;
    }

    writeJson("radioapp:web:volume", state.volume);
  }, [state.volume]);

  const playStation = useCallback(
    (station: Station, playlist: Station[], playlistTitle: string) => {
      dispatch({ type: "playStation", station, playlist, playlistTitle });
    },
    [],
  );

  const togglePlayPause = useCallback(() => {
    const audio = audioRef.current;
    if (!audio || !state.currentStation) return;

    if (state.isPlaying) {
      audio.pause();
      dispatch({ type: "pause" });
      return;
    }

    void audio.play().catch(() =>
      dispatch({
        type: "playbackError",
        message: "该电台暂不支持浏览器播放。",
      }),
    );
  }, [state.currentStation, state.isPlaying]);

  const value = useMemo<AudioPlayerContextValue>(
    () => ({
      state,
      playStation,
      togglePlayPause,
      next: () => dispatch({ type: "next" }),
      previous: () => dispatch({ type: "previous" }),
      setVolume: (volume: number) => dispatch({ type: "setVolume", volume }),
      setExpanded: (expanded: boolean) =>
        dispatch({ type: "setExpanded", expanded }),
    }),
    [playStation, state, togglePlayPause],
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
