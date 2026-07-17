import type {
  LyricSnippet,
  SongCandidate,
  StreamTrackMetadata,
} from "@/features/recognition/recognitionTypes";

type FetchLike = typeof fetch;

type NetEaseSearchPayload = {
  result?: {
    songs?: NetEaseRawSong[];
  };
};

type NetEaseRawSong = {
  id?: number | string;
  name?: string;
  artists?: Array<{ name?: string }>;
  ar?: Array<{ name?: string }>;
  album?: { name?: string; picUrl?: string; publishTime?: number | string };
  al?: { name?: string; picUrl?: string; publishTime?: number | string };
  publishTime?: number | string;
  lyrics?: unknown;
  pop?: unknown;
};

export function makeNetEaseSongSearchRequest(
  keyword: string,
  limit: number,
  offset = 0
) {
  const url = new URL("https://music.163.com/api/cloudsearch/pc");
  url.searchParams.set("s", keyword);
  url.searchParams.set("type", "1006");
  url.searchParams.set("offset", String(offset));
  url.searchParams.set("limit", String(limit));

  return new Request(url, {
    method: "GET",
    headers: {
      Accept: "application/json, text/plain, */*",
      Referer: "https://music.163.com/",
      "User-Agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
    },
  });
}

export function parseNetEaseSongSearchResponse(
  payload: NetEaseSearchPayload
): SongCandidate[] {
  return (payload.result?.songs ?? []).flatMap((song) => {
    const parsed = parseNetEaseSong(song);
    return parsed ? [parsed] : [];
  });
}

export async function searchNetEaseSongCandidates(
  snippets: Pick<LyricSnippet, "text" | "confidenceScore">[],
  {
    fetchImpl = fetch,
    limitPerSnippet = 6,
    trackMetadata = null,
  }: {
    fetchImpl?: FetchLike;
    limitPerSnippet?: number;
    trackMetadata?: StreamTrackMetadata | null;
  } = {}
) {
  const candidates: SongCandidate[] = [];
  const seen = new Map<string, SongCandidate>();

  for (const snippet of snippets.slice(0, 3)) {
    const query = compactLyricQuery(snippet.text);
    if (normalizedLyricSearchText(query).length < 6) continue;

    const response = await fetchImpl(
      makeNetEaseSongSearchRequest(query, limitPerSnippet)
    ).catch(() => null);
    if (!response || !response.ok) continue;

    const payload = await response.json().catch(() => null);
    const songs = readNetEaseRawSongs(payload);
    for (const song of songs) {
      const parsedSong = parseNetEaseSong(song);
      if (!parsedSong || isDerivative(parsedSong.title)) continue;

      const lyricScore = scoreLyricEvidence(snippet.text, readLyricLines(song));
      if (lyricScore < 0.55) continue;

      const key = buildSongIdentityKey(parsedSong);
      const metadataScore = scoreCandidateAgainstMetadata(parsedSong, trackMetadata);
      const candidate = {
        ...parsedSong,
        matchedSnippet: snippet.text,
        confidenceScore: roundScore(snippet.confidenceScore * lyricScore),
        ...(metadataScore > 0 ? { metadataScore } : {}),
        popularityScore: readPopularityScore(song),
      };
      const existing = seen.get(key);

      if (!existing || compareCandidates(candidate, existing) < 0) {
        seen.set(key, candidate);
      }
    }
  }

  for (const candidate of seen.values()) {
    candidates.push(candidate);
  }

  return candidates.sort(
    (lhs, rhs) => compareCandidates(lhs, rhs)
  );
}

function compareCandidates(lhs: SongCandidate, rhs: SongCandidate) {
  return (
    (rhs.metadataScore ?? 0) - (lhs.metadataScore ?? 0) ||
    (rhs.confidenceScore ?? 0) - (lhs.confidenceScore ?? 0) ||
    (rhs.popularityScore ?? 0) - (lhs.popularityScore ?? 0)
  );
}

