import { isIP } from "node:net";
import { transcodeStreamToMp3 } from "@/server/audioTranscode";

const STREAM_FETCH_ERROR = "STREAM_FETCH_FAILED";
const INVALID_STREAM_URL = "INVALID_STREAM_URL";
const STREAM_FETCH_TIMEOUT_MS = 10000;
const STREAM_USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";

export const runtime = "nodejs";

export async function GET(request: Request) {
  const sourceUrl = readSourceUrl(request);
  if (!sourceUrl || !isAllowedStreamUrl(sourceUrl)) {
    return Response.json({ error: INVALID_STREAM_URL }, { status: 400 });
  }

  if (shouldTranscodeToMp3(request)) {
    return new Response(
      transcodeStreamToMp3({
        streamUrl: sourceUrl.toString(),
        signal: request.signal,
      }),
      {
        headers: {
          "content-type": "audio/mpeg",
          "cache-control": "no-store",
          "x-content-type-options": "nosniff",
        },
      }
    );
  }

  const abortController = new AbortController();
  const timeoutId = setTimeout(
    () => abortController.abort(),
    STREAM_FETCH_TIMEOUT_MS
  );

  try {
    const response = await fetch(sourceUrl.toString(), {
      headers: buildUpstreamHeaders(request),
      signal: abortController.signal,
      cache: "no-store",
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      return Response.json({ error: STREAM_FETCH_ERROR }, { status: 502 });
    }

    const contentType = response.headers.get("content-type") || "audio/mpeg";
    if (!isStreamContentType(contentType)) {
      return Response.json({ error: STREAM_FETCH_ERROR }, { status: 502 });
    }

    return new Response(response.body, {
      status: response.status,
      headers: buildClientHeaders(response.headers, contentType),
    });
  } catch {
    return Response.json({ error: STREAM_FETCH_ERROR }, { status: 502 });
  } finally {
    clearTimeout(timeoutId);
  }
}

function shouldTranscodeToMp3(request: Request) {
  return new URL(request.url).searchParams.get("transcode") === "mp3";
}

function readSourceUrl(request: Request) {
  const rawUrl = new URL(request.url).searchParams.get("url");
  if (!rawUrl) return null;

  try {
    return new URL(rawUrl);
  } catch {
    return null;
  }
}

function buildUpstreamHeaders(request: Request) {
  const headers: Record<string, string> = {
    Accept: "audio/*,application/vnd.apple.mpegurl,application/x-mpegurl,*/*;q=0.8",
    "User-Agent": STREAM_USER_AGENT,
  };
  const range = request.headers.get("range");
  if (range) {
    headers.Range = range;
  }

  return headers;
}

function buildClientHeaders(upstreamHeaders: Headers, contentType: string) {
  const headers = new Headers({
    "content-type": contentType,
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
  });

  for (const header of [
    "accept-ranges",
    "content-length",
    "content-range",
    "icy-br",
    "icy-genre",
    "icy-name",
    "icy-url",
  ]) {
    const value = upstreamHeaders.get(header);
    if (value) {
      headers.set(header, value);
    }
  }

  return headers;
}

function isAllowedStreamUrl(url: URL) {
  if (url.protocol !== "http:" && url.protocol !== "https:") return false;
  if (url.username || url.password) return false;

  const hostname = url.hostname.toLowerCase();
  if (!hostname) return false;
  if (
    hostname === "localhost" ||
    hostname === "0" ||
    hostname.endsWith(".localhost") ||
    hostname.endsWith(".local")
  ) {
    return false;
  }

  const ipVersion = isIP(hostname);
  if (ipVersion === 4) return !isPrivateIpv4(hostname);
  if (ipVersion === 6) return !isPrivateIpv6(hostname);

  return true;
}

function isStreamContentType(contentType: string) {
  const normalized = contentType.toLowerCase();
  return (
    normalized.startsWith("audio/") ||
    normalized.includes("mpegurl") ||
    normalized.includes("ogg") ||
    normalized.includes("octet-stream")
  );
}

function isPrivateIpv4(hostname: string) {
  const [first = 0, second = 0] = hostname
    .split(".")
    .map((part) => Number.parseInt(part, 10));

  return (
    first === 0 ||
    first === 10 ||
    first === 127 ||
    first >= 224 ||
    (first === 100 && second >= 64 && second <= 127) ||
    (first === 169 && second === 254) ||
    (first === 172 && second >= 16 && second <= 31) ||
    (first === 192 && second === 168) ||
    (first === 198 && (second === 18 || second === 19))
  );
}

function isPrivateIpv6(hostname: string) {
  const normalized = hostname.toLowerCase();
  return (
    normalized === "::" ||
    normalized === "::1" ||
    normalized.startsWith("fc") ||
    normalized.startsWith("fd") ||
    normalized.startsWith("fe80:")
  );
}
