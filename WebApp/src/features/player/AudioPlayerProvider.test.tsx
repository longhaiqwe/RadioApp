import { act, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { stationFixture } from "@/test/fixtures";
import { AudioPlayerProvider, useAudioPlayer } from "./AudioPlayerProvider";

type AudioListener = () => void;

class MockAudio {
  src = "";
  volume = 0.5;
  play = vi.fn(async () => undefined);
  pause = vi.fn();
  private listeners = new Map<string, Set<AudioListener>>();

  addEventListener(type: string, listener: AudioListener) {
    const current = this.listeners.get(type) ?? new Set<AudioListener>();
    current.add(listener);
    this.listeners.set(type, current);
  }

  removeEventListener(type: string, listener: AudioListener) {
    this.listeners.get(type)?.delete(listener);
  }

  emit(type: string) {
    this.listeners.get(type)?.forEach((listener) => listener());
  }
}

function AudioHarness() {
  const { playStation, setVolume } = useAudioPlayer();

  return (
    <div>
      <button
        type="button"
        onClick={() => playStation(stationFixture, [stationFixture], "发现")}
      >
        播放
      </button>
      <button type="button" onClick={() => setVolume(0.8)}>
        音量
      </button>
    </div>
  );
}

describe("AudioPlayerProvider", () => {
  let audio: MockAudio;

  beforeEach(() => {
    window.localStorage.clear();
    audio = new MockAudio();
    vi.stubGlobal("Audio", vi.fn(() => audio));
  });

  it("starts playback from the user action and does not replay on volume changes", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <AudioHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "播放" }));

    await waitFor(() => {
      expect(audio.play).toHaveBeenCalledTimes(1);
    });
    expect(audio.src).toBe(stationFixture.urlResolved);

    await user.click(screen.getByRole("button", { name: "音量" }));

    expect(audio.play).toHaveBeenCalledTimes(1);
    await waitFor(() => {
      expect(audio.volume).toBe(0.8);
    });
  });

  it("records played stations after the audio element reports playback", async () => {
    const onPlayedStation = vi.fn();
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider onPlayedStation={onPlayedStation}>
        <AudioHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "播放" }));
    act(() => {
      audio.emit("playing");
    });

    expect(onPlayedStation).toHaveBeenCalledWith(stationFixture);
  });
});