function scoreCandidateAgainstMetadata(
  candidate: Pick<SongCandidate, "title" | "artist">,
  metadata: StreamTrackMetadata | null
) {
  if (!metadata) return 0;

  const metadataTitle = normalizedLyricSearchText(metadata.title ?? metadata.rawTitle);
  const metadataArtist = normalizedLyricSearchText(metadata.artist ?? "");
  const candidateTitle = normalizedLyricSearchText(candidate.title);
  const candidateArtist = normalizedLyricSearchText(candidate.artist);

  const titleScore = scoreTextMatch(candidateTitle, metadataTitle) * 0.6;
  const artistScore = scoreTextMatch(candidateArtist, metadataArtist) * 0.4;

  return roundScore(Math.min(titleScore + artistScore, 1));
}

function scoreTextMatch(candidateText: string, metadataText: string) {
  if (!candidateText || !metadataText) return 0;
  if (candidateText === metadataText) return 1;
  if (candidateText.includes(metadataText) || metadataText.includes(candidateText)) {
    return Math.min(candidateText.length, metadataText.length) /
      Math.max(candidateText.length, metadataText.length);
  }
  return 0;
}

function buildSongIdentityKey(song: SongCandidate) {
  const title = normalizedLyricSearchText(song.title);
  const artist = normalizedLyricSearchText(song.artist);
  return title && artist
    ? `${song.source}:song:${title}:${artist}`
    : `${song.source}:id:${song.id}`;
}

function readNetEaseRawSongs(payload: unknown) {
  if (typeof payload !== "object" || payload === null || Array.isArray(payload)) {
    return [];
  }

  const result = (payload as NetEaseSearchPayload).result;
  return Array.isArray(result?.songs) ? result.songs : [];
}

function parseNetEaseSong(song: NetEaseRawSong): SongCandidate | null {
  const title = song.name?.trim() ?? "";
  const rawId = song.id;
  const id =
    typeof rawId === "number"
      ? String(rawId)
      : typeof rawId === "string"
        ? rawId.trim()
        : "";

  if (!title || !id) return null;

  const artists = song.artists ?? song.ar ?? [];
  const artist = artists
    .map((artist) => artist.name?.trim())
    .filter((name): name is string => Boolean(name))
    .join(" ");
  const rawAlbum = song.album ?? song.al;
  const album = rawAlbum?.name?.trim() || undefined;
  const artworkUrl = normalizeArtworkUrl(rawAlbum?.picUrl?.trim());
  const releaseDate = readReleaseDate(rawAlbum?.publishTime ?? song.publishTime);

  return {
    id,
    title,
    artist,
    ...(album ? { album } : {}),
    ...(artworkUrl ? { artworkUrl } : {}),
    ...(releaseDate ? { releaseDate } : {}),
    source: "netease" as const,
    url: `https://music.163.com/song?id=${encodeURIComponent(id)}`,
  };
}

function readReleaseDate(value: unknown) {
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    const timestamp = value < 10_000_000_000 ? value * 1000 : value;
    const date = new Date(timestamp);
    return Number.isNaN(date.getTime()) ? undefined : formatChinaDate(date);
  }

  if (typeof value !== "string") return undefined;

  const trimmed = value.trim();
  if (!trimmed) return undefined;

  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return trimmed;
  if (/^\d{4}\/\d{2}\/\d{2}$/.test(trimmed)) {
    return trimmed.replaceAll("/", "-");
  }

  const parsed = new Date(trimmed);
  return Number.isNaN(parsed.getTime()) ? undefined : parsed.toISOString().slice(0, 10);
}

function normalizeArtworkUrl(value: string | undefined) {
  if (!value) return undefined;

  try {
    const url = new URL(value);
    if (isNetEaseArtworkHost(url)) {
      if (url.protocol !== "http:" && url.protocol !== "https:") {
        return value;
      }
      url.protocol = "https:";
      url.searchParams.set("param", "300y300");
      return url.toString();
    }
  } catch {
    return value;
  }

  return value;
}

function isNetEaseArtworkHost(url: URL) {
  return (
    url.hostname === "music.126.net" ||
    url.hostname.endsWith(".music.126.net")
  );
}

function formatChinaDate(date: Date) {
  const chinaOffsetMilliseconds = 8 * 60 * 60 * 1000;
  return new Date(date.getTime() + chinaOffsetMilliseconds)
    .toISOString()
    .slice(0, 10);
}

