import type {
  LyricSnippet,
  SyncedLyricLine,
  SyncedLyrics,
} from "./recognitionTypes";

type SyncedLyricsInput = {
  source: SyncedLyrics["source"];
  rawLrc: string;
  snippets: Pick<LyricSnippet, "text" | "start" | "confidenceScore">[];
  captureDurationSeconds?: number;
  allowUnmatchedLyrics?: boolean;
};

type LyricWindow = {
  time: number;
  text: string;
};

export function buildSyncedLyrics({
  source,
  rawLrc,
  snippets,
  captureDurationSeconds = 15,
  allowUnmatchedLyrics = false,
}: SyncedLyricsInput): SyncedLyrics | null {
  const lines = parseLrcLines(rawLrc);
  if (lines.length === 0) return null;

  const match = findBestLyricMatch(lines, snippets);
  if (!match || match.score < 0.55) {
    return allowUnmatchedLyrics
      ? {
          source,
          rawLrc,
          lines,
        }
      : null;
  }

  return {
    source,
    rawLrc,
    lines,
    matchedSnippet: match.snippet.text,
    confidenceScore: roundScore(match.score),
    estimatedOffsetSeconds: roundScore(
      Math.max(
        0,
        match.time -
          estimateSnippetStartSeconds(
            match.snippet,
            match.snippetIndex,
            snippets.length,
            captureDurationSeconds
          )
      )
    ),
  };
}

export function parseLrcLines(rawLrc: string): SyncedLyricLine[] {
  const parsedLines: SyncedLyricLine[] = [];

  for (const [lineIndex, rawLine] of rawLrc.split(/\r?\n/).entries()) {
    const timestamps = Array.from(rawLine.matchAll(/\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?]/g));
    if (timestamps.length === 0) continue;

    const text = rawLine
      .replace(/\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?]/g, "")
      .trim();
    if (!text) continue;

    for (const timestamp of timestamps) {
      const time = readTimestampSeconds(timestamp);
      if (time === null) continue;

      parsedLines.push({
        id: `${lineIndex}-${time}`,
        time,
        text,
      });
    }
  }

  return parsedLines.sort((lhs, rhs) => lhs.time - rhs.time);
}

function findBestLyricMatch(
  lines: SyncedLyricLine[],
  snippets: Pick<LyricSnippet, "text" | "start" | "confidenceScore">[]
) {
  let bestMatch:
    | {
        snippet: Pick<LyricSnippet, "text" | "start" | "confidenceScore">;
        snippetIndex: number;
        score: number;
        time: number;
      }
    | undefined;
  const windows = buildLyricWindows(lines);

  for (const [snippetIndex, snippet] of snippets.entries()) {
    const normalizedSnippet = normalizeLyricText(snippet.text);
    if (normalizedSnippet.length < 6) continue;

    for (const window of windows) {
      const normalizedWindow = normalizeLyricText(window.text);
      if (normalizedWindow.length < 4) continue;

      const score =
        normalizedWindow.includes(normalizedSnippet) ||
        normalizedSnippet.includes(normalizedWindow)
          ? Math.min(normalizedWindow.length, normalizedSnippet.length) /
            Math.max(normalizedWindow.length, normalizedSnippet.length)
          : bigramDiceScore(normalizedSnippet, normalizedWindow);
      const weightedScore = score * (0.85 + snippet.confidenceScore * 0.15);

      if (!bestMatch || weightedScore > bestMatch.score) {
        bestMatch = {
          snippet,
          snippetIndex,
          score: weightedScore,
          time: window.time,
        };
      }
    }
  }

  return bestMatch;
}

function estimateSnippetStartSeconds(
  snippet: Pick<LyricSnippet, "start">,
  snippetIndex: number,
  snippetCount: number,
  captureDurationSeconds: number
) {
  if (typeof snippet.start === "number") return snippet.start;
  if (snippetCount <= 1) return 0;

  return (captureDurationSeconds * snippetIndex) / snippetCount;
}

function buildLyricWindows(lines: SyncedLyricLine[]) {
  const windows: LyricWindow[] = [];

  lines.forEach((line, index) => {
    windows.push({ time: line.time, text: line.text });

    const nextLine = lines[index + 1];
    if (nextLine) {
      windows.push({ time: line.time, text: `${line.text}${nextLine.text}` });
    }

    const thirdLine = lines[index + 2];
    if (nextLine && thirdLine) {
      windows.push({
        time: line.time,
        text: `${line.text}${nextLine.text}${thirdLine.text}`,
      });
    }
  });

  return windows;
}

function readTimestampSeconds(match: RegExpMatchArray) {
  const minutes = Number(match[1]);
  const seconds = Number(match[2]);
  const fraction = match[3] ?? "";
  if (!Number.isFinite(minutes) || !Number.isFinite(seconds)) return null;

  return minutes * 60 + seconds + readFractionSeconds(fraction);
}

function readFractionSeconds(value: string) {
  if (!value) return 0;
  return Number(`0.${value.padEnd(3, "0").slice(0, 3)}`);
}

function normalizeLyricText(text: string) {
  return normalizeChineseVariants(text.toLowerCase())
    .replace(/<[^>]*>/g, "")
    .replace(/[\p{P}\p{S}\s]/gu, "");
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

  return (2 * overlap) / (lhsBigrams.length + rhsBigrams.length);
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
    絕: "绝",
    熱: "热",
    動: "动",
    諒: "谅",
    緊: "紧",
    過: "过",
    遠: "远",
    變: "变",
    給: "给",
    見: "见",
    點: "点",
    風: "风",
    雲: "云",
    開: "开",
    夢: "梦",
    頭: "头",
    體: "体",
    樂: "乐",
    間: "间",
  };

  return text.replace(
    /[愛與無連還掛誰會傷聽說懷絕熱動諒緊過遠變給見點風雲開夢頭體樂間]/g,
    (character) => variantMap[character] ?? character
  );
}
