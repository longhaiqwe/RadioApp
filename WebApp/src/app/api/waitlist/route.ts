import { parseWaitlistRequest } from "@/features/waitlist/waitlistSchema";
import { createSupabaseAdminClient } from "@/lib/supabaseAdmin";
import { saveWaitlistSubmission } from "@/server/waitlistRepository";

const WAITLIST_SAVE_ERROR = "暂时无法加入等待名单，请稍后再试。";

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = parseWaitlistRequest(body);

  if (!parsed.ok) {
    return Response.json({ error: parsed.error }, { status: 400 });
  }

  const clientResult = (() => {
    try {
      return { ok: true as const, client: createSupabaseAdminClient() };
    } catch {
      return { ok: false as const };
    }
  })();

  if (!clientResult.ok) {
    return Response.json({ error: WAITLIST_SAVE_ERROR }, { status: 502 });
  }

  const result = await saveWaitlistSubmission(clientResult.client, parsed.value);

  if (!result.ok) {
    return Response.json({ error: WAITLIST_SAVE_ERROR }, { status: 502 });
  }

  return Response.json({ ok: true });
}
