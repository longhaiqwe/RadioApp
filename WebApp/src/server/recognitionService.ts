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

  const streamMetadataPromise = fetchStreamTrackMetadata({
    streamUrl: request.streamUrl,
  }).catch(() => null);
  const audioData = await captureStreamAudio({ streamUrl: request.streamUrl });
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

  const streamMetadata = await streamMetadataPromise;
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

  if (qqCandidates.length > 0) {
    const qqVersions = await fetchSyncedLyricsVersionsForCandidates(
      qqCandidates,
      snippets
    );
    if (qqVersions.length > 0) {
      return { source: "qq", candidates: qqCandidates, versions: qqVersions };
    }
  }

  const netEaseCandidates = await searchNetEaseSongCandidates(snippets, {
    trackMetadata: streamMetadata,
  });
  const netEaseVersions = await fetchSyncedLyricsVersionsForCandidates(
    netEaseCandidates,
    snippets
  );

  return {
    source: "netease",
    candidates: netEaseCandidates,
    versions: netEaseVersions,
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
