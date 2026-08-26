import { act, renderHook } from "@testing-library/react";
import { beforeEach, describe, expect, it } from "vitest";
import { secondStationFixture, stationFixture } from "@/test/fixtures";
import { useLocalStations } from "./useLocalStations";

describe("useLocalStations", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("hydrates from local storage on first render", () => {
    window.localStorage.setItem(
      "radioapp:web:favorites",
      JSON.stringify([
        stationFixture,
        stationFixture,
        {
          ...stationFixture,
          id: "station-2",
          stationuuid: "station-2",
          name: "Second",
        },
      ])
    );

    const { result } = renderHook(() =>
      useLocalStations("radioapp:web:favorites", 1)
    );

    expect(result.current.stations).toEqual([stationFixture]);
    expect(result.current.hasStation(stationFixture.id)).toBe(true);
  });

  it("adds and removes favorite stations", () => {
    const { result } = renderHook(() =>
      useLocalStations("radioapp:web:favorites", 30)
    );

    act(() => result.current.addStation(stationFixture));
    expect(result.current.stations).toEqual([stationFixture]);
    expect(result.current.hasStation(stationFixture.id)).toBe(true);

    act(() => result.current.removeStation(stationFixture.id));
    expect(result.current.stations).toEqual([]);
  });

  it("keeps the newest station at the front and caps length", () => {
    const { result } = renderHook(() =>
      useLocalStations("radioapp:web:recent", 2)
    );

    act(() => result.current.addStation(stationFixture));
    act(() =>
      result.current.addStation({
        ...stationFixture,
        id: "station-2",
        stationuuid: "station-2",
        name: "Second",
      })
    );

    expect(result.current.stations.map((station) => station.id)).toEqual([
      "station-2",
      "station-1",
    ]);
  });

  it("syncs multiple consumers of the same key", () => {
    const first = renderHook(() => useLocalStations("radioapp:web:recent", 30));
    const second = renderHook(() => useLocalStations("radioapp:web:recent", 30));

    act(() => first.result.current.addStation(stationFixture));

    expect(second.result.current.stations).toEqual([stationFixture]);
    expect(second.result.current.hasStation(stationFixture.id)).toBe(true);
  });

  it("re-hydrates when the storage key changes", () => {
    window.localStorage.setItem(
      "radioapp:web:favorites",
      JSON.stringify([stationFixture])
    );
    window.localStorage.setItem(
      "radioapp:web:recent",
      JSON.stringify([secondStationFixture])
    );

    const { result, rerender } = renderHook(
      ({ storageKey }) => useLocalStations(storageKey, 30),
      {
        initialProps: { storageKey: "radioapp:web:favorites" },
      }
    );

    expect(result.current.stations).toEqual([stationFixture]);

    rerender({ storageKey: "radioapp:web:recent" });
    expect(result.current.stations).toEqual([secondStationFixture]);
  });

  it("drops shape-mismatched stored payloads", () => {
    window.localStorage.setItem(
      "radioapp:web:favorites",
      JSON.stringify([
        null,
        { id: 123 },
        { id: "station-bad" },
        { id: "playable-but-partial", url: "https://example.com/live.mp3" },
        stationFixture,
      ])
    );

    const { result } = renderHook(() =>
      useLocalStations("radioapp:web:favorites", 30)
    );

    expect(result.current.stations).toEqual([stationFixture]);
  });
});
