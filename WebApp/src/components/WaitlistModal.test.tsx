import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { WaitlistModal } from "./WaitlistModal";

describe("WaitlistModal", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    window.localStorage.clear();
  });

  it("validates email before submitting", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch");
    const user = userEvent.setup();

    render(
      <WaitlistModal
        source="recognition"
        stationId="station-1"
        stationName="清晨音乐台"
        onClose={vi.fn()}
      />,
    );

    await user.type(screen.getByLabelText("邮箱地址"), "not-email");
    await user.click(screen.getByRole("button", { name: "加入等待名单" }));

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(screen.getByText("请输入有效邮箱地址。")).toBeInTheDocument();
  });

  it("submits a normalized payload and shows the success state", async () => {
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ ok: true })),
    );
    const user = userEvent.setup();

    render(
      <WaitlistModal
        source="recognition"
        stationId="station-1"
        stationName="清晨音乐台"
        onClose={vi.fn()}
      />,
    );

    await user.type(screen.getByLabelText("邮箱地址"), " USER@Example.com ");
    await user.click(screen.getByRole("button", { name: "加入等待名单" }));

    await waitFor(() => {
      expect(fetchSpy).toHaveBeenCalledWith(
        "/api/waitlist",
        expect.objectContaining({
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
        }),
      );
    });

    const request = fetchSpy.mock.calls[0]?.[1];
    expect(request).toBeDefined();
    expect(JSON.parse(String(request?.body))).toMatchObject({
      email: "user@example.com",
      source: "recognition",
      stationId: "station-1",
    });

    expect(await screen.findByText("已经帮你排上了")).toBeInTheDocument();
    expect(window.localStorage.getItem("radioapp:web:waitlist-email")).toBe(
      "user@example.com",
    );
  });

  it("shows duplicate success when the email was already submitted locally", async () => {
    window.localStorage.setItem("radioapp:web:waitlist-email", "user@example.com");
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ ok: true })),
    );
    const user = userEvent.setup();

    render(
      <WaitlistModal
        source="recognition"
        stationId={null}
        onClose={vi.fn()}
      />,
    );

    await user.click(screen.getByRole("button", { name: "加入等待名单" }));

    expect(
      await screen.findByText("这个邮箱已经在名单里了"),
    ).toBeInTheDocument();
  });
});
