import { buildSyncedLyrics } from "@/features/recognition/syncedLyrics";
import type {
  LyricSnippet,
  RecognizedSongVersion,
  SongCandidate,
  SyncedLyrics,
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
    code?: number;
    data?: {
      body?: {
        song?: {
          list?: QQSearchSong[];
        };
      };
    };
  };
  data?: {
    song?: {
      list?: QQSearchSong[];
    };
  };
};

type NetEaseLyricPayload = {
  lrc?: {
    lyric?: unknown;
  };
};

type QQSongMatch = {
  songMid: string;
  artistMatched: boolean;
  candidate: SongCandidate;
  keepNetEaseSongId?: boolean;
};

const MIN_UNMATCHED_LYRICS_CONFIDENCE = 0.7;

export async function fetchSyncedLyricsForCandidates(
  candidates: SongCandidate[],
  snippets: Pick<LyricSnippet, "text" | "start" | "confidenceScore">[],
  {
    fetchImpl = fetch,
    maxCandidates = 3,
  }: {
    fetchImpl?: FetchLike;
    maxCandidates?: number;
  } = {}
): Promise<SyncedLyrics | null> {
  const versions = await fetchSyncedLyricsVersionsForCandidates(candidates, snippets, {
    fetchImpl,
    maxCandidates,
  });
  return versions[0]?.lyrics ?? null;
}

export async function fetchSyncedLyricsVersionsForCandidates(
  candidates: SongCandidate[],
  snippets: Pick<LyricSnippet, "text" | "start" | "confidenceScore">[],
  {
    fetchImpl = fetch,
    maxCandidates = 4,
  }: {
    fetchImpl?: FetchLike;
    maxCandidates?: number;
  } = {}
): Promise<RecognizedSongVersion[]> {
  const versions: RecognizedSongVersion[] = [];

  for (const candidate of candidates.slice(0, maxCandidates)) {
    const lyrics = await fetchSyncedLyricsForCandidate(
      candidate,
      snippets,
      fetchImpl
    );
    if (lyrics) {
      const versionCandidate = lyrics.matchedCandidate ?? candidate;
      versions.push({
        id: `${versionCandidate.source}:${versionCandidate.id}`,
        candidate: versionCandidate,
        lyrics,
      });
    }
  }

  return versions.sort(compareRecognizedSongVersions);
}

function compareRecognizedSongVersions(
  lhs: RecognizedSongVersion,
  rhs: RecognizedSongVersion
) {
  return (
    readLyricAlignmentScore(rhs) - readLyricAlignmentScore(lhs) ||
    Number(hasEstimatedOffset(rhs)) - Number(hasEstimatedOffset(lhs))
  );
}

function readLyricAlignmentScore(version: RecognizedSongVersion) {
  return version.lyrics.confidenceScore ?? 0;
}

function hasEstimatedOffset(version: RecognizedSongVersion) {
  return typeof version.lyrics.estimatedOffsetSeconds === "number";
}

async function fetchSyncedLyricsForCandidate(
  candidate: SongCandidate,
  snippets: Pick<LyricSnippet, "text" | "start" | "confidenceScore">[],
  fetchImpl: FetchLike
): Promise<SyncedLyrics | null> {
  const qqLyrics = await fetchQQLyricsForCandidate(candidate, snippets, fetchImpl);
  if (qqLyrics) {
    const { songMid, keepNetEaseSongId, ...lyrics } = qqLyrics;
    return {
      ...lyrics,
      platformSongIds: {
        qq: songMid,
        ...(keepNetEaseSongId ? { netease: candidate.id } : {}),
      },
    };
  }

  if (candidate.source !== "netease") return null;

  const netEaseLyrics = await fetchNetEaseLyricsForCandidate(
    candidate,
    snippets,
    fetchImpl
  );
  if (!netEaseLyrics) return null;

  return {
    ...netEaseLyrics,
    matchedCandidate: candidate,
    platformSongIds: { netease: candidate.id },
  };
}

async function fetchQQLyricsForCandidate(
  candidate: SongCandidate,
  snippets: Pick<LyricSnippet, "text" | "start" | "confidenceScore">[],
  fetchImpl: FetchLike
) {
  const songMatch: QQSongMatch | null =
    candidate.source === "qq"
      ? await buildDirectQQSongMatch(candidate, fetchImpl)
      : await findQQSongMatch(candidate, fetchImpl);
  if (!songMatch) return null;

  const url = new URL("https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg");
  url.searchParams.set("songmid", songMatch.songMid);
  url.searchParams.set("format", "json");
  url.searchParams.set("nobase64", "1");

  const response = await fetchImpl(url.toString(), {
    headers: {
      Accept: "application/json, text/plain, */*",
      Referer: "https://y.qq.com/",
      "User-Agent": "Mozilla/5.0",
    },
  }).catch(() => null);
  if (!response?.ok) return null;

  const payload = await response.json().catch(() => null);
  const rawLrc = readString((payload as { lyric?: unknown } | null)?.lyric);
  if (!rawLrc) return null;

  const lyrics = buildSyncedLyrics({
    source: "qq",
    rawLrc,
    snippets,
    allowUnmatchedLyrics:
      songMatch.artistMatched && shouldAllowUnmatchedLyrics(candidate),
  });
  return lyrics
    ? {
        ...lyrics,
        songMid: songMatch.songMid,
        matchedCandidate: songMatch.artistMatched
          ? mergeSongCandidateMetadata(candidate, songMatch.candidate)
          : songMatch.candidate,
        keepNetEaseSongId:
          songMatch.keepNetEaseSongId ?? songMatch.artistMatched,
      }
    : null;
}

