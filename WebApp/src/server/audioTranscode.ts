import { spawn } from "node:child_process";
import { Readable } from "node:stream";

export function transcodeStreamToMp3({
  streamUrl,
  signal,
}: {
  streamUrl: string;
  signal: AbortSignal;
}) {
  const child = spawn("ffmpeg", [
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
    streamUrl,
    "-vn",
    "-codec:a",
    "libmp3lame",
    "-b:a",
    "128k",
    "-f",
    "mp3",
    "pipe:1",
  ]);

  const killChild = () => {
    if (!child.killed) {
      child.kill("SIGKILL");
    }
  };

  child.stderr.on("data", () => {
    // Drain stderr so long-running ffmpeg processes cannot block on logs.
  });
  child.once("close", () => {
    signal.removeEventListener("abort", killChild);
  });
  child.once("error", killChild);
  signal.addEventListener("abort", killChild, { once: true });

  return Readable.toWeb(child.stdout) as ReadableStream<Uint8Array>;
}
