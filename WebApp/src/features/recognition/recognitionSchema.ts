import type { RecognitionRequest } from "./recognitionTypes";

type RecognitionParseResult =
  | { ok: true; value: RecognitionRequest }
  | { ok: false; error: string };

const MISSING_STATION_ERROR = "请选择正在播放的电台后再识别。";
const UNSAFE_STREAM_URL_ERROR = "当前电台地址无法用于识别。";

export function parseRecognitionRequest(body: unknown): RecognitionParseResult {
  if (!isRecord(body)) {
    return { ok: false, error: MISSING_STATION_ERROR };
  }

  const streamUrl = readTrimmedString(body.streamUrl);
  if (!streamUrl) {
    return { ok: false, error: MISSING_STATION_ERROR };
  }

  if (!isSafeHttpStreamURL(streamUrl)) {
    return { ok: false, error: UNSAFE_STREAM_URL_ERROR };
  }

  return {
    ok: true,
    value: {
      streamUrl,
      stationId: readTrimmedString(body.stationId),
      stationName: readTrimmedString(body.stationName),
      languageHint: normalizeLanguageHint(readTrimmedString(body.languageHint)),
    },
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readTrimmedString(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function normalizeLanguageHint(languageHint: string | undefined) {
  if (!languageHint) return undefined;

  const normalized = languageHint.trim().toLowerCase();
  if (!normalized) return undefined;
  if (normalized.length === 2) return normalized;
  if (normalized.startsWith("zh")) return "zh";
  if (normalized.startsWith("en")) return "en";
  if (normalized.startsWith("ja")) return "ja";
  if (normalized.startsWith("ko")) return "ko";

  return normalized.slice(0, 2);
}

function isSafeHttpStreamURL(rawURL: string) {
  let url: URL;
  try {
    url = new URL(rawURL);
  } catch {
    return false;
  }

  if (url.protocol !== "http:" && url.protocol !== "https:") {
    return false;
  }

  return !isLocalOrPrivateHost(url.hostname);
}

function isLocalOrPrivateHost(hostname: string) {
  const host = hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (host === "localhost" || host === "::1" || host === "0.0.0.0") return true;
  if (host.startsWith("127.") || host.startsWith("169.254.")) return true;
  if (host.startsWith("10.") || host.startsWith("192.168.")) return true;

  const match = /^172\.(\d{1,2})\./.exec(host);
  if (!match) return false;

  const secondOctet = Number(match[1]);
  return secondOctet >= 16 && secondOctet <= 31;
}
