"use client";

import useSWR from "swr";
import { getTopStations, searchStations } from "@/lib/stationApi";

export function useTopStations() {
  return useSWR("stations:top", getTopStations);
}

export function useStationSearch(query: string) {
  return useSWR(
    query.trim().length > 0 ? ["stations:search", query] : null,
    ([, value]) => searchStations(value),
  );
}
