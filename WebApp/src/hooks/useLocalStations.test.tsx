import { act, renderHook } from "@testing-library/react";
import { beforeEach, describe, expect, it } from "vitest";
import { stationFixture } from "@/test/fixtures";
import { useLocalStations } from "./useLocalStations";

describe("useLocalStations", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("hydrates from local storage on first render", () => {
    window.localStorage.setItem(
      "radioapp:web:favorites",
      JSON.stringify([stationFixture])
    );

    const { result } = renderHook(() =>
      useLocalStations("radioapp:web:favorites", 30)
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
      useLocalStations("radioapp:web:recent", 1)
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
    ]);
  });
});
