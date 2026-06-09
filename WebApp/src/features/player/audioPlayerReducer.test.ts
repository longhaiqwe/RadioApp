import { describe, expect, it } from "vitest";
import { stationFixture, secondStationFixture } from "@/test/fixtures";
import {
  audioPlayerReducer,
  initialAudioPlayerState,
} from "./audioPlayerReducer";

describe("audioPlayerReducer", () => {
  it("starts a station with playlist context", () => {
    const state = audioPlayerReducer(initialAudioPlayerState, {
      type: "playStation",
      station: stationFixture,
      playlist: [stationFixture, secondStationFixture],
      playlistTitle: "发现",
    });

    expect(state.currentStation?.id).toBe("station-1");
    expect(state.playlistTitle).toBe("发现");
    expect(state.isLoading).toBe(true);
    expect(state.playbackError).toBeNull();
  });

  it("moves to next and previous stations", () => {
    const playing = audioPlayerReducer(initialAudioPlayerState, {
      type: "playStation",
      station: stationFixture,
      playlist: [stationFixture, secondStationFixture],
      playlistTitle: "发现",
    });

    const next = audioPlayerReducer(playing, { type: "next" });
    expect(next.currentStation?.id).toBe("station-2");

    const previous = audioPlayerReducer(next, { type: "previous" });
    expect(previous.currentStation?.id).toBe("station-1");
  });

  it("stores playback error without clearing station", () => {
    const playing = audioPlayerReducer(initialAudioPlayerState, {
      type: "playStation",
      station: stationFixture,
      playlist: [stationFixture],
      playlistTitle: "发现",
    });

    const failed = audioPlayerReducer(playing, {
      type: "playbackError",
      message: "该电台暂不支持浏览器播放。",
    });

    expect(failed.currentStation?.id).toBe("station-1");
    expect(failed.isPlaying).toBe(false);
    expect(failed.playbackError).toBe("该电台暂不支持浏览器播放。");
  });
});
