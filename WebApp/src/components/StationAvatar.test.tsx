import { render, screen } from "@testing-library/react";
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
});
