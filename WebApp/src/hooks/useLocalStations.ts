"use client";

import { useCallback, useMemo, useSyncExternalStore } from "react";
import type { Station } from "@/features/stations/stationTypes";
import {
  readJson,
  subscribeJsonStorage,
  writeJson,
} from "@/lib/localJsonStorage";

type LocalStationsState = {
  stations: Station[];
  addStation: (station: Station) => void;
  removeStation: (stationId: string) => void;
  hasStation: (stationId: string) => boolean;
};

type StationsSnapshotCacheEntry = {
  raw: string | null;
  stations: Station[];
};

const stationsSnapshotCache = new Map<string, StationsSnapshotCacheEntry>();

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

function isStation(value: unknown): value is Station {
  return (
    typeof value === "object" &&
    value !== null &&
    typeof (value as { id?: unknown }).id === "string"
  );
}

function readStationsSnapshot(key: string, limit: number): Station[] {
  if (typeof window === "undefined") {
    return [];
  }

  const cacheKey = `${key}:${limit}`;
  const raw = window.localStorage.getItem(key);
  const cached = stationsSnapshotCache.get(cacheKey);

  if (cached && cached.raw === raw) {
    return cached.stations;
  }

  const stored = readJson<unknown>(key, []);
  const stations = Array.isArray(stored)
    ? normalizeStations(stored.filter(isStation), limit)
    : [];

  stationsSnapshotCache.set(cacheKey, {
    raw,
    stations,
  });

  return stations;
}

export function useLocalStations(
  key: string,
  limit: number
): LocalStationsState {
  const subscribe = useCallback(
    (onChange: () => void) => subscribeJsonStorage(key, onChange),
    [key]
  );
  const getSnapshot = useCallback(
    () => readStationsSnapshot(key, limit),
    [key, limit]
  );
  const stations = useSyncExternalStore(subscribe, getSnapshot, () => []);

  return useMemo(
    () => ({
      stations,
      addStation: (station: Station) => {
        const withoutDuplicate = stations.filter((item) => item.id !== station.id);
        writeJson(key, normalizeStations([station, ...withoutDuplicate], limit));
      },
      removeStation: (stationId: string) => {
        writeJson(
          key,
          stations.filter((item) => item.id !== stationId)
        );
      },
      hasStation: (stationId: string) =>
        stations.some((station) => station.id === stationId),
    }),
    [key, limit, stations]
  );
}
