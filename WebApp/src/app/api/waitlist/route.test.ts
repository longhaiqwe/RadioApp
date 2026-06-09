import { createSupabaseAdminClient } from "@/lib/supabaseAdmin";
import { saveWaitlistSubmission } from "@/server/waitlistRepository";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { POST } from "./route";

vi.mock("@/lib/supabaseAdmin", () => ({
  createSupabaseAdminClient: vi.fn(() => ({ from: vi.fn() })),
}));

vi.mock("@/server/waitlistRepository", () => ({
  saveWaitlistSubmission: vi.fn(async () => ({ ok: true })),
}));

const SAFE_SAVE_ERROR = "暂时无法加入等待名单，请稍后再试。";
const INVALID_EMAIL_ERROR = "请输入有效邮箱地址。";

async function readJson(response: Response) {
  return response.json() as Promise<unknown>;
}

describe("/api/waitlist", () => {
  beforeEach(() => {
    const client = { from: vi.fn() } as unknown as ReturnType<
      typeof createSupabaseAdminClient
    >;

    vi.mocked(createSupabaseAdminClient).mockReset();
    vi.mocked(createSupabaseAdminClient).mockReturnValue(client);
    vi.mocked(saveWaitlistSubmission).mockReset();
    vi.mocked(saveWaitlistSubmission).mockResolvedValue({ ok: true });
  });

  it("returns validation error for invalid JSON body", async () => {
    const response = await POST(
      new Request("http://localhost/api/waitlist", {
        method: "POST",
        body: "{",
      })
    );

    expect(response.status).toBe(400);
    expect(await readJson(response)).toEqual({ error: INVALID_EMAIL_ERROR });
    expect(createSupabaseAdminClient).not.toHaveBeenCalled();
    expect(saveWaitlistSubmission).not.toHaveBeenCalled();
  });

  it("returns validation error for invalid email", async () => {
    const response = await POST(
      new Request("http://localhost/api/waitlist", {
        method: "POST",
        body: JSON.stringify({ email: "not-email", source: "recognition" }),
      })
    );

    expect(response.status).toBe(400);
    expect(await readJson(response)).toEqual({ error: INVALID_EMAIL_ERROR });
    expect(createSupabaseAdminClient).not.toHaveBeenCalled();
    expect(saveWaitlistSubmission).not.toHaveBeenCalled();
  });

  it("returns safe error when admin client creation fails", async () => {
    vi.mocked(createSupabaseAdminClient).mockImplementation(() => {
      throw new Error("missing env");
    });

    const response = await POST(
      new Request("http://localhost/api/waitlist", {
        method: "POST",
        body: JSON.stringify({ email: "user@example.com" }),
      })
    );

    expect(response.status).toBe(502);
    expect(await readJson(response)).toEqual({ error: SAFE_SAVE_ERROR });
    expect(saveWaitlistSubmission).not.toHaveBeenCalled();
  });

  it("returns safe error when repository save fails", async () => {
    vi.mocked(saveWaitlistSubmission).mockResolvedValue({
      ok: false,
      error: SAFE_SAVE_ERROR,
    });

    const response = await POST(
      new Request("http://localhost/api/waitlist", {
        method: "POST",
        body: JSON.stringify({ email: "user@example.com" }),
      })
    );

    expect(response.status).toBe(502);
    expect(await readJson(response)).toEqual({ error: SAFE_SAVE_ERROR });
  });

  it("returns ok on success", async () => {
    const response = await POST(
      new Request("http://localhost/api/waitlist", {
        method: "POST",
        body: JSON.stringify({
          email: " USER@Example.COM ",
          source: "player",
          stationId: " station-1 ",
          userAgent: " Mozilla ",
        }),
      })
    );

    expect(response.status).toBe(200);
    expect(await readJson(response)).toEqual({ ok: true });
    expect(saveWaitlistSubmission).toHaveBeenCalledWith(expect.anything(), {
      email: "user@example.com",
      source: "player",
      stationId: "station-1",
      userAgent: "Mozilla",
    });
  });
});
