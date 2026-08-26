import { fetchTopStations } from "@/server/radioBrowser";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { GET } from "./route";

vi.mock("@/server/radioBrowser", () => ({
  fetchTopStations: vi.fn(async () => []),
}));

describe("/api/stations/top", () => {
  beforeEach(() => {
    vi.mocked(fetchTopStations).mockClear();
  });

  it("defaults limit to 20", async () => {
    await GET(new Request("http://localhost/api/stations/top"));

    expect(fetchTopStations).toHaveBeenCalledWith(20);
  });

  it("clamps negative limit to 1", async () => {
    await GET(new Request("http://localhost/api/stations/top?limit=-4"));

    expect(fetchTopStations).toHaveBeenCalledWith(1);
  });

  it("clamps large limit to 50", async () => {
    await GET(new Request("http://localhost/api/stations/top?limit=500"));

    expect(fetchTopStations).toHaveBeenCalledWith(50);
  });

  it("parses decimal limit as an integer", async () => {
    await GET(new Request("http://localhost/api/stations/top?limit=3.9"));

    expect(fetchTopStations).toHaveBeenCalledWith(3);
  });
});
