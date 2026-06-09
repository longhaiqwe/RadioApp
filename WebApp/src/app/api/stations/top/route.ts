import { fetchTopStations } from "@/server/radioBrowser";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const limit = Number(url.searchParams.get("limit") ?? 20);
  const stations = await fetchTopStations(Number.isFinite(limit) ? limit : 20);

  return Response.json({ stations });
}
