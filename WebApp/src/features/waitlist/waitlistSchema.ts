export type WaitlistSource = "recognition" | "player" | "settings";

export type WaitlistSubmission = {
  email: string;
  source: WaitlistSource;
  stationId: string | null;
  userAgent: string | null;
};

type ParseWaitlistRequestResult =
  | { ok: true; value: WaitlistSubmission }
  | { ok: false; error: string };

export const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
export const MAX_WAITLIST_EMAIL_LENGTH = 320;
export const MAX_WAITLIST_STATION_ID_LENGTH = 128;
export const MAX_WAITLIST_USER_AGENT_LENGTH = 512;

const VALID_SOURCES = new Set<WaitlistSource>([
  "recognition",
  "player",
  "settings",
]);

function nullableTrimmedString(value: unknown, maxLength: number): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  if (trimmed.length === 0) {
    return null;
  }

  return trimmed.slice(0, maxLength);
}

function parseSource(value: unknown): WaitlistSource {
  if (typeof value === "string" && VALID_SOURCES.has(value as WaitlistSource)) {
    return value as WaitlistSource;
  }

  return "recognition";
}

export function normalizeWaitlistEmail(value: unknown): string {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

export function isValidWaitlistEmail(email: string): boolean {
  return (
    email.length > 0 &&
    email.length <= MAX_WAITLIST_EMAIL_LENGTH &&
    EMAIL_PATTERN.test(email)
  );
}

export function parseWaitlistRequest(
  input: unknown
): ParseWaitlistRequestResult {
  const body =
    input !== null && typeof input === "object"
      ? (input as Record<string, unknown>)
      : {};
  const email = normalizeWaitlistEmail(body.email);

  if (!isValidWaitlistEmail(email)) {
    return {
      ok: false,
      error: "请输入有效邮箱地址。",
    };
  }

  return {
    ok: true,
    value: {
      email,
      source: parseSource(body.source),
      stationId: nullableTrimmedString(
        body.stationId,
        MAX_WAITLIST_STATION_ID_LENGTH
      ),
      userAgent: nullableTrimmedString(
        body.userAgent,
        MAX_WAITLIST_USER_AGENT_LENGTH
      ),
    },
  };
}
