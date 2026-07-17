import { parseRecognitionRequest } from "@/features/recognition/recognitionSchema";
import { recognizeStation } from "@/server/recognitionService";

export const runtime = "nodejs";

const RECOGNITION_ERROR =
  "暂时没能识别出歌词，请换一段人声更清楚的位置再试。";

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = parseRecognitionRequest(body);

  if (!parsed.ok) {
    return Response.json({ error: parsed.error }, { status: 400 });
  }

  try {
    const result = await recognizeStation(parsed.value);
    return Response.json(result);
  } catch {
    return Response.json({ error: RECOGNITION_ERROR }, { status: 502 });
  }
}
