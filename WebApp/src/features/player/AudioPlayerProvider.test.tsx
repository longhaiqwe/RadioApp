import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { stationFixture } from "@/test/fixtures";
import { AudioPlayerProvider, useAudioPlayer } from "./AudioPlayerProvider";

type AudioListener = () => void;

class MockAudio {
  src = "";
  volume = 0.5;
  play = vi.fn(async () => undefined);
  pause = vi.fn();
  load = vi.fn();
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
  const { next, playStation, setVolume, state, togglePlayPause } =
    useAudioPlayer();

  return (
    <div>
      <output aria-label="播放错误">{state.playbackError ?? ""}</output>
      <button
        type="button"
        onClick={() => playStation(stationFixture, [stationFixture], "发现")}
      >
        播放
      </button>
      <button type="button" onClick={() => setVolume(0.8)}>
        音量
      </button>
      <button type="button" onClick={togglePlayPause}>
        切换
      </button>
      <button type="button" onClick={next}>
        下一台
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

  afterEach(() => {
    vi.useRealTimers();
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
    expect(audio.src).toBe("https://lhttp.qingting.fm/live/4915/64k.mp3");

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

  it("records played stations even when playback starts synchronously", async () => {
    const onPlayedStation = vi.fn();
    const user = userEvent.setup();

    audio.play.mockImplementationOnce(async () => {
      audio.emit("playing");
    });

    render(
      <AudioPlayerProvider onPlayedStation={onPlayedStation}>
        <AudioHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "播放" }));

    await waitFor(() => {
      expect(onPlayedStation).toHaveBeenCalledWith(stationFixture);
    });
  });

  it("forces a reload when retrying the current station", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <AudioHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "播放" }));
    await user.click(screen.getByRole("button", { name: "播放" }));

    expect(audio.load).toHaveBeenCalledTimes(2);
    expect(audio.play).toHaveBeenCalledTimes(2);
  });

  it("reloads the current station when recovering from a playback error", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <AudioHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "播放" }));
    act(() => {
      audio.emit("error");
    });

    await user.click(screen.getByRole("button", { name: "切换" }));

    expect(audio.load).toHaveBeenCalledTimes(2);
    expect(audio.play).toHaveBeenCalledTimes(2);
  });

  it("reloads the live stream when resuming the current station after pause", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <AudioHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "播放" }));
    act(() => {
      audio.emit("playing");
    });

    await user.click(screen.getByRole("button", { name: "切换" }));
    expect(audio.pause).toHaveBeenCalledTimes(1);

    await user.click(screen.getByRole("button", { name: "切换" }));

    expect(audio.load).toHaveBeenCalledTimes(2);
    expect(audio.play).toHaveBeenCalledTimes(2);
  });

  it("reloads when next resolves to the same station", async () => {
    const user = userEvent.setup();

    render(
      <AudioPlayerProvider>
        <AudioHarness />
      </AudioPlayerProvider>
    );

    await user.click(screen.getByRole("button", { name: "播放" }));
    await user.click(screen.getByRole("button", { name: "下一台" }));

    expect(audio.load).toHaveBeenCalledTimes(2);
    expect(audio.play).toHaveBeenCalledTimes(2);
  });

  it("keeps playing through transient stalled events without reloading the stream", async () => {
    vi.useFakeTimers();

    render(
      <AudioPlayerProvider>
        <AudioHarness />
      </AudioPlayerProvider>
    );

    act(() => {
      fireEvent.click(screen.getByRole("button", { name: "播放" }));
    });
    expect(audio.play).toHaveBeenCalledTimes(1);
    act(() => {
      audio.emit("playing");
      audio.emit("stalled");
    });

    expect(audio.play).toHaveBeenCalledTimes(1);

    await act(async () => {
      vi.advanceTimersByTime(1500);
      await Promise.resolve();
    });

    expect(audio.load).toHaveBeenCalledTimes(1);
    expect(audio.play).toHaveBeenCalledTimes(1);
    expect(screen.getByLabelText("播放错误")).toHaveTextContent("");
  });

  it("keeps the initial stream request alive when the browser reports stalled while buffering", async () => {
    vi.useFakeTimers();

    render(
      <AudioPlayerProvider>
        <AudioHarness />
      </AudioPlayerProvider>
    );

    act(() => {
      fireEvent.click(screen.getByRole("button", { name: "播放" }));
    });
    await act(async () => {
      await Promise.resolve();
    });
    act(() => {
      audio.emit("stalled");
    });

    await act(async () => {
      vi.advanceTimersByTime(1500);
      await Promise.resolve();
    });

    expect(audio.load).toHaveBeenCalledTimes(1);
    expect(audio.play).toHaveBeenCalledTimes(1);
    expect(screen.getByLabelText("播放错误")).toHaveTextContent("");
  });
});
