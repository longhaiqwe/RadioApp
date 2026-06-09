import { parseWaitlistRequest } from "@/features/waitlist/waitlistSchema";
import { createSupabaseAdminClient } from "@/lib/supabaseAdmin";
import { saveWaitlistSubmission } from "@/server/waitlistRepository";

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = parseWaitlistRequest(body);

  if (!parsed.ok) {
    return Response.json({ error: parsed.error }, { status: 400 });
  }

  const result = await saveWaitlistSubmission(
    createSupabaseAdminClient(),
    parsed.value
  );

  if (!result.ok) {
    return Response.json({ error: result.error }, { status: 502 });
  }

  return Response.json({ ok: true });
}
