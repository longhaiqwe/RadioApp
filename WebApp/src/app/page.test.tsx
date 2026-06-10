import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { stationFixture } from "@/test/fixtures";
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
  it("shows favorites preview on the home tab when local favorites exist", () => {
    window.localStorage.setItem(
      "radioapp:web:favorites",
      JSON.stringify([stationFixture]),
    );

    render(<Home />);

    expect(screen.getByRole("heading", { name: "你的收藏" })).toBeInTheDocument();
    expect(screen.getByText("下次回来，不用重新找。")).toBeInTheDocument();
    expect(screen.getByText("清晨音乐台")).toBeInTheDocument();
  });

  it("renders the RadioApp web shell", () => {
    render(<Home />);

    expect(screen.getByRole("heading", { name: "发现" })).toBeInTheDocument();
    expect(screen.getByText("探索全球电台")).toBeInTheDocument();
    expect(
      screen.getByPlaceholderText("搜索电台、风格、地区...")
    ).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "推荐电台" })).toBeInTheDocument();
  });

  it("shows a no-results state after entering a search query with no matches", async () => {
    const user = userEvent.setup();

    render(<Home />);

    await user.type(
      screen.getByPlaceholderText("搜索电台、风格、地区..."),
      "ambient"
    );

    expect(screen.getByText("还没有找到匹配电台")).toBeInTheDocument();
    expect(
      screen.getByText("换个关键词，或者试试地区和频率。")
    ).toBeInTheDocument();
  });

  it("opens recent stations from the top-right action instead of showing them by default", async () => {
    const user = userEvent.setup();

    window.localStorage.setItem(
      "radioapp:web:recent",
      JSON.stringify([stationFixture]),
    );

    render(<Home />);

    expect(
      screen.queryByRole("heading", { name: "最近听过" }),
    ).not.toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "查看最近听过" }));

    expect(screen.getByRole("heading", { name: "最近听过" })).toBeInTheDocument();
    expect(
      screen.getByText("刚刚路过的好声音，会先留在这里。")
    ).toBeInTheDocument();
  });
});
