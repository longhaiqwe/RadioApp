import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import Home from "./page";

class MockAudio {
  src = "";
  volume = 0.5;
  play = vi.fn(async () => undefined);
  pause = vi.fn();
  load = vi.fn();

  addEventListener() {}

  removeEventListener() {}
}

vi.mock("@/hooks/useStations", () => ({
  useTopStations: () => ({
    data: [],
    error: null,
    isLoading: false,
    mutate: vi.fn(),
  }),
  useStationSearch: () => ({
    data: [],
    error: null,
    isLoading: false,
  }),
}));

vi.stubGlobal("Audio", vi.fn(() => new MockAudio()));

describe("Home page", () => {
  it("renders the RadioApp web shell", () => {
    render(<Home />);

    expect(screen.getByText("发现")).toBeInTheDocument();
    expect(screen.getByText("探索全球电台")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "发现" })
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "搜索" })
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "收藏" })
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "最近" })
    ).toBeInTheDocument();
  });
});