async function buildDirectQQSongMatch(
  candidate: SongCandidate,
  fetchImpl: FetchLike
): Promise<QQSongMatch> {
  let enrichedCandidate = candidate;

  if (needsQQMetadataEnrichment(candidate)) {
    const fallbackSongs = await searchQQClassicSongs(candidate, fetchImpl);
    const fallbackMatch = findQQSongInResults(fallbackSongs, candidate);

    if (fallbackMatch?.songMid === candidate.id) {
      enrichedCandidate = mergeSongCandidateMetadata(
        candidate,
        fallbackMatch.candidate
      );
    }
  }

  return {
    songMid: candidate.id,
    artistMatched: true,
    candidate: enrichedCandidate,
    keepNetEaseSongId: false,
  };
}

async function findQQSongMatch(
  candidate: SongCandidate,
  fetchImpl: FetchLike
): Promise<QQSongMatch | null> {
  const songs = await searchQQDesktopSongs(candidate, fetchImpl);
  const primaryMatch = findQQSongInResults(songs, candidate);
  if (primaryMatch && !needsQQMetadataEnrichment(primaryMatch.candidate)) {
    return primaryMatch;
  }

  const fallbackSongs = await searchQQClassicSongs(candidate, fetchImpl);
  const fallbackMatch = findQQSongInResults(fallbackSongs, candidate);

  if (!primaryMatch) return fallbackMatch;
  if (fallbackMatch?.songMid !== primaryMatch.songMid) return primaryMatch;

  return {
    ...primaryMatch,
    candidate: mergeSongCandidateMetadata(
      primaryMatch.candidate,
      fallbackMatch.candidate
    ),
  };
}

async function searchQQDesktopSongs(
  candidate: SongCandidate,
  fetchImpl: FetchLike
): Promise<QQSearchSong[]> {
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
          query: `${candidate.title} ${candidate.artist}`.trim(),
          search_type: 0,
          page_num: 1,
          num_per_page: 5,
          grp: 1,
        },
      },
    }),
  }).catch(() => null);
  if (!response?.ok) return [];

  const payload = (await response.json().catch(() => null)) as QQSearchPayload | null;
  return payload?.req_1?.data?.body?.song?.list ?? [];
}

async function searchQQClassicSongs(
  candidate: SongCandidate,
  fetchImpl: FetchLike
): Promise<QQSearchSong[]> {
  const url = new URL("https://c.y.qq.com/soso/fcgi-bin/search_for_qq_cp");
  url.searchParams.set("format", "json");
  url.searchParams.set("p", "1");
  url.searchParams.set("n", "10");
  url.searchParams.set("w", `${candidate.title} ${candidate.artist}`.trim());

  const response = await fetchImpl(url.toString(), {
    headers: {
      Accept: "application/json, text/plain, */*",
      Referer: "https://y.qq.com/",
      "User-Agent": "Mozilla/5.0",
    },
  }).catch(() => null);
  if (!response?.ok) return [];

  const payload = (await response.json().catch(() => null)) as QQSearchPayload | null;
  return payload?.data?.song?.list ?? [];
}

function findQQSongInResults(
  songs: QQSearchSong[],
  candidate: SongCandidate
): QQSongMatch | null {
  const artistMatchedSong = songs.find((song) =>
    isQQSongMatch(song, candidate, true)
  );
  const matchedSong = artistMatchedSong ?? findSafeTitleOnlyQQSong(songs, candidate);
  const songMid = readString(matchedSong?.mid ?? matchedSong?.songmid);
  if (!matchedSong || !songMid) return null;

  return {
    songMid,
    artistMatched: Boolean(artistMatchedSong),
    candidate: makeQQSongCandidate(matchedSong, songMid, candidate),
  };
}

