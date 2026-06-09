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

const stringValue = (value: unknown): string =>
  typeof value === "string" ? value : "";

const numberValue = (value: unknown): number =>
  typeof value === "number" && Number.isFinite(value) ? value : 0;

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

function sanitizeStation(value: unknown): Station | null {
  if (typeof value !== "object" || value === null) {
    return null;
  }

  const record = value as Record<string, unknown>;
  const stationuuid = stringValue(record.stationuuid) || stringValue(record.id);
  const name = stringValue(record.name).trim();
  const url = stringValue(record.url);
  const urlResolved = stringValue(record.urlResolved) || url;
  const id = stationuuid.trim();

  if (id.length === 0 || name.length === 0 || urlResolved.trim().length === 0) {
    return null;
  }

  return {
    changeuuid: stringValue(record.changeuuid),
    stationuuid,
    id,
    name,
    url,
    urlResolved,
    homepage: stringValue(record.homepage),
    favicon: stringValue(record.favicon),
    tags: stringValue(record.tags),
    country: stringValue(record.country),
    countrycode: stringValue(record.countrycode),
    state: stringValue(record.state),
    language: stringValue(record.language),
    languagecodes:
      typeof record.languagecodes === "string" ? record.languagecodes : null,
    votes: numberValue(record.votes),
    codec: stringValue(record.codec),
    bitrate: numberValue(record.bitrate),
    hls: numberValue(record.hls),
    lastcheckok: numberValue(record.lastcheckok),
    clickcount: numberValue(record.clickcount),
    clicktrend: numberValue(record.clicktrend),
  };
}

function readStorageSnapshot(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function readStationsSnapshot(key: string, limit: number): Station[] {
  if (typeof window === "undefined") {
    return [];
  }

  const cacheKey = `${key}:${limit}`;
  const raw = readStorageSnapshot(key);
  const cached = stationsSnapshotCache.get(cacheKey);

  if (cached && cached.raw === raw) {
    return cached.stations;
  }

  const stored = readJson<unknown>(key, []);
  const stations = Array.isArray(stored)
    ? normalizeStations(
        stored
          .map(sanitizeStation)
          .filter((station): station is Station => station !== null),
        limit
      )
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
