import { beforeEach, describe, expect, it, vi } from "vitest";
import { useStationSearch } from "./useStations";

const swrMock = vi.fn();

vi.mock("swr", () => ({
  default: (...args: unknown[]) => swrMock(...args),
}));

describe("useStationSearch", () => {
  beforeEach(() => {
    swrMock.mockReset();
    swrMock.mockReturnValue({
      data: [],
      error: null,
      isLoading: false,
    });
  });

  it("normalizes the search key to avoid whitespace cache misses", () => {
    useStationSearch("  jazz  ");

    expect(swrMock).toHaveBeenCalledWith(
      ["stations:search", "jazz"],
      expect.any(Function),
    );
  });

  it("skips empty trimmed queries", () => {
    useStationSearch("   ");

    expect(swrMock).toHaveBeenCalledWith(null, expect.any(Function));
  });
});
