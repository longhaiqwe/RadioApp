import type { WaitlistSubmission } from "@/features/waitlist/waitlistSchema";
import { describe, expect, it, vi } from "vitest";
import { saveWaitlistSubmission } from "./waitlistRepository";

const submission: WaitlistSubmission = {
  email: "user@example.com",
  source: "recognition",
  stationId: "station-1",
  userAgent: "Mozilla",
};

function createSupabaseClient(error: unknown = null) {
  const upsert = vi.fn(async (...args: unknown[]) => {
    void args;
    return { error };
  });
  const from = vi.fn(() => ({ upsert }));

  return {
    client: { from },
    from,
    upsert,
  };
}

describe("waitlistRepository", () => {
  it("upserts waitlist submissions by email", async () => {
    const { client, from, upsert } = createSupabaseClient();

    const result = await saveWaitlistSubmission(client, submission);

    expect(result).toEqual({ ok: true });
    expect(from).toHaveBeenCalledWith("waitlist_submissions");
    expect(upsert).toHaveBeenCalledWith(
      {
        email: "user@example.com",
        source: "recognition",
        station_id: "station-1",
        user_agent: "Mozilla",
        updated_at: expect.any(String),
      },
      { onConflict: "email" }
    );
    const [row] = upsert.mock.calls[0] as [{ updated_at: string }, unknown];
    expect(Date.parse(row.updated_at)).not.toBeNaN();
  });

  it("returns a safe error when Supabase fails", async () => {
    const { client } = createSupabaseClient(new Error("database failed"));

    const result = await saveWaitlistSubmission(client, submission);

    expect(result).toEqual({
      ok: false,
      error: "暂时无法加入等待名单，请稍后再试。",
    });
  });
});
