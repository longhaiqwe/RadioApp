import { describe, expect, it } from "vitest";
import { secondStationFixture, stationFixture } from "@/test/fixtures";
import {
  dedupeStationsById,
  filterMusicStations,
  pickRandomStation,
} from "./stationFilters";

describe("stationFilters", () => {
  it("keeps stations with music only in tags", () => {
    const taggedMusicStation = {
      ...stationFixture,
      id: "tagged-music",
      stationuuid: "tagged-music",
      name: "Late Night City",
      tags: "jazz",
    };

    expect(filterMusicStations([taggedMusicStation])).toEqual([
      taggedMusicStation,
    ]);
  });

  it("keeps stations with music only in name", () => {
    const namedMusicStation = {
      ...stationFixture,
      id: "named-music",
      stationuuid: "named-music",
      name: "Classical Harbor",
      tags: "",
    };

    expect(filterMusicStations([namedMusicStation])).toEqual([
      namedMusicStation,
    ]);
  });

  it("keeps existing music fixtures while excluding non-music stations", () => {
    const newsRadioStation = {
      ...stationFixture,
      id: "news",
      stationuuid: "news",
      name: "News Radio",
      tags: "news,talk",
    };
    const sportsFmStation = {
      ...stationFixture,
      id: "sports",
      stationuuid: "sports",
      name: "Sports FM",
      tags: "sports",
    };
    const trafficFmStation = {
      ...stationFixture,
      id: "traffic",
      stationuuid: "traffic",
      name: "Traffic FM",
      tags: "traffic",
    };

    const stations = filterMusicStations([
      stationFixture,
      secondStationFixture,
      newsRadioStation,
      sportsFmStation,
      trafficFmStation,
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

  it("returns null when no station can be picked", () => {
    expect(pickRandomStation([], undefined, () => 0)).toBeNull();
    expect(
      pickRandomStation([stationFixture], "station-1", () => 0)
    ).toBeNull();
  });
});
