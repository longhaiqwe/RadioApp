import { describe, expect, it } from "vitest";
import { secondStationFixture, stationFixture } from "@/test/fixtures";
import {
  dedupeStationsById,
  filterMusicStations,
  pickRandomStation,
} from "./stationFilters";

describe("stationFilters", () => {
  it("keeps music-like stations by tag or name", () => {
    const newsStation = {
      ...stationFixture,
      id: "news",
      stationuuid: "news",
      name: "Daily News",
      tags: "news,talk",
    };

    const stations = filterMusicStations([
      stationFixture,
      secondStationFixture,
      newsStation,
    ]);

    expect(stations.map((station) => station.id)).toEqual([
      "station-1",
      "station-2",
    ]);
  });

  it("deduplicates by station id", () => {
    const stations = dedupeStationsById([
      stationFixture,
      { ...stationFixture, name: "Duplicate Name" },
      secondStationFixture,
    ]);

    expect(stations.map((station) => station.id)).toEqual([
      "station-1",
      "station-2",
    ]);
  });

  it("picks a station while excluding current station", () => {
    const picked = pickRandomStation(
      [stationFixture, secondStationFixture],
      "station-1",
      () => 0
    );

    expect(picked?.id).toBe("station-2");
  });
});
