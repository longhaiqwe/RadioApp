"use client";

import useSWR from "swr";
import { getTopStations, searchStations } from "@/lib/stationApi";

export function useTopStations() {
  return useSWR("stations:top", getTopStations);
}

export function useStationSearch(query: string) {
  const normalizedQuery = query.trim();

  return useSWR(
    normalizedQuery.length > 0 ? ["stations:search", normalizedQuery] : null,
    ([, value]) => searchStations(value),
  );
}
