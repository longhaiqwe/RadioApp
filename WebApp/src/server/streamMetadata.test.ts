import { describe, expect, it, vi } from "vitest";
import {
  fetchStreamTrackMetadata,
  parseIcyMetadataBlock,
  parseStreamTitle,
} from "./streamMetadata";

function makeIcyBody(metaInt: number, metadata: string) {
  const encoder = new TextEncoder();
  const audioBytes = encoder.encode("x".repeat(metaInt));
  const metadataBytes = encoder.encode(metadata);
  const blockCount = Math.ceil(metadataBytes.length / 16);
  const paddedMetadata = new Uint8Array(blockCount * 16);
  paddedMetadata.set(metadataBytes);

  const body = new Uint8Array(audioBytes.length + 1 + paddedMetadata.length);
  body.set(audioBytes);
  body[audioBytes.length] = blockCount;
  body.set(paddedMetadata, audioBytes.length + 1);

  return new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(body);
      controller.close();
    },
  });
}

describe("streamMetadata", () => {
  it("parses artist and title from an ICY StreamTitle block", () => {
    expect(
      parseIcyMetadataBlock("StreamTitle='谭咏麟 - 一生中最爱';StreamUrl='';")
    ).toEqual({
      rawTitle: "谭咏麟 - 一生中最爱",
      artist: "谭咏麟",
      title: "一生中最爱",
    });
  });

  it("supports title-only stream titles when artist is missing", () => {
    expect(parseStreamTitle("一时的选择")).toEqual({
      rawTitle: "一时的选择",
      title: "一时的选择",
    });
  });

  it("fetches the first embedded ICY metadata block from a stream", async () => {
    const fetchImpl = vi.fn(async () => {
      return new Response(
        makeIcyBody(5, "StreamTitle='谭咏麟 - 一生中最爱';"),
        {
          headers: { "icy-metaint": "5" },
        }
      );
    });

    const metadata = await fetchStreamTrackMetadata({
      streamUrl: "https://example.com/live.mp3",
      fetchImpl,
    });

    expect(fetchImpl).toHaveBeenCalledWith(
      "https://example.com/live.mp3",
      expect.objectContaining({
        headers: expect.objectContaining({ "Icy-MetaData": "1" }),
      })
    );
    expect(metadata).toMatchObject({
      rawTitle: "谭咏麟 - 一生中最爱",
      artist: "谭咏麟",
      title: "一生中最爱",
    });
  });
});
