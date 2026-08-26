import type {
  LyricSnippet,
  SongCandidate,
  StreamTrackMetadata,
} from "@/features/recognition/recognitionTypes";

type FetchLike = typeof fetch;

type QQSearchSong = {
  mid?: unknown;
  songmid?: unknown;
  title?: unknown;
  songname?: unknown;
  singer?: Array<{ name?: unknown; title?: unknown }>;
  album?: {
    name?: unknown;
    title?: unknown;
    mid?: unknown;
    pmid?: unknown;
    time_public?: unknown;
    publishTime?: unknown;
  };
  albumname?: unknown;
  albumName?: unknown;
  albumtitle?: unknown;
  albummid?: unknown;
  albumMid?: unknown;
  time_public?: unknown;
  pubtime?: unknown;
  releaseDate?: unknown;
};

type QQSearchPayload = {
  req_1?: {
    data?: {
      body?: {
        song?: {
          list?: QQSearchSong[];
        };
      };
    };
  };
};

export async function searchQQSongCandidates(
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
  const seen = new Map<string, SongCandidate>();

  for (const snippet of snippets.slice(0, 3)) {
    const query = compactLyricQuery(snippet.text);
    if (normalizeSongText(query).length < 6) continue;

    const response = await fetchImpl("https://u.y.qq.com/cgi-bin/musicu.fcg", {
      method: "POST",
      headers: {
        Accept: "application/json, text/plain, */*",
        "Content-Type": "application/json;charset=UTF-8",
        Referer: "https://y.qq.com/",
        "User-Agent":
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
      },
      body: JSON.stringify({
        comm: {
          ct: 19,
          cv: 1859,
          uin: "0",
          format: "json",
        },
        req_1: {
          module: "music.search.SearchCgiService",
          method: "DoSearchForQQMusicDesktop",
          param: {
            query,
            search_type: 0,
            page_num: 1,
            num_per_page: limitPerSnippet,
            grp: 1,
          },
        },
      }),
    }).catch(() => null);
    if (!response?.ok) continue;

    const payload = (await response.json().catch(() => null)) as
      | QQSearchPayload
      | null;
    const songs = payload?.req_1?.data?.body?.song?.list ?? [];
    songs.slice(0, limitPerSnippet).forEach((song, rankIndex) => {
      const candidate = parseQQSong(song);
      if (!candidate) return;

      const scoredCandidate = {
        ...candidate,
        matchedSnippet: snippet.text,
        confidenceScore: roundScore(snippet.confidenceScore),
        popularityScore: roundScore((limitPerSnippet - rankIndex) / limitPerSnippet),
        ...readMetadataScore(candidate, trackMetadata),
      };
      const existing = seen.get(scoredCandidate.id);

      if (!existing || compareCandidates(scoredCandidate, existing) < 0) {
        seen.set(scoredCandidate.id, scoredCandidate);
      }
    });
  }

  return Array.from(seen.values()).sort(compareCandidates);
}

function parseQQSong(song: QQSearchSong): SongCandidate | null {
  const id = readString(song.mid ?? song.songmid);
  const title = readString(song.title ?? song.songname);
  if (!id || !title) return null;

  const artist = readQQArtist(song);
  const album = readQQAlbum(song);
  const artworkUrl = readQQArtworkUrl(song);
  const releaseDate = readQQReleaseDate(song);

  return {
    id,
    title,
    artist,
    ...(album ? { album } : {}),
    ...(artworkUrl ? { artworkUrl } : {}),
    ...(releaseDate ? { releaseDate } : {}),
    source: "qq",
    url: `https://y.qq.com/n/ryqq/songDetail/${encodeURIComponent(id)}`,
  };
}

function compareCandidates(lhs: SongCandidate, rhs: SongCandidate) {
  return (
    (rhs.metadataScore ?? 0) - (lhs.metadataScore ?? 0) ||
    (rhs.confidenceScore ?? 0) - (lhs.confidenceScore ?? 0) ||
    (rhs.popularityScore ?? 0) - (lhs.popularityScore ?? 0)
  );
}

function readMetadataScore(
  candidate: Pick<SongCandidate, "title" | "artist">,
  metadata: StreamTrackMetadata | null
) {
  if (!metadata) return {};

  const metadataTitle = normalizeSongText(metadata.title ?? metadata.rawTitle);
  const metadataArtist = normalizeSongText(metadata.artist ?? "");
  const candidateTitle = normalizeSongText(candidate.title);
  const candidateArtist = normalizeSongText(candidate.artist);
  const titleScore = scoreTextMatch(candidateTitle, metadataTitle) * 0.6;
  const artistScore = scoreTextMatch(candidateArtist, metadataArtist) * 0.4;
  const metadataScore = roundScore(Math.min(titleScore + artistScore, 1));

  return metadataScore > 0 ? { metadataScore } : {};
}

function scoreTextMatch(candidateText: string, metadataText: string) {
  if (!candidateText || !metadataText) return 0;
  if (candidateText === metadataText) return 1;
  if (candidateText.includes(metadataText) || metadataText.includes(candidateText)) {
    return (
      Math.min(candidateText.length, metadataText.length) /
      Math.max(candidateText.length, metadataText.length)
    );
  }
  return 0;
}

function readQQArtist(song: QQSearchSong) {
  return (song.singer ?? [])
    .map((singer) => readString(singer.name ?? singer.title))
    .filter(Boolean)
    .join(" / ");
}

function readQQAlbum(song: QQSearchSong) {
  return readString(
    song.album?.name ??
      song.album?.title ??
      song.albumname ??
      song.albumName ??
      song.albumtitle
  );
}

function readQQArtworkUrl(song: QQSearchSong) {
  const albumMid = readString(
    song.album?.mid ?? song.album?.pmid ?? song.albummid ?? song.albumMid
  );

  if (!albumMid) return "";

  return `https://y.gtimg.cn/music/photo_new/T002R300x300M000${encodeURIComponent(
    albumMid
  )}.jpg?max_age=2592000`;
}

function readQQReleaseDate(song: QQSearchSong) {
  return normalizeReleaseDate(
    song.album?.time_public ??
      song.album?.publishTime ??
      song.time_public ??
      song.pubtime ??
      song.releaseDate
  );
}

function normalizeReleaseDate(value: unknown) {
  const text = readString(value);
  if (!text) return undefined;

  if (/^\d{4}-\d{2}-\d{2}$/.test(text)) return text;
  if (/^\d{4}\/\d{2}\/\d{2}$/.test(text)) return text.replaceAll("/", "-");

  const parsed = new Date(text);
  return Number.isNaN(parsed.getTime()) ? undefined : parsed.toISOString().slice(0, 10);
}

function compactLyricQuery(text: string) {
  return text
    .replace(/[“”"「」『』]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 60);
}

function normalizeSongText(text: string) {
  return normalizeChineseVariants(text.toLowerCase()).replace(/[\p{P}\p{S}\s]/gu, "");
}

function readString(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function roundScore(score: number) {
  return Math.round(score * 1000) / 1000;
}

function normalizeChineseVariants(text: string) {
  const variantMap: Record<string, string> = {
    愛: "爱",
    與: "与",
    無: "无",
    連: "连",
    還: "还",
    掛: "挂",
    誰: "谁",
    會: "会",
    傷: "伤",
    聽: "听",
    說: "说",
    懷: "怀",
    峯: "峰",
  };

  return text.replace(/[愛與無連還掛誰會傷聽說懷峯]/g, (character) =>
    variantMap[character] ?? character
  );
}
