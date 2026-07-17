import { describe, expect, it } from "vitest";
import { presetStations } from "./presetStations";

describe("presetStations", () => {
  it("ships enough stations for a useful PWA first screen before the network refreshes", () => {
    expect(presetStations.length).toBeGreaterThanOrEqual(16);
  });

  it("keeps station ids unique so local fallback playlists do not collapse entries", () => {
    const stationIds = presetStations.map((station) => station.id);

    expect(new Set(stationIds).size).toBe(stationIds.length);
  });
});
