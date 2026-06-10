import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { StationAvatar } from "./StationAvatar";

describe("StationAvatar", () => {
  it("renders a remote image when favicon exists", () => {
    render(
      <StationAvatar
        name="清晨音乐台"
        stationId="station-1"
        favicon="https://example.com/favicon.png"
      />,
    );

    expect(screen.getByAltText("清晨音乐台")).toHaveAttribute(
      "src",
      "https://example.com/favicon.png",
    );
  });

  it("renders branded initials when favicon is empty", () => {
    render(<StationAvatar name="清晨音乐台" stationId="station-1" favicon="" />);

    expect(screen.getByText("清")).toBeInTheDocument();
  });

  it("renders branded initials for insecure favicons blocked on https pages", () => {
    render(
      <StationAvatar
        name="怀集音乐之声"
        stationId="station-2"
        favicon="http://www.hj0758.cn/favicon.ico"
      />,
    );

    expect(screen.queryByAltText("怀集音乐之声")).not.toBeInTheDocument();
    expect(screen.getByText("怀")).toBeInTheDocument();
  });

  it("falls back to the branded initial when a remote favicon fails", () => {
    render(
      <StationAvatar
        name="清晨音乐台"
        stationId="station-1"
        favicon="https://example.com/broken.png"
      />,
    );

    fireEvent.error(screen.getByAltText("清晨音乐台"));

    expect(screen.queryByAltText("清晨音乐台")).not.toBeInTheDocument();
    expect(screen.getByText("清")).toBeInTheDocument();
  });

  it("derives fallback gradient styling from stationId", () => {
    const { container } = render(
      <>
        <StationAvatar name="清晨音乐台" stationId="station-1" favicon="" />
        <StationAvatar name="清晨音乐台" stationId="station-2" favicon="" />
      </>,
    );

    const firstAvatar = container.querySelector('[data-station-id="station-1"]');
    const secondAvatar = container.querySelector('[data-station-id="station-2"]');

    expect(firstAvatar).toBeInTheDocument();
    expect(secondAvatar).toBeInTheDocument();
    expect(firstAvatar?.getAttribute("style")).toBeTruthy();
    expect(secondAvatar?.getAttribute("style")).toBeTruthy();
    expect(firstAvatar?.getAttribute("style")).not.toEqual(
      secondAvatar?.getAttribute("style"),
    );
  });
});