async function fetchNetEaseLyricsForCandidate(
  candidate: SongCandidate,
  snippets: Pick<LyricSnippet, "text" | "start" | "confidenceScore">[],
  fetchImpl: FetchLike
) {
  const url = new URL("https://music.163.com/api/song/lyric");
  url.searchParams.set("id", candidate.id);
  url.searchParams.set("lv", "1");
  url.searchParams.set("kv", "1");
  url.searchParams.set("tv", "-1");

  const response = await fetchImpl(url.toString(), {
    headers: {
      Accept: "application/json, text/plain, */*",
      Referer: "https://music.163.com/",
      "User-Agent": "Mozilla/5.0",
    },
  }).catch(() => null);
  if (!response?.ok) return null;

  const payload = (await response.json().catch(() => null)) as
    | NetEaseLyricPayload
    | null;
  const rawLrc = readString(payload?.lrc?.lyric);
  if (!rawLrc) return null;

  return buildSyncedLyrics({
    source: "netease",
    rawLrc,
    snippets,
    allowUnmatchedLyrics: shouldAllowUnmatchedLyrics(candidate),
  });
}

function shouldAllowUnmatchedLyrics(candidate: SongCandidate) {
  return (candidate.confidenceScore ?? 0) >= MIN_UNMATCHED_LYRICS_CONFIDENCE;
}

function isQQSongMatch(
  song: QQSearchSong,
  candidate: Pick<SongCandidate, "title" | "artist">,
  requireArtist: boolean
) {
  const title = normalizeSongText(readString(song.title ?? song.songname), true);
  const candidateTitle = normalizeSongText(candidate.title, true);
  if (!title || title !== candidateTitle) return false;

  if (!requireArtist) return true;

  const artist = normalizeSongText(
    (song.singer ?? [])
      .map((singer) => readString(singer.name ?? singer.title))
      .filter(Boolean)
      .join(" "),
    false
  );
  const candidateArtist = normalizeSongText(candidate.artist, false);
  return Boolean(
    artist &&
      candidateArtist &&
      (artist.includes(candidateArtist) || candidateArtist.includes(artist))
  );
}

function findSafeTitleOnlyQQSong(
  songs: QQSearchSong[],
  candidate: Pick<SongCandidate, "title" | "artist">
) {
  const candidateTitle = normalizeSongText(candidate.title, false);
  if (!candidateTitle) return undefined;

  return songs.find((song) => {
    const title = normalizeSongText(readString(song.title ?? song.songname), false);
    return title === candidateTitle;
  });
}

function makeQQSongCandidate(
  song: QQSearchSong,
  songMid: string,
  fallbackCandidate: SongCandidate
): SongCandidate {
  const artist = readQQArtist(song) || fallbackCandidate.artist;
  const album = readQQAlbum(song) || fallbackCandidate.album;
  const artworkUrl = readQQArtworkUrl(song) || fallbackCandidate.artworkUrl;
  const releaseDate = readQQReleaseDate(song) || fallbackCandidate.releaseDate;

  return {
    ...fallbackCandidate,
    id: songMid,
    title: readString(song.title ?? song.songname) || fallbackCandidate.title,
    artist,
    ...(album ? { album } : {}),
    ...(artworkUrl ? { artworkUrl } : {}),
    ...(releaseDate ? { releaseDate } : {}),
    source: "qq",
    url: `https://y.qq.com/n/ryqq/songDetail/${encodeURIComponent(songMid)}`,
  };
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
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    const timestamp = value < 10_000_000_000 ? value * 1000 : value;
    const date = new Date(timestamp);
    return Number.isNaN(date.getTime()) ? undefined : formatChinaDate(date);
  }

  const text = readString(value);
  if (!text) return undefined;

  if (/^\d{4}-\d{2}-\d{2}$/.test(text)) return text;
  if (/^\d{4}\/\d{2}\/\d{2}$/.test(text)) return text.replaceAll("/", "-");

  const parsed = new Date(text);
  return Number.isNaN(parsed.getTime()) ? undefined : parsed.toISOString().slice(0, 10);
}

function needsQQMetadataEnrichment(candidate: SongCandidate) {
  return !candidate.releaseDate && Boolean(candidate.artworkUrl);
}

function mergeSongCandidateMetadata(
  candidate: SongCandidate,
  metadataCandidate: SongCandidate
): SongCandidate {
  return {
    ...candidate,
    album: candidate.album ?? metadataCandidate.album,
    artworkUrl: candidate.artworkUrl ?? metadataCandidate.artworkUrl,
    releaseDate: candidate.releaseDate ?? metadataCandidate.releaseDate,
  };
}

function formatChinaDate(date: Date) {
  const chinaOffsetMilliseconds = 8 * 60 * 60 * 1000;
  return new Date(date.getTime() + chinaOffsetMilliseconds)
    .toISOString()
    .slice(0, 10);
}

function normalizeSongText(text: string, removeParentheses: boolean) {
  const withoutParentheses = removeParentheses
    ? text.replace(/[（(].*?[）)]/g, "")
    : text;

  return normalizeChineseVariants(withoutParentheses.toLowerCase()).replace(
    /[\p{P}\p{S}\s]/gu,
    ""
  );
}

function readString(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
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
