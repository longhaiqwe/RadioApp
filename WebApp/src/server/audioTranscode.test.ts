import { EventEmitter } from "node:events";
import { PassThrough } from "node:stream";
import { spawn } from "node:child_process";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { transcodeStreamToMp3 } from "./audioTranscode";

const spawnMock = vi.hoisted(() => vi.fn());

vi.mock("node:child_process", () => ({
  default: { spawn: spawnMock },
  spawn: spawnMock,
}));

function makeFfmpegProcess() {
  const child = new EventEmitter() as EventEmitter & {
    killed: boolean;
    kill: ReturnType<typeof vi.fn>;
    stderr: PassThrough;
    stdout: PassThrough;
  };
  child.killed = false;
  child.kill = vi.fn(() => {
    child.killed = true;
    return true;
  });
  child.stderr = new PassThrough();
  child.stdout = new PassThrough();
  return child;
}

describe("transcodeStreamToMp3", () => {
  beforeEach(() => {
    vi.mocked(spawn).mockReset();
  });

  it("spawns ffmpeg to convert the source stream into MP3", () => {
    const child = makeFfmpegProcess();
    vi.mocked(spawn).mockReturnValue(child as never);

    transcodeStreamToMp3({
      streamUrl: "http://asiafm.hk:8000/asiahd",
      signal: new AbortController().signal,
    });

    expect(spawn).toHaveBeenCalledWith("ffmpeg", [
      "-hide_banner",
      "-loglevel",
      "error",
      "-nostdin",
      "-rw_timeout",
      "15000000",
      "-reconnect",
      "1",
      "-reconnect_streamed",
      "1",
      "-reconnect_at_eof",
      "1",
      "-reconnect_on_network_error",
      "1",
      "-reconnect_delay_max",
      "5",
      "-i",
      "http://asiafm.hk:8000/asiahd",
      "-vn",
      "-codec:a",
      "libmp3lame",
      "-b:a",
      "128k",
      "-f",
      "mp3",
      "pipe:1",
    ]);
  });

  it("returns ffmpeg stdout as a web stream", async () => {
    const child = makeFfmpegProcess();
    vi.mocked(spawn).mockReturnValue(child as never);

    const stream = transcodeStreamToMp3({
      streamUrl: "http://asiafm.hk:8000/asiahd",
      signal: new AbortController().signal,
    });

    child.stdout.end("mp3-bytes");

    await expect(new Response(stream).text()).resolves.toBe("mp3-bytes");
  });

  it("kills ffmpeg when the client aborts playback", () => {
    const child = makeFfmpegProcess();
    const abortController = new AbortController();
    vi.mocked(spawn).mockReturnValue(child as never);

    transcodeStreamToMp3({
      streamUrl: "http://asiafm.hk:8000/asiahd",
      signal: abortController.signal,
    });

    abortController.abort();

    expect(child.kill).toHaveBeenCalledWith("SIGKILL");
  });
});
