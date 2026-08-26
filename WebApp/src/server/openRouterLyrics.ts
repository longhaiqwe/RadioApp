import type {
  LyricSnippet,
  LyricsTranscription,
  LyricsTranscriptionSegment,
} from "@/features/recognition/recognitionTypes";

type FetchLike = typeof fetch;

type OpenRouterChoice = {
  message?: {
    content?: string;
  };
};

type OpenRouterResponse = {
  choices?: OpenRouterChoice[];
};

type LyricsAnalysisPayload = {
  transcript?: unknown;
  text?: unknown;
  snippets?: LyricsAnalysisSnippetPayload[];
  segments?: LyricsAnalysisSnippetPayload[];
};

type LyricsAnalysisSnippetPayload = {
  text?: unknown;
  start_seconds?: unknown;
  startSeconds?: unknown;
  end_seconds?: unknown;
  endSeconds?: unknown;
  confidence?: unknown;
  confidence_score?: unknown;
  confidenceScore?: unknown;
};

export type OpenRouterLyricsRequestInput = {
  apiKey: string;
  audioBase64: string;
  model: string;
  languageHint?: string;
};

export function buildOpenRouterLyricsRequest({
  apiKey,
  audioBase64,
  model,
  languageHint,
}: OpenRouterLyricsRequestInput) {
  const promptLines = [
    "Analyze this short radio audio clip and extract only likely sung lyric fragments.",
    "Ignore DJ speech, station IDs, advertisements, commentary, crowd noise, and purely instrumental sections.",
    "Return JSON only. Do not wrap the JSON in markdown.",
    'Use this exact shape: {"transcript":"string","snippets":[{"text":"string","start_seconds":number|null,"end_seconds":number|null,"confidence":number}]}',
    "Rules:",
    "1. transcript must contain only lyric text that is likely being sung.",
    "2. snippets must contain 0 to 4 unique lyric fragments most useful for song lookup.",
    "3. confidence must be between 0 and 1.",
    "4. Use null timestamps when unsure.",
    '5. If the clip is mostly speech or no lyrics are discernible, return {"transcript":"","snippets":[]}.',
  ];

  if (languageHint) {
    promptLines.push(`Likely language: ${languageHint}.`);
  }

  const body = {
    model,
    temperature: 0,
    max_tokens: 700,
    response_format: { type: "json_object" },
    messages: [
      {
        role: "system",
        content:
          "You extract lyric fragments from short radio audio clips and respond with JSON only.",
      },
      {
        role: "user",
        content: [
          {
            type: "text",
            text: promptLines.join("\n"),
          },
          {
            type: "input_audio",
            input_audio: {
              data: audioBase64,
              format: "wav",
            },
          },
        ],
      },
    ],
  };

  return {
    url: "https://openrouter.ai/api/v1/chat/completions",
    body,
    init: {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "X-OpenRouter-Title": "Shiyin FM Web",
      },
      body: JSON.stringify(body),
    },
  };
}

export async function transcribeLyricsWithOpenRouter({
  audioData,
  languageHint,
  fetchImpl = fetch,
}: {
  audioData: Buffer;
  languageHint?: string;
  fetchImpl?: FetchLike;
}): Promise<LyricsTranscription> {
  const apiKey = process.env.OPENROUTER_API_KEY?.trim();
  if (!apiKey) {
    throw new Error("missing_openrouter_api_key");
  }

  const request = buildOpenRouterLyricsRequest({
    apiKey,
    audioBase64: audioData.toString("base64"),
    model:
      process.env.OPENROUTER_LYRIC_MODEL?.trim() ||
      process.env.OPENROUTER_MODEL?.trim() ||
      "xiaomi/mimo-v2.5",
    languageHint,
  });

  const response = await fetchImpl(request.url, request.init);
  if (!response.ok) {
    throw new Error(`openrouter_http_${response.status}`);
  }

  return parseOpenRouterLyricsResponse(await response.json());
}

