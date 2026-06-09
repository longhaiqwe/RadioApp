import { describe, expect, it } from "vitest";
import { normalizeStation, normalizeStations } from "./stationNormalization";

describe("stationNormalization", () => {
  it("maps radio-browser snake_case fields to the web Station type", () => {
    const station = normalizeStation({
      changeuuid: "change-1",
      stationuuid: "station-1",
      name: "清晨音乐台",
      url: "http://example.com/live.mp3",
      url_resolved: "http://cdn.example.com/live.mp3",
      homepage: "https://example.com",
      favicon: "",
      tags: "music,pop",
      country: "China",
      countrycode: "CN",
      state: "Kwangsi",
      language: "chinese",
      languagecodes: "zh",
      votes: 42,
      codec: "MP3",
      bitrate: 128,
      hls: 0,
      lastcheckok: 1,
      clickcount: 7,
      clicktrend: 3,
    });

    expect(station).toEqual({
      changeuuid: "change-1",
      stationuuid: "station-1",
      id: "station-1",
      name: "清晨音乐台",
      url: "http://example.com/live.mp3",
      urlResolved: "http://cdn.example.com/live.mp3",
      homepage: "https://example.com",
      favicon: "",
      tags: "music,pop",
      country: "China",
      countrycode: "CN",
      state: "Kwangsi",
      language: "chinese",
      languagecodes: "zh",
      votes: 42,
      codec: "MP3",
      bitrate: 128,
      hls: 0,
      lastcheckok: 1,
      clickcount: 7,
      clicktrend: 3,
    });
  });

  it("uses url when url_resolved is missing", () => {
    const station = normalizeStation({
      stationuuid: "station-2",
      name: "Fallback FM",
      url: "https://example.com/fallback.mp3",
    });

    expect(station.urlResolved).toBe("https://example.com/fallback.mp3");
  });

  it("filters invalid stations from arrays", () => {
    const stations = normalizeStations([
      { stationuuid: "ok", name: "OK FM", url: "https://example.com/ok.mp3" },
      { stationuuid: "", name: "No ID", url: "https://example.com/no-id.mp3" },
      { stationuuid: "no-url", name: "No URL", url: "" },
    ]);

    expect(stations.map((station) => station.id)).toEqual(["ok"]);
  });
});
