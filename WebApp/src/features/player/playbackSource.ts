import type { Station } from "@/features/stations/stationTypes";

export function resolvePlaybackSource(
  station: Pick<Station, "codec" | "hls" | "url" | "urlResolved">
) {
  const source = station.urlResolved || station.url;
  if (!source) return source;

  try {
    const url = new URL(source);
    const shouldTranscode = needsBrowserTranscode(station, url);
    if (!shouldTranscode) {
      const secureUrl = upgradeVerifiedHttpStream(url);
      if (secureUrl) return secureUrl;
    }

    if (url.protocol === "http:" || shouldTranscode) {
      const params = new URLSearchParams({ url: url.toString() });
      if (shouldTranscode) {
        params.set("transcode", "mp3");
      }
      return `/api/stream?${params.toString()}`;
    }
  } catch {
    return source;
  }

  return source;
}

function upgradeVerifiedHttpStream(url: URL) {
  if (url.protocol !== "http:") return null;
  if (url.hostname.toLowerCase() !== "lhttp.qingting.fm") return null;

  const secureUrl = new URL(url.toString());
  secureUrl.protocol = "https:";
  return secureUrl.toString();
}

function needsBrowserTranscode(
  station: Pick<Station, "codec" | "hls">,
  url: URL
) {
  const codec = station.codec.trim().toUpperCase();
  const pathname = url.pathname.toLowerCase();

  return (
    station.hls === 1 ||
    pathname.endsWith(".m3u8") ||
    codec === "AAC+" ||
    codec === "AACPLUS" ||
    codec === "HE-AAC"
  );
}
