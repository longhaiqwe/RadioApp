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

export function useLocalStations(
  key: string,
  limit: number
): LocalStationsState {
  const [stations, setStations] = useState<Station[]>(() =>
    readJson<Station[]>(key, [])
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
          return [station, ...withoutDuplicate].slice(0, limit);
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
