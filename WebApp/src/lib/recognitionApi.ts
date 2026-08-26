import type { RecognitionResult } from "@/features/recognition/recognitionTypes";
import type { Station } from "@/features/stations/stationTypes";

export async function recognizeStationFromStream(
  station: Station
): Promise<RecognitionResult> {
  const response = await fetch("/api/recognize", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      streamUrl: station.urlResolved || station.url,
      stationId: station.id,
      stationName: station.name,
      languageHint: station.languagecodes?.split(",")[0] || station.language,
    }),
  });

  const data = await response.json().catch(() => null);

  if (!response.ok) {
    const message =
      typeof data?.error === "string"
        ? data.error
        : "暂时没能识别出歌词，请稍后再试。";
    throw new Error(message);
  }

  return data as RecognitionResult;
}
