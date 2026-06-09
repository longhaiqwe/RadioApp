"use client";

import { useEffect, useMemo, useState } from "react";
import type { Station } from "@/features/stations/stationTypes";
import { readJson, writeJson } from "@/lib/localJsonStorage";

type LocalStationsState = {
  stations: Station[];
  addStation: (station: Station) => void;
  removeStation: (stationId: string) => void;
  hasStation: (stationId: string) => boolean;
};

function normalizeStations(stations: Station[], limit: number): Station[] {
  const seen = new Set<string>();
  const normalized: Station[] = [];

  for (const station of stations) {
    if (seen.has(station.id)) {
      continue;
    }

    seen.add(station.id);
    normalized.push(station);

    if (normalized.length >= limit) {
      break;
    }
  }

  return normalized;
}

export function useLocalStations(
  key: string,
  limit: number
): LocalStationsState {
  const [stations, setStations] = useState<Station[]>(() =>
    normalizeStations(readJson<Station[]>(key, []), limit)
  );

  useEffect(() => {
    writeJson(key, stations);
  }, [key, stations]);

  return useMemo(
    () => ({
      stations,
      addStation: (station: Station) => {
        setStations((current) => {
          const withoutDuplicate = current.filter(
            (item) => item.id !== station.id
          );
          return normalizeStations([station, ...withoutDuplicate], limit);
        });
      },
      removeStation: (stationId: string) => {
        setStations((current) => current.filter((item) => item.id !== stationId));
      },
      hasStation: (stationId: string) =>
        stations.some((station) => station.id === stationId),
    }),
    [limit, stations]
  );
}
