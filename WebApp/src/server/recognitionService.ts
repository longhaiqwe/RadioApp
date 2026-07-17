import type {
  LyricSnippet,
  RecognitionRequest,
  RecognitionResult,
  SongCandidate,
} from "@/features/recognition/recognitionTypes";
import { captureStreamAudio } from "./audioCapture";
import {
  extractLikelyLyricSnippets,
  transcribeLyricsWithOpenRouter,
} from "./openRouterLyrics";
import { fetchSyncedLyricsVersionsForCandidates } from "./musicLyrics";
import { searchNetEaseSongCandidates } from "./neteaseSongSearch";
import { searchQQSongCandidates } from "./qqSongSearch";
import { fetchStreamTrackMetadata } from "./streamMetadata";

const MAX_RECOGNITION_ATTEMPTS = 2;

export async function recognizeStation(
  request: RecognitionRequest
): Promise<RecognitionResult> {
  const logContext = {
    streamHost: readURLHost(request.streamUrl),
    stationId: request.stationId,
    languageHint: request.languageHint,
  };

  for (let attempt = 1; attempt <= MAX_RECOGNITION_ATTEMPTS; attempt += 1) {
    try {
      return await recognizeStationAttempt(request, logContext, attempt);
    } catch (error) {
      const retryable =
        attempt < MAX_RECOGNITION_ATTEMPTS && isRetryableRecognitionError(error);
      logRecognitionStage(retryable ? "retry" : "failed", {
        ...logContext,
        attempt,
        error: sanitizeErrorMessage(error, request.streamUrl),
      });

      if (!retryable) throw error;
    }
  }

  throw new Error("recognition_failed");
}

async function recognizeStationAttempt(
  request: RecognitionRequest,
  logContext: Record<string, string | undefined>,
  attempt: number
): Promise<RecognitionResult> {
  logRecognitionStage("start", { ...logContext, attempt });

  const captureStart = Date.now();
  const audioData = await captureStreamAudio({ streamUrl: request.streamUrl });
  const captureEnd = Date.now();
  const physicalDuration = (captureEnd - captureStart) / 1000;
  const audioDuration = 15; // ffmpeg capture duration is 15s
  const compensation = physicalDuration > 0.05 ? Math.max(0, audioDuration - physicalDuration) : 0;

  logRecognitionStage("captured", {
    ...logContext,
    attempt,
    audioBytes: audioData.length,
  });

  const transcription = await transcribeLyricsWithOpenRouter({
    audioData,
    languageHint: request.languageHint,
  });
  logRecognitionStage("transcribed", {
    ...logContext,
    attempt,
    transcriptChars: transcription.text.length,
    segmentCount: transcription.segments.length,
  });

  const snippets = extractLikelyLyricSnippets(transcription);
  logRecognitionStage("snippets", {
    ...logContext,
    attempt,
    snippetCount: snippets.length,
  });

  if (snippets.length === 0) {
    throw new Error("no_usable_lyric_snippets");
  }

  const streamMetadata = await fetchStreamTrackMetadata({
    streamUrl: request.streamUrl,
  }).catch(() => null);

  logRecognitionStage("metadata", {
    ...logContext,
    attempt,
    metadataTitle: streamMetadata?.rawTitle,
  });

  const searchResult = await searchSongCandidatesAndLyrics(snippets, streamMetadata);
  const { candidates, versions } = searchResult;
  logRecognitionStage("searched", {
    ...logContext,
    attempt,
    candidateCount: candidates.length,
    candidateSource: searchResult.source,
  });

  const lyrics = versions[0]?.lyrics ?? null;
  if (compensation > 0) {
    if (lyrics && typeof lyrics.estimatedOffsetSeconds === "number") {
      lyrics.estimatedOffsetSeconds = Number((lyrics.estimatedOffsetSeconds + compensation).toFixed(3));
    }
    for (const v of versions) {
      if (v.lyrics && typeof v.lyrics.estimatedOffsetSeconds === "number") {
        v.lyrics.estimatedOffsetSeconds = Number((v.lyrics.estimatedOffsetSeconds + compensation).toFixed(3));
      }
    }
  }

  const rankedCandidates = promoteMatchedCandidate(
    candidates,
    lyrics?.matchedCandidate
  );

  logRecognitionStage("lyrics", {
    ...logContext,
    attempt,
    hasLyrics: lyrics ? 1 : 0,
    lyricLineCount: lyrics?.lines.length ?? 0,
    matchedCandidateId: lyrics?.matchedCandidate?.id,
  });

  return {
    method: "lyrics_asr",
    transcript: transcription.text,
    snippets,
    candidates: rankedCandidates.slice(0, 5),
    streamMetadata,
    versions,
    lyrics,
  };
}