function compactLyricQuery(text: string) {
  return text
    .replace(/[“”"「」『』]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 60);
}

function normalizedLyricSearchText(text: string) {
  return normalizeChineseVariants(text.toLowerCase())
    .replace(/<[^>]*>/g, "")
    .replace(/[\p{P}\p{S}\s]/gu, "");
}

function readLyricLines(song: NetEaseRawSong) {
  if (!Array.isArray(song.lyrics)) return [];

  return song.lyrics
    .filter((line): line is string => typeof line === "string")
    .map((line) => line.replace(/<[^>]*>/g, ""))
    .filter(Boolean);
}

function scoreLyricEvidence(snippetText: string, lyricLines: string[]) {
  const snippet = normalizedLyricSearchText(snippetText);
  if (snippet.length < 6) return 0;

  return buildLyricEvidenceWindows(lyricLines).reduce((bestScore, line) => {
    const normalizedLine = normalizedLyricSearchText(line);
    if (normalizedLine.length < 4) return bestScore;

    if (normalizedLine.includes(snippet)) {
      return Math.max(bestScore, 1);
    }

    if (snippet.includes(normalizedLine)) {
      return Math.max(bestScore, normalizedLine.length / snippet.length);
    }

    return Math.max(bestScore, bigramDiceScore(snippet, normalizedLine));
  }, 0);
}

function buildLyricEvidenceWindows(lyricLines: string[]) {
  const windows: string[] = [];

  lyricLines.forEach((line, index) => {
    windows.push(line);

    const nextLine = lyricLines[index + 1];
    if (nextLine) {
      windows.push(`${line}${nextLine}`);
    }

    const thirdLine = lyricLines[index + 2];
    if (nextLine && thirdLine) {
      windows.push(`${line}${nextLine}${thirdLine}`);
    }
  });

  return windows;
}

function bigramDiceScore(lhs: string, rhs: string) {
  const lhsBigrams = makeBigrams(lhs);
  const rhsBigrams = makeBigrams(rhs);
  if (lhsBigrams.length === 0 || rhsBigrams.length === 0) return 0;

  const rhsCounts = new Map<string, number>();
  for (const bigram of rhsBigrams) {
    rhsCounts.set(bigram, (rhsCounts.get(bigram) ?? 0) + 1);
  }

  let overlap = 0;
  for (const bigram of lhsBigrams) {
    const count = rhsCounts.get(bigram) ?? 0;
    if (count > 0) {
      overlap += 1;
      rhsCounts.set(bigram, count - 1);
    }
  }

  const dice = (2 * overlap) / (lhsBigrams.length + rhsBigrams.length);
  const overlapRatio = overlap / Math.min(lhsBigrams.length, rhsBigrams.length);
  return Math.max(dice, overlapRatio * 0.85);
}

function makeBigrams(text: string) {
  if (text.length < 2) return [];

  return Array.from({ length: text.length - 1 }, (_, index) =>
    text.slice(index, index + 2)
  );
}

function roundScore(score: number) {
  return Math.round(score * 1000) / 1000;
}

function readPopularityScore(song: NetEaseRawSong) {
  return typeof song.pop === "number" && Number.isFinite(song.pop)
    ? Math.min(Math.max(song.pop / 100, 0), 1)
    : 0;
}

function isDerivative(title: string) {
  const keywords = ["伴奏", "instrumental", "inst.", "off vocal", "dj", "remix", "club mix"];
  const lowerTitle = title.toLowerCase();
  return keywords.some((keyword) => lowerTitle.includes(keyword));
}

function normalizeChineseVariants(text: string) {
  const variantMap: Record<string, string> = {
    愛: "爱", 與: "与", 無: "无", 連: "连", 還: "还", 挂: "挂", 掛: "挂",
    誰: "谁", 会: "会", 會: "会", 傷: "伤", 聽: "听", 説: "说", 說: "说",
    懷: "怀", 絕: "绝", 熱: "热", 動: "动", 諒: "谅", 緊: "紧", 過: "过",
    遠: "远", 變: "变", 給: "给", 見: "见", 點: "点", 風: "风", 雲: "云",
    開: "开", 夢: "梦", 头: "头", 頭: "头", 體: "体", 樂: "乐", 間: "间", 峯: "峰", 峰: "峰"
  };

  return text.replace(
    /[愛與無連還掛誰會傷聽說懷絕熱動諒緊過遠變給見點風雲開梦梦頭體樂間峯]/g,
    (character) => variantMap[character] ?? character
  );
}
