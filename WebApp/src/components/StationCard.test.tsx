import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { stationFixture } from "@/test/fixtures";
import { StationCard } from "./StationCard";

describe("StationCard", () => {
  it("renders station metadata and starts playback", async () => {
    const onPlay = vi.fn();
    const user = userEvent.setup();

    render(
      <StationCard
        station={stationFixture}
        isPlaying={false}
        isFavorite={false}
        onPlay={onPlay}
        onToggleFavorite={vi.fn()}
      />,
    );

    expect(screen.getByText("清晨音乐台")).toBeInTheDocument();
    expect(screen.getByText("music,pop music")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "播放 清晨音乐台" }));
    expect(onPlay).toHaveBeenCalledWith(stationFixture);
  });

  it("toggles favorite without starting playback", async () => {
    const onPlay = vi.fn();
    const onToggleFavorite = vi.fn();
    const user = userEvent.setup();

    render(
      <StationCard
        station={stationFixture}
        isPlaying={false}
        isFavorite={false}
        onPlay={onPlay}
        onToggleFavorite={onToggleFavorite}
      />,
    );

    await user.click(screen.getByRole("button", { name: "收藏 清晨音乐台" }));
    expect(onToggleFavorite).toHaveBeenCalledWith(stationFixture);
    expect(onPlay).not.toHaveBeenCalled();
  });
});
