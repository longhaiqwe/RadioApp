import { fetchSearchStations } from "@/server/radioBrowser";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const query = url.searchParams.get("q")?.trim() ?? "";

  if (query.length === 0) {
    return Response.json({ stations: [] });
  }

  try {
    const stations = await fetchSearchStations(query);
    return Response.json({ stations });
  } catch {
    return Response.json(
      { error: "SEARCH_FAILED", message: "暂时无法搜索电台，请稍后再试。" },
      { status: 502 }
    );
  }
}
