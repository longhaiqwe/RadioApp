"use client";

import useSWR from "swr";
import type { Station } from "@/features/stations/stationTypes";
import { getTopStations, searchStations } from "@/lib/stationApi";

export function useTopStations(fallbackData?: Station[]) {
  return useSWR("stations:top", getTopStations, {
    fallbackData,
  });
}

export function useStationSearch(query: string) {
  const normalizedQuery = query.trim();

  return useSWR(
    normalizedQuery.length > 0 ? ["stations:search", normalizedQuery] : null,
    ([, value]) => searchStations(value),
  );
}
