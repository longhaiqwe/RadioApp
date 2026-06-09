import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  fetchRandomStation,
  fetchSearchStations,
  fetchTopStations,
} from "./radioBrowser";

const stationResponse = [
  {
    stationuuid: "station-1",
    name: "清晨音乐台",
    url: "http://example.com/live.mp3",
    url_resolved: "http://example.com/live.mp3",
    tags: "music",
    countrycode: "CN",
    lastcheckok: 1,
  },
];

describe("radioBrowser", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it("posts top station search payload to a mirror", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(new Response(JSON.stringify(stationResponse)));

    const stations = await fetchTopStations();

    expect(stations[0]?.id).toBe("station-1");
    expect(fetchMock).toHaveBeenCalledWith(
      "https://de1.api.radio-browser.info/json/stations/search",
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({
          "Content-Type": "application/json",
          "User-Agent": "RadioApp-Web/1.0",
        }),
        signal: expect.any(AbortSignal),
      })
    );
  });

  it("falls back to the next mirror when the first mirror fails", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockRejectedValueOnce(new Error("network"))
      .mockResolvedValueOnce(new Response(JSON.stringify(stationResponse)));

    const stations = await fetchTopStations();

    expect(stations).toHaveLength(1);
  });

  it("falls back to presets when top stations response is empty", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify([]))
    );

    const stations = await fetchTopStations(2);

    expect(stations).toHaveLength(2);
    expect(stations[0]?.id).not.toBe("station-1");
  });

  it("falls back to presets when top stations response has no music", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify([
          {
            stationuuid: "station-talk",
            name: "交通广播",
            url: "http://example.com/traffic.mp3",
            tags: "talk",
          },
        ])
      )
    );

    const stations = await fetchTopStations(1);

    expect(stations).toHaveLength(1);
    expect(stations[0]?.id).not.toBe("station-talk");
  });

  it("returns search results filtered by all keywords", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify([
          ...stationResponse,
          {
            stationuuid: "station-2",
            name: "交通广播",
            url: "http://example.com/traffic.mp3",
            tags: "talk",
          },
        ])
      )
    );

    const stations = await fetchSearchStations("清晨 音乐");

    expect(stations.map((station) => station.name)).toEqual(["清晨音乐台"]);
  });

  it("falls back to presets for random station when all candidates are excluded", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify(stationResponse))
    );

    const station = await fetchRandomStation("station-1");

    expect(station).not.toBeNull();
    expect(station?.id).not.toBe("station-1");
  });

  it("falls back to presets for random station when upstream has no music", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify([
          {
            stationuuid: "station-talk",
            name: "交通广播",
            url: "http://example.com/traffic.mp3",
            tags: "talk",
          },
        ])
      )
    );

    const station = await fetchRandomStation();

    expect(station).not.toBeNull();
    expect(station?.id).not.toBe("station-talk");
  });
});
