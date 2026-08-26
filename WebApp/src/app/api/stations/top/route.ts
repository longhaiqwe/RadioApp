import { fetchTopStations } from "@/server/radioBrowser";

const DEFAULT_LIMIT = 20;
const MIN_LIMIT = 1;
const MAX_LIMIT = 50;

export async function GET(request: Request) {
  const url = new URL(request.url);
  const parsedLimit = Number.parseInt(
    url.searchParams.get("limit") ?? String(DEFAULT_LIMIT),
    10
  );
  const limit = Number.isFinite(parsedLimit)
    ? Math.min(MAX_LIMIT, Math.max(MIN_LIMIT, parsedLimit))
    : DEFAULT_LIMIT;
  const stations = await fetchTopStations(limit);

  return Response.json({ stations });
}
