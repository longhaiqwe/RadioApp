import type { StreamTrackMetadata } from "@/features/recognition/recognitionTypes";

type FetchLike = typeof fetch;

const MAX_METADATA_BYTES = 256 * 1024;
const DEFAULT_TIMEOUT_MS = 3500;

export async function fetchStreamTrackMetadata({
  streamUrl,
  fetchImpl = fetch,
  timeoutMs = DEFAULT_TIMEOUT_MS,
}: {
  streamUrl: string;
  fetchImpl?: FetchLike;
  timeoutMs?: number;
}): Promise<StreamTrackMetadata | null> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetchImpl(streamUrl, {
      headers: {
        Accept: "*/*",
        "Icy-MetaData": "1",
        "User-Agent": "Mozilla/5.0",
      },
      signal: controller.signal,
    }).catch(() => null);
    if (!response?.ok || !response.body) return null;

    const metaInt = Number(response.headers.get("icy-metaint"));
    if (!Number.isFinite(metaInt) || metaInt <= 0) return null;

    return await readFirstIcyMetadataBlock(response.body, metaInt);
  } finally {
    clearTimeout(timeout);
    controller.abort();
  }
}

export function parseIcyMetadataBlock(block: string) {
  const streamTitle = block.match(/StreamTitle='([^']*)'/i)?.[1]?.trim();
  return streamTitle ? parseStreamTitle(streamTitle) : null;
}

export function parseStreamTitle(rawTitle: string): StreamTrackMetadata | null {
  const cleanedTitle = rawTitle.replace(/\s+/g, " ").trim();
  if (!cleanedTitle) return null;

  const separatorMatch = cleanedTitle.match(/\s[-–—]\s/);
  if (!separatorMatch || typeof separatorMatch.index !== "number") {
    return {
      rawTitle: cleanedTitle,
      title: cleanedTitle,
    };
  }

  const separatorIndex = separatorMatch.index;
  const artist = cleanedTitle.slice(0, separatorIndex).trim();
  const title = cleanedTitle.slice(separatorIndex + separatorMatch[0].length).trim();

  return {
    rawTitle: cleanedTitle,
    ...(title ? { title } : {}),
    ...(artist ? { artist } : {}),
  };
}

async function readFirstIcyMetadataBlock(
  body: ReadableStream<Uint8Array>,
  metaInt: number
) {
  const reader = body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  try {
    while (totalBytes <= metaInt + 1 + 4080 && totalBytes < MAX_METADATA_BYTES) {
      const { value, done } = await reader.read();
      if (done) break;
      if (!value) continue;

      chunks.push(value);
      totalBytes += value.length;

      const metadata = readMetadataFromBuffer(concatChunks(chunks, totalBytes), metaInt);
      if (metadata) return metadata;
    }
  } finally {
    await reader.cancel().catch(() => undefined);
  }

  return null;
}

function readMetadataFromBuffer(buffer: Uint8Array, metaInt: number) {
  if (buffer.length <= metaInt) return null;

  const metadataLength = buffer[metaInt] * 16;
  if (metadataLength === 0) return null;
  if (buffer.length < metaInt + 1 + metadataLength) return null;

  const metadataBytes = buffer.slice(metaInt + 1, metaInt + 1 + metadataLength);
  const metadataBlock = new TextDecoder()
    .decode(metadataBytes)
    .replace(/\0+$/g, "")
    .trim();

  return parseIcyMetadataBlock(metadataBlock);
}

function concatChunks(chunks: Uint8Array[], totalBytes: number) {
  const buffer = new Uint8Array(totalBytes);
  let offset = 0;

  for (const chunk of chunks) {
    buffer.set(chunk, offset);
    offset += chunk.length;
  }

  return buffer;
}
