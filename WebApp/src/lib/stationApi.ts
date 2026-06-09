import type { Station } from "@/features/stations/stationTypes";

type StationsResponse = { stations: Station[] };
type RandomStationResponse = { station: Station | null };

async function fetchJson<T>(url: string): Promise<T> {
  const response = await fetch(url);

  if (!response.ok) {
    throw new Error(`Request failed: ${response.status}`);
  }

  return (await response.json()) as T;
}

export async function getTopStations(): Promise<Station[]> {
  const data = await fetchJson<StationsResponse>("/api/stations/top");
  return data.stations;
}

export async function searchStations(query: string): Promise<Station[]> {
  if (query.trim().length === 0) return [];

  const data = await fetchJson<StationsResponse>(
    `/api/stations/search?q=${encodeURIComponent(query)}`,
  );
  return data.stations;
}

export async function getRandomStation(exclude?: string): Promise<Station | null> {
  const suffix = exclude ? `?exclude=${encodeURIComponent(exclude)}` : "";
  const data = await fetchJson<RandomStationResponse>(
    `/api/stations/random${suffix}`,
  );
  return data.station;
}
