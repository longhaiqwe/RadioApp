import type { RadioBrowserStation, Station } from "./stationTypes";

const stringValue = (value: unknown): string =>
  typeof value === "string" ? value : "";

const numberValue = (value: unknown): number =>
  typeof value === "number" && Number.isFinite(value) ? value : 0;

export function normalizeStation(raw: RadioBrowserStation): Station {
  const stationuuid = stringValue(raw.stationuuid);
  const url = stringValue(raw.url);
  const urlResolved = stringValue(raw.url_resolved) || url;

  return {
    changeuuid: stringValue(raw.changeuuid),
    stationuuid,
    id: stationuuid,
    name: stringValue(raw.name),
    url,
    urlResolved,
    homepage: stringValue(raw.homepage),
    favicon: stringValue(raw.favicon),
    tags: stringValue(raw.tags),
    country: stringValue(raw.country),
    countrycode: stringValue(raw.countrycode),
    state: stringValue(raw.state),
    language: stringValue(raw.language),
    languagecodes:
      typeof raw.languagecodes === "string" ? raw.languagecodes : null,
    votes: numberValue(raw.votes),
    codec: stringValue(raw.codec),
    bitrate: numberValue(raw.bitrate),
    hls: numberValue(raw.hls),
    lastcheckok: numberValue(raw.lastcheckok),
    clickcount: numberValue(raw.clickcount),
    clicktrend: numberValue(raw.clicktrend),
  };
}

export function normalizeStations(rawStations: RadioBrowserStation[]): Station[] {
  return rawStations
    .map(normalizeStation)
    .filter((station) => station.id.length > 0 && station.urlResolved.length > 0);
}
