import type { WaitlistSubmission } from "@/features/waitlist/waitlistSchema";

const WAITLIST_SAVE_ERROR = "暂时无法加入等待名单，请稍后再试。";

type WaitlistRow = {
  email: string;
  source: string;
  station_id: string | null;
  user_agent: string | null;
  updated_at: string;
};

type SupabaseUpsertResult = {
  error: unknown;
};

export type SupabaseLikeClient = {
  from(table: string): {
    upsert(
      row: WaitlistRow,
      options: { onConflict: "email" }
    ): PromiseLike<SupabaseUpsertResult>;
  };
};

type SaveWaitlistSubmissionResult =
  | { ok: true }
  | { ok: false; error: string };

export async function saveWaitlistSubmission(
  client: SupabaseLikeClient,
  submission: WaitlistSubmission
): Promise<SaveWaitlistSubmissionResult> {
  try {
    const { error } = await client.from("waitlist_submissions").upsert(
      {
        email: submission.email,
        source: submission.source,
        station_id: submission.stationId,
        user_agent: submission.userAgent,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "email" }
    );

    if (error) {
      return {
        ok: false,
        error: WAITLIST_SAVE_ERROR,
      };
    }

    return { ok: true };
  } catch {
    return {
      ok: false,
      error: WAITLIST_SAVE_ERROR,
    };
  }
}
