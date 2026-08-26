import { beforeEach, describe, expect, it, vi } from "vitest";
import { stationFixture } from "@/test/fixtures";
import { searchStations } from "./stationApi";

describe("searchStations", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it("trims the query before building the request URL", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ stations: [stationFixture] })),
    );

    await searchStations("  chill  ");

    expect(fetchSpy).toHaveBeenCalledWith("/api/stations/search?q=chill");
  });

  it("returns an empty list for blank queries without fetching", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ stations: [stationFixture] })),
    );

    await expect(searchStations("   ")).resolves.toEqual([]);
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});
