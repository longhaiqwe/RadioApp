import type { Station } from "./stationTypes";

const MUSIC_KEYWORDS = [
  "music",
  "pop",
  "hits",
  "rock",
  "jazz",
  "classical",
  "音乐",
  "流行",
  "top40",
  "dance",
  "rnb",
  "lofi",
  "radio",
  "fm",
  "电台",
  "之声",
];

export function filterMusicStations(stations: Station[]): Station[] {
  return stations.filter((station) => {
    const haystack = `${station.name} ${station.tags}`.toLowerCase();
    return MUSIC_KEYWORDS.some((keyword) => haystack.includes(keyword));
  });
}

export function dedupeStationsById(stations: Station[]): Station[] {
  const seen = new Set<string>();
  const unique: Station[] = [];

  for (const station of stations) {
    if (!seen.has(station.id)) {
      seen.add(station.id);
      unique.push(station);
    }
  }

  return unique;
}

export function pickRandomStation(
  stations: Station[],
  excludedId?: string,
  random: () => number = Math.random
): Station | null {
  const candidates = stations.filter((station) => station.id !== excludedId);
  if (candidates.length === 0) return null;
  const index = Math.floor(random() * candidates.length);
  return candidates[index] ?? candidates[0];
}
