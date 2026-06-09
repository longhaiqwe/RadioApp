import { fetchRandomStation } from "@/server/radioBrowser";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { GET } from "./route";

vi.mock("@/server/radioBrowser", () => ({
  fetchRandomStation: vi.fn(async () => null),
}));

describe("/api/stations/random", () => {
  beforeEach(() => {
    vi.mocked(fetchRandomStation).mockClear();
  });

  it("trims exclude before fetching a random station", async () => {
    await GET(
      new Request("http://localhost/api/stations/random?exclude=%20abc%20")
    );

    expect(fetchRandomStation).toHaveBeenCalledWith("abc");
  });

  it("treats blank exclude as undefined", async () => {
    await GET(new Request("http://localhost/api/stations/random?exclude=%20"));

    expect(fetchRandomStation).toHaveBeenCalledWith(undefined);
  });
});
