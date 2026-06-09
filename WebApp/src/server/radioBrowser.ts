import { presetStations } from "@/data/presetStations";
import {
  dedupeStationsById,
  filterMusicStations,
  pickRandomStation,
} from "@/features/stations/stationFilters";
import { normalizeStations } from "@/features/stations/stationNormalization";
import {
  buildSearchKeywords,
  stationMatchesKeywords,
} from "@/features/stations/stationSearch";
import type {
  RadioBrowserStation,
  Station,
} from "@/features/stations/stationTypes";

const MIRRORS = [
  "https://de1.api.radio-browser.info/json",
  "https://fr1.api.radio-browser.info/json",
  "https://at1.api.radio-browser.info/json",
  "https://nl1.api.radio-browser.info/json",
  "https://all.api.radio-browser.info/json",
];

type StationSearchPayload = Record<string, boolean | number | string>;

type NextFetchInit = RequestInit & {
  next: {
    revalidate: number;
  };
};

export async function postStationSearch(
  payload: StationSearchPayload
): Promise<Station[]> {
  let lastError: unknown;

  for (const mirror of MIRRORS) {
    try {
      const response = await fetch(`${mirror}/stations/search`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "User-Agent": "RadioApp-Web/1.0",
        },
        body: JSON.stringify(payload),
        next: { revalidate: 120 },
      } satisfies NextFetchInit);

      if (!response.ok) {
        throw new Error(`radio-browser returned ${response.status}`);
      }

      const rawStations: unknown = await response.json();
      if (!Array.isArray(rawStations)) {
        throw new Error("radio-browser returned an invalid station list");
      }

      return dedupeStationsById(
        normalizeStations(rawStations as RadioBrowserStation[])
      );
    } catch (error) {
      lastError = error;
    }
  }

  throw lastError;
}

export async function fetchTopStations(limit = 20): Promise<Station[]> {
  try {
    const stations = await postStationSearch({
      countrycode: "CN",
      order: "clickcount",
      reverse: true,
      limit: 100,
      hidebroken: true,
    });

    return filterMusicStations(stations).slice(0, limit);
  } catch {
    return presetStations.slice(0, limit);
  }
}

export async function fetchSearchStations(query: string): Promise<Station[]> {
  const keywords = buildSearchKeywords(query);
  if (keywords.length === 0) return [];

  const stations = await postStationSearch({
    name: keywords[0] ?? "",
    limit: 500,
    hidebroken: true,
  });

  const filteredStations = stations.filter((station) =>
    stationMatchesKeywords(station, keywords)
  );

  return filteredStations.length > 0 ? filteredStations : stations;
}

export async function fetchRandomStation(
  excludedId?: string
): Promise<Station | null> {
  try {
    const stations = await postStationSearch({
      countrycode: "CN",
      order: "random",
      limit: 100,
      hidebroken: true,
    });

    return pickRandomStation(filterMusicStations(stations), excludedId);
  } catch {
    return pickRandomStation(presetStations, excludedId);
  }
}
