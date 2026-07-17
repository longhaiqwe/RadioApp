import { spawn } from "node:child_process";

export async function captureStreamAudio({
  streamUrl,
  durationSeconds = 15,
}: {
  streamUrl: string;
  durationSeconds?: number;
}): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    const errorChunks: Buffer[] = [];
    const child = spawn("ffmpeg", [
      "-hide_banner",
      "-loglevel",
      "error",
      "-nostdin",
      "-rw_timeout",
      "15000000",
      "-i",
      streamUrl,
      "-t",
      String(durationSeconds),
      "-vn",
      "-ac",
      "1",
      "-ar",
      "16000",
      "-f",
      "wav",
      "pipe:1",
    ]);

    const timeout = setTimeout(() => {
      child.kill("SIGKILL");
      reject(new Error("audio_capture_timeout"));
    }, Math.max(durationSeconds + 20, 30) * 1000);

    child.stdout.on("data", (chunk: Buffer) => {
      chunks.push(chunk);
    });
    child.stderr.on("data", (chunk: Buffer) => {
      errorChunks.push(chunk);
    });
    child.on("error", (error) => {
      clearTimeout(timeout);
      reject(error);
    });
    child.on("close", (code) => {
      clearTimeout(timeout);
      if (code !== 0) {
        const message =
          Buffer.concat(errorChunks).toString("utf8").trim() ||
          `ffmpeg_exit_${code}`;
        reject(new Error(message));
        return;
      }

      const audio = Buffer.concat(chunks);
      if (audio.length < 1024) {
        reject(new Error("audio_capture_empty"));
        return;
      }

      resolve(audio);
    });
  });
}