async function searchSongCandidatesAndLyrics(
  snippets: LyricSnippet[],
  streamMetadata: Awaited<ReturnType<typeof fetchStreamTrackMetadata>>
) {
  const qqCandidates = await searchQQSongCandidates(snippets, {
    trackMetadata: streamMetadata,
  });

  // 1. 高置信度提前熔断：获取 QQ 音乐全部候选歌词并检查 Top 1 得分
  if (qqCandidates.length > 0) {
    const qqVersions = await fetchSyncedLyricsVersionsForCandidates(
      qqCandidates,
      snippets,
      { streamMetadata }
    );
    if (qqVersions.length > 0) {
      return { source: "qq", candidates: qqCandidates, versions: qqVersions };
    }
  }

  // 2. 低置信度降级为双通道混合对比与统一打分
  const netEaseCandidates = await searchNetEaseSongCandidates(snippets, {
    trackMetadata: streamMetadata,
  });

  const allCandidatesMap = new Map<string, SongCandidate>();
  for (const c of qqCandidates) {
    const key = `${normalizeChineseVariantsForSync(c.title.toLowerCase())}::${normalizeChineseVariantsForSync(c.artist.toLowerCase())}`;
    if (!allCandidatesMap.has(key)) {
      allCandidatesMap.set(key, c);
    }
  }
  for (const c of netEaseCandidates) {
    const key = `${normalizeChineseVariantsForSync(c.title.toLowerCase())}::${normalizeChineseVariantsForSync(c.artist.toLowerCase())}`;
    if (!allCandidatesMap.has(key)) {
      allCandidatesMap.set(key, c);
    }
  }

  const combinedCandidates = Array.from(allCandidatesMap.values());
  const combinedVersions = await fetchSyncedLyricsVersionsForCandidates(
    combinedCandidates,
    snippets,
    { streamMetadata }
  );

  const source = combinedVersions[0]?.candidate.source ?? "qq";
  return {
    source,
    candidates: combinedCandidates,
    versions: combinedVersions,
  };
}

function promoteMatchedCandidate(
  candidates: SongCandidate[],
  matchedCandidate?: SongCandidate
) {
  if (!matchedCandidate) return candidates;

  const matchedIndex = candidates.findIndex(
    (candidate) =>
      candidate.source === matchedCandidate.source && candidate.id === matchedCandidate.id
  );
  if (matchedIndex <= 0) return candidates;

  const nextCandidates = [...candidates];
  const [matched] = nextCandidates.splice(matchedIndex, 1);
  return [matched, ...nextCandidates];
}

function logRecognitionStage(
  stage: string,
  details: Record<string, string | number | undefined>
) {
  console.info("[recognition]", JSON.stringify({ stage, ...details }));
}

function readURLHost(rawURL: string) {
  try {
    return new URL(rawURL).host;
  } catch {
    return "invalid_url";
  }
}

function sanitizeErrorMessage(error: unknown, streamUrl: string) {
  const rawMessage =
    error instanceof Error ? error.message : String(error || "unknown_error");
  return rawMessage.replaceAll(streamUrl, "[stream_url]").slice(0, 300);
}

function isRetryableRecognitionError(error: unknown) {
  const message =
    error instanceof Error ? error.message : String(error || "unknown_error");

  return [
    "audio_capture_timeout",
    "audio_capture_empty",
    "empty_lyrics_transcript",
    "no_usable_lyric_snippets",
    "ffmpeg_exit_255",
    "Connection timed out",
    "Error opening input",
  ].some((retryableMessage) => message.includes(retryableMessage));
}

function normalizeChineseVariantsForSync(text: string) {
  const variantMap: Record<string, string> = {
    愛: "爱", 與: "与", 無: "无", 連: "连", 還: "还", 挂: "挂", 掛: "挂",
    誰: "谁", 会: "会", 會: "会", 傷: "伤", 聽: "听", 説: "说", 說: "说",
    懷: "怀", 絕: "绝", 熱: "热", 動: "动", 諒: "凉", 緊: "紧", 過: "过",
    遠: "远", 變: "变", 給: "给", 見: "见", 點: "点", 風: "风", 雲: "云",
    開: "开", 夢: "梦", 头: "头", 頭: "头", 體: "体", 乐: "乐", 樂: "乐", 间: "间", 間: "间", 峯: "峰", 峰: "峰"
  };
  return text.replace(/[愛與無連還掛誰會傷聽說懷絕熱動諒紧紧過遠變給見點風雲開梦梦頭體樂間峯]/g, (char) => variantMap[char] ?? char);
}
