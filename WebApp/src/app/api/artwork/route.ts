const ARTWORK_HOSTS = ["music.126.net", "y.gtimg.cn"];

const ARTWORK_FETCH_ERROR = "ARTWORK_FETCH_FAILED";
const INVALID_ARTWORK_URL = "INVALID_ARTWORK_URL";

export const runtime = "nodejs";

export async function GET(request: Request) {
  const sourceUrl = readSourceUrl(request);
  const artworkUrl = sourceUrl ? normalizeAllowedArtworkUrl(sourceUrl) : null;

  if (!artworkUrl) {
    return Response.json({ error: INVALID_ARTWORK_URL }, { status: 400 });
  }

  const abortController = new AbortController();
  const timeoutId = setTimeout(() => abortController.abort(), 8000);

  try {
    const response = await fetch(artworkUrl.toString(), {
      headers: {
        Accept: "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
        "User-Agent":
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
      },
      signal: abortController.signal,
    });

    if (!response.ok) {
      return Response.json({ error: ARTWORK_FETCH_ERROR }, { status: 502 });
    }

    const contentType = response.headers.get("content-type") || "image/jpeg";
    if (!contentType.toLowerCase().startsWith("image/")) {
      return Response.json({ error: ARTWORK_FETCH_ERROR }, { status: 502 });
    }

    return new Response(await response.arrayBuffer(), {
      headers: {
        "content-type": contentType,
        "cache-control": "public, max-age=86400, stale-while-revalidate=604800",
      },
    });
  } catch {
    return Response.json({ error: ARTWORK_FETCH_ERROR }, { status: 502 });
  } finally {
    clearTimeout(timeoutId);
  }
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

function normalizeAllowedArtworkUrl(url: URL) {
  if (!isAllowedArtworkHost(url)) return null;

  const upgradedUrl = new URL(url.toString());
  if (upgradedUrl.protocol !== "http:" && upgradedUrl.protocol !== "https:") {
    return null;
  }

  upgradedUrl.protocol = "https:";
  if (isNetEaseArtworkHost(upgradedUrl)) {
    upgradedUrl.searchParams.set("param", "300y300");
  }
  return upgradedUrl;
}

function isAllowedArtworkHost(url: URL) {
  return ARTWORK_HOSTS.some(
    (host) => url.hostname === host || url.hostname.endsWith(`.${host}`)
  );
}

function isNetEaseArtworkHost(url: URL) {
  return (
    url.hostname === "music.126.net" ||
    url.hostname.endsWith(".music.126.net")
  );
}