export function parseOpenRouterLyricsResponse(
  response: OpenRouterResponse
): LyricsTranscription {
  const rawContent =
    response.choices?.[0]?.message?.content?.trim() ??
    "";
  const payload = parseLyricsPayload(extractJSONPayload(rawContent));
  const rawSegments = payload.snippets ?? payload.segments ?? [];

  const segments = rawSegments.flatMap((segment) => {
    const parsed = parseSegment(segment);
    return parsed ? [parsed] : [];
  });
  const transcript = cleanSnippetText(readString(payload.transcript ?? payload.text));
  const finalText = transcript || segments.map((segment) => segment.text).join(" ");

  if (!finalText && segments.length === 0) {
    throw new Error("empty_lyrics_transcript");
  }

  return { text: finalText, segments };
}

export function extractLikelyLyricSnippets(
  transcription: LyricsTranscription,
  maxCount = 4
): LyricSnippet[] {
  const snippets: LyricSnippet[] = [];
  const seen = new Set<string>();

  for (const segment of [...transcription.segments].sort(segmentPriority)) {
    const cleaned = cleanSnippetText(segment.text);
    const normalized = normalizeComparisonText(cleaned);

    if (normalized.length < 6) continue;
    if (isLikelySpeechOrStationText(cleaned)) continue;

    const confidenceScore = clampConfidence(segment.confidence);
    if (confidenceScore < 0.2) continue;
    if (seen.has(normalized)) continue;

    seen.add(normalized);
    snippets.push({
      text: cleaned,
      start: segment.start,
      end: segment.end,
      confidenceScore,
    });

    if (snippets.length >= maxCount) {
      return snippets;
    }
  }

  if (snippets.length === 0) {
    const fallbackText = cleanSnippetText(transcription.text);
    const normalized = normalizeComparisonText(fallbackText);
    if (normalized.length >= 6 && !isLikelySpeechOrStationText(fallbackText)) {
      snippets.push({
        text: fallbackText,
        confidenceScore: 0.3,
      });
    }
  }

  return snippets;
}

function parseLyricsPayload(jsonString: string): LyricsAnalysisPayload {
  const parsed = JSON.parse(jsonString) as unknown;
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new Error("malformed_lyrics_payload");
  }

  return parsed as LyricsAnalysisPayload;
}

function extractJSONPayload(rawContent: string) {
  const trimmed = rawContent.trim();
  const startIndex = trimmed.indexOf("{");
  const endIndex = trimmed.lastIndexOf("}");

  if (startIndex >= 0 && endIndex >= startIndex) {
    return trimmed.slice(startIndex, endIndex + 1);
  }

  return trimmed;
}

function parseSegment(
  payload: LyricsAnalysisSnippetPayload
): LyricsTranscriptionSegment | null {
  const text = cleanSnippetText(readString(payload.text));
  if (!text) return null;

  return {
    start: readNumber(payload.start_seconds ?? payload.startSeconds),
    end: readNumber(payload.end_seconds ?? payload.endSeconds),
    text,
    confidence: readNumber(
      payload.confidence ?? payload.confidence_score ?? payload.confidenceScore
    ),
  };
}

function readString(value: unknown) {
  return typeof value === "string" ? value : "";
}

function readNumber(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function segmentPriority(
  lhs: LyricsTranscriptionSegment,
  rhs: LyricsTranscriptionSegment
) {
  return clampConfidence(rhs.confidence) - clampConfidence(lhs.confidence);
}

function clampConfidence(confidence: number | undefined) {
  if (typeof confidence !== "number" || !Number.isFinite(confidence)) {
    return 0.35;
  }

  return Math.min(Math.max(confidence, 0), 1);
}

function cleanSnippetText(text: string) {
  return text
    .replace(/\s+/g, " ")
    .replace(/[“”"「」『』]/g, "")
    .trim();
}

function normalizeComparisonText(text: string) {
  return cleanSnippetText(text)
    .toLowerCase()
    .replace(/[\p{P}\p{S}\s]/gu, "");
}

function isLikelySpeechOrStationText(text: string) {
  const lowered = text.toLowerCase();
  return [
    "dj",
    "fm",
    "电台",
    "广播",
    "主持",
    "欢迎收听",
    "广告",
    "直播间",
  ].some((keyword) => lowered.includes(keyword));
}
