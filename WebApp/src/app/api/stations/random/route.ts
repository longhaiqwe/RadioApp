import { fetchRandomStation } from "@/server/radioBrowser";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const excludeParam = url.searchParams.get("exclude")?.trim();
  const exclude =
    excludeParam && excludeParam.length > 0 ? excludeParam : undefined;
  const station = await fetchRandomStation(exclude);

  return Response.json({ station });
}
