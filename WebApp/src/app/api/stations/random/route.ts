import { fetchRandomStation } from "@/server/radioBrowser";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const exclude = url.searchParams.get("exclude") ?? undefined;
  const station = await fetchRandomStation(exclude);

  return Response.json({ station });
}
