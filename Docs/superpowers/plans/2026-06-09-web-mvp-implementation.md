# RadioApp Web MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a `/WebApp` Next.js MVP that lets users discover, search, play, favorite, and revisit radio stations in the browser while routing song recognition interest into a macOS waitlist.

**Architecture:** `/WebApp` is isolated from the Xcode project. The browser UI owns playback and local favorites/recent state, while Next.js Route Handlers proxy radio-browser and submit waitlist entries to Supabase. The web visual system ports the existing SwiftUI neon/glass design tokens instead of creating a new brand.

**Tech Stack:** Next.js App Router, TypeScript, Tailwind CSS, SWR, React Context/hooks, Supabase JS, Vitest, Testing Library, Playwright.

---

## References

- Spec: `Docs/superpowers/specs/2026-06-09-web-mvp-design.md`
- Current Swift model reference: `RadioApp/Models/Station.swift`
- Current station service reference: `RadioApp/Services/RadioService.swift`
- Current design tokens reference: `RadioApp/Views/Components/DesignSystem.swift`
- Current avatar fallback reference: `RadioApp/Views/Components/StationAvatarView.swift`
- Preset data source: `RadioApp/Resources/preset_stations.json`
- Next.js create-next-app CLI: https://nextjs.org/docs/pages/api-reference/cli/create-next-app
- Next.js Route Handlers: https://nextjs.org/docs/app/api-reference/file-conventions/route
- Supabase Next.js guide: https://supabase.com/docs/guides/auth/quickstarts/nextjs

## Target File Structure

Create these files under `/WebApp`:

```text
WebApp/
  .env.example
  package.json
  next.config.ts
  vitest.config.ts
  playwright.config.ts
  src/
    app/
      api/
        stations/
          top/route.ts
          search/route.ts
          random/route.ts
        waitlist/route.ts
      globals.css
      layout.tsx
      page.tsx
    components/
      AnimatedMeshBackground.tsx
      EmptyState.tsx
      GlassCard.tsx
      IconButton.tsx
      MiniPlayer.tsx
      PlayerPanel.tsx
      StationAvatar.tsx
      StationCard.tsx
      StationGrid.tsx
      WaitlistModal.tsx
    data/
      presetStations.ts
    features/
      player/
        AudioPlayerProvider.tsx
        audioPlayerReducer.ts
        audioPlayerTypes.ts
      stations/
        stationFilters.ts
        stationSearch.ts
      waitlist/
        waitlistSchema.ts
    hooks/
      useLocalStations.ts
      useStations.ts
    lib/
      localJsonStorage.ts
      stationApi.ts
      supabaseAdmin.ts
    server/
      radioBrowser.ts
      waitlistRepository.ts
    test/
      setupTests.ts
      fixtures.ts
  supabase/
    migrations/
      0001_waitlist_submissions.sql
  tests/
    e2e/
      web-mvp.spec.ts
```

## Implementation Rules

- Do not modify the Xcode project while implementing WebApp.
- Keep `RadioApp.xcodeproj/xcshareddata/xcschemes/RadioApp.xcscheme` out of WebApp commits unless the user separately asks for it.
- Commit after each task.
- Prefer failing tests first, then minimal code.
- Use Chinese user-facing copy in the app shell to match the existing product.
- Keep the first route as the radio experience itself, not a marketing page.

---

### Task 1: Scaffold `/WebApp` and Test Tooling

**Files:**
- Create: `WebApp/`
- Create: `WebApp/vitest.config.ts`
- Create: `WebApp/src/test/setupTests.ts`
- Modify: `WebApp/package.json`
- Create: `WebApp/.env.example`

- [ ] **Step 1: Scaffold the Next.js app**

Run:

```bash
npx create-next-app@latest WebApp \
  --ts \
  --tailwind \
  --eslint \
  --app \
  --src-dir \
  --import-alias "@/*" \
  --use-npm \
  --disable-git \
  --yes
```

Expected: `WebApp/package.json`, `WebApp/src/app/page.tsx`, and `WebApp/src/app/globals.css` exist.

- [ ] **Step 2: Install runtime and test dependencies**

Run:

```bash
cd WebApp
npm install @supabase/supabase-js swr lucide-react clsx
npm install --save-dev vitest jsdom @testing-library/react @testing-library/jest-dom @testing-library/user-event @playwright/test
```

Expected: `package-lock.json` updates and npm exits successfully.

- [ ] **Step 3: Configure Vitest**

Write `WebApp/vitest.config.ts`:

```ts
import path from "node:path";
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./src/test/setupTests.ts"],
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
```

Write `WebApp/src/test/setupTests.ts`:

```ts
import "@testing-library/jest-dom/vitest";
```

- [ ] **Step 4: Update package scripts**

Modify `WebApp/package.json` scripts to include:

```json
{
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "eslint .",
    "test": "vitest run",
    "test:watch": "vitest",
    "e2e": "playwright test"
  }
}
```

Keep existing dependencies and package metadata generated by `create-next-app`.

- [ ] **Step 5: Add local environment template**

Write `WebApp/.env.example`:

```dotenv
SUPABASE_URL=https://example.supabase.co
SUPABASE_SECRET_KEY=sb_secret_replace_me
```

- [ ] **Step 6: Run baseline checks**

Run:

```bash
cd WebApp
npm run test
npm run lint
npm run build
```

Expected: All commands pass with the generated starter app.

- [ ] **Step 7: Commit scaffold**

Run:

```bash
git add WebApp
git commit -m "feat(web): scaffold Next.js app"
```

---

### Task 2: Station Types, Normalization, and Preset Data

**Files:**
- Create: `WebApp/src/features/stations/stationTypes.ts`
- Create: `WebApp/src/features/stations/stationNormalization.ts`
- Create: `WebApp/src/features/stations/stationNormalization.test.ts`
- Create: `WebApp/src/data/presetStations.ts`
- Create: `WebApp/src/test/fixtures.ts`

- [ ] **Step 1: Write failing station normalization tests**

Write `WebApp/src/features/stations/stationNormalization.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { normalizeStation, normalizeStations } from "./stationNormalization";

describe("stationNormalization", () => {
  it("maps radio-browser snake_case fields to the web Station type", () => {
    const station = normalizeStation({
      changeuuid: "change-1",
      stationuuid: "station-1",
      name: "清晨音乐台",
      url: "http://example.com/live.mp3",
      url_resolved: "http://cdn.example.com/live.mp3",
      homepage: "https://example.com",
      favicon: "",
      tags: "music,pop",
      country: "China",
      countrycode: "CN",
      state: "Kwangsi",
      language: "chinese",
      languagecodes: "zh",
      votes: 42,
      codec: "MP3",
      bitrate: 128,
      hls: 0,
      lastcheckok: 1,
      clickcount: 7,
      clicktrend: 3,
    });

    expect(station).toEqual({
      changeuuid: "change-1",
      stationuuid: "station-1",
      id: "station-1",
      name: "清晨音乐台",
      url: "http://example.com/live.mp3",
      urlResolved: "http://cdn.example.com/live.mp3",
      homepage: "https://example.com",
      favicon: "",
      tags: "music,pop",
      country: "China",
      countrycode: "CN",
      state: "Kwangsi",
      language: "chinese",
      languagecodes: "zh",
      votes: 42,
      codec: "MP3",
      bitrate: 128,
      hls: 0,
      lastcheckok: 1,
      clickcount: 7,
      clicktrend: 3,
    });
  });

  it("uses url when url_resolved is missing", () => {
    const station = normalizeStation({
      stationuuid: "station-2",
      name: "Fallback FM",
      url: "https://example.com/fallback.mp3",
    });

    expect(station.urlResolved).toBe("https://example.com/fallback.mp3");
  });

  it("filters invalid stations from arrays", () => {
    const stations = normalizeStations([
      { stationuuid: "ok", name: "OK FM", url: "https://example.com/ok.mp3" },
      { stationuuid: "", name: "No ID", url: "https://example.com/no-id.mp3" },
      { stationuuid: "no-url", name: "No URL", url: "" },
    ]);

    expect(stations.map((station) => station.id)).toEqual(["ok"]);
  });
});
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
cd WebApp
npm run test -- src/features/stations/stationNormalization.test.ts
```

Expected: FAIL because `stationNormalization` does not exist.

- [ ] **Step 3: Add Station types**

Write `WebApp/src/features/stations/stationTypes.ts`:

```ts
export type Station = {
  changeuuid: string;
  stationuuid: string;
  id: string;
  name: string;
  url: string;
  urlResolved: string;
  homepage: string;
  favicon: string;
  tags: string;
  country: string;
  countrycode: string;
  state: string;
  language: string;
  languagecodes: string | null;
  votes: number;
  codec: string;
  bitrate: number;
  hls: number;
  lastcheckok: number;
  clickcount: number;
  clicktrend: number;
};

export type RadioBrowserStation = Partial<{
  changeuuid: string;
  stationuuid: string;
  name: string;
  url: string;
  url_resolved: string;
  homepage: string;
  favicon: string;
  tags: string;
  country: string;
  countrycode: string;
  state: string;
  language: string;
  languagecodes: string | null;
  votes: number;
  codec: string;
  bitrate: number;
  hls: number;
  lastcheckok: number;
  clickcount: number;
  clicktrend: number;
}>;
```

- [ ] **Step 4: Implement normalization**

Write `WebApp/src/features/stations/stationNormalization.ts`:

```ts
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
```

- [ ] **Step 5: Add fixtures**

Write `WebApp/src/test/fixtures.ts`:

```ts
import type { Station } from "@/features/stations/stationTypes";

export const stationFixture: Station = {
  changeuuid: "change-1",
  stationuuid: "station-1",
  id: "station-1",
  name: "清晨音乐台",
  url: "http://lhttp.qingting.fm/live/4915/64k.mp3",
  urlResolved: "http://lhttp.qingting.fm/live/4915/64k.mp3",
  homepage: "https://m.weibo.cn/u/2022851417",
  favicon: "",
  tags: "music,pop music",
  country: "China",
  countrycode: "CN",
  state: "Kwangsi",
  language: "chinese",
  languagecodes: "zh",
  votes: 4238,
  codec: "MP3",
  bitrate: 0,
  hls: 0,
  lastcheckok: 1,
  clickcount: 38,
  clicktrend: 38,
};

export const secondStationFixture: Station = {
  ...stationFixture,
  changeuuid: "change-2",
  stationuuid: "station-2",
  id: "station-2",
  name: "CNR-3 音乐之声",
  url: "https://ngcdn001.cnr.cn/live/yyzs/index.m3u8",
  urlResolved: "https://ngcdn001.cnr.cn/live/yyzs/index.m3u8",
  favicon: "bundle://cnr3_cover_v2",
};
```

- [ ] **Step 6: Add preset stations**

Write `WebApp/src/data/presetStations.ts` with at least these three stations derived from `RadioApp/Resources/preset_stations.json`:

```ts
import type { Station } from "@/features/stations/stationTypes";

export const presetStations: Station[] = [
  {
    changeuuid: "b8d9b20a-9d1f-459d-96ac-c4d034b76e63",
    stationuuid: "24711f7f-8ff5-4141-8e0f-ab17f3da1b89",
    id: "24711f7f-8ff5-4141-8e0f-ab17f3da1b89",
    name: "怀集音乐之声",
    url: "https://lhttp.qingting.fm/live/4804/64k.mp3",
    urlResolved: "https://lhttp.qingting.fm/live/4804/64k.mp3",
    homepage: "http://www.hj0758.cn/",
    favicon: "http://www.hj0758.cn/favicon.ico",
    tags: "music",
    country: "China",
    countrycode: "CN",
    state: "Kwangtung",
    language: "chinese",
    languagecodes: "zh",
    votes: 8519,
    codec: "MP3",
    bitrate: 0,
    hls: 0,
    lastcheckok: 1,
    clickcount: 104,
    clicktrend: 104,
  },
  {
    changeuuid: "e4a40a1a-0d47-4e85-b4e1-b0446cbada7e",
    stationuuid: "94de57d1-542a-46b8-8e18-d97517d93f99",
    id: "94de57d1-542a-46b8-8e18-d97517d93f99",
    name: "清晨音乐台",
    url: "http://lhttp.qingting.fm/live/4915/64k.mp3",
    urlResolved: "http://lhttp.qingting.fm/live/4915/64k.mp3",
    homepage: "https://m.weibo.cn/u/2022851417",
    favicon: "https://h5.sinaimg.cn/m/weibo-lite/appicon.png",
    tags: "music,pop music",
    country: "China",
    countrycode: "CN",
    state: "Kwangsi",
    language: "chinese",
    languagecodes: "zh",
    votes: 4238,
    codec: "MP3",
    bitrate: 0,
    hls: 0,
    lastcheckok: 1,
    clickcount: 38,
    clicktrend: 38,
  },
  {
    changeuuid: "22885fd3-bf3a-4ddc-9929-0a6217b6ed25",
    stationuuid: "94b627b7-7b61-4478-b797-bcb21973c4bf",
    id: "94b627b7-7b61-4478-b797-bcb21973c4bf",
    name: "AsiaFM亚洲经典台",
    url: "http://goldfm.cn:8000/goldfm",
    urlResolved: "http://goldfm.cn:8000/goldfm",
    homepage: "http://www.asiafm.net/index.php#page1",
    favicon: "http://pic.qtfm.cn/2022/0712/20220712122112.jpeg!200",
    tags: "classic hits,hd,music,oldies",
    country: "China",
    countrycode: "CN",
    state: "",
    language: "chinese",
    languagecodes: "zh",
    votes: 1832,
    codec: "AAC+",
    bitrate: 128,
    hls: 0,
    lastcheckok: 1,
    clickcount: 37,
    clicktrend: 37,
  },
];
```

- [ ] **Step 7: Run tests**

Run:

```bash
cd WebApp
npm run test -- src/features/stations/stationNormalization.test.ts
```

Expected: PASS.

- [ ] **Step 8: Commit station types and presets**

Run:

```bash
git add WebApp/src/features/stations WebApp/src/data WebApp/src/test
git commit -m "feat(web): add station model and presets"
```

---

### Task 3: Station Filtering and Search Helpers

**Files:**
- Create: `WebApp/src/features/stations/stationFilters.ts`
- Create: `WebApp/src/features/stations/stationFilters.test.ts`
- Create: `WebApp/src/features/stations/stationSearch.ts`
- Create: `WebApp/src/features/stations/stationSearch.test.ts`

- [ ] **Step 1: Write failing filtering tests**

Write `WebApp/src/features/stations/stationFilters.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { secondStationFixture, stationFixture } from "@/test/fixtures";
import {
  dedupeStationsById,
  filterMusicStations,
  pickRandomStation,
} from "./stationFilters";

describe("stationFilters", () => {
  it("keeps music-like stations by tag or name", () => {
    const newsStation = {
      ...stationFixture,
      id: "news",
      stationuuid: "news",
      name: "Daily News",
      tags: "news,talk",
    };

    const stations = filterMusicStations([
      stationFixture,
      secondStationFixture,
      newsStation,
    ]);

    expect(stations.map((station) => station.id)).toEqual([
      "station-1",
      "station-2",
    ]);
  });

  it("deduplicates by station id", () => {
    const stations = dedupeStationsById([
      stationFixture,
      { ...stationFixture, name: "Duplicate Name" },
      secondStationFixture,
    ]);

    expect(stations.map((station) => station.id)).toEqual([
      "station-1",
      "station-2",
    ]);
  });

  it("picks a station while excluding current station", () => {
    const picked = pickRandomStation(
      [stationFixture, secondStationFixture],
      "station-1",
      () => 0
    );

    expect(picked?.id).toBe("station-2");
  });
});
```

- [ ] **Step 2: Write failing search helper tests**

Write `WebApp/src/features/stations/stationSearch.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { buildSearchKeywords, stationMatchesKeywords } from "./stationSearch";

describe("stationSearch", () => {
  it("splits trimmed keywords", () => {
    expect(buildSearchKeywords("  CNR  音乐  ")).toEqual(["CNR", "音乐"]);
  });

  it("inserts a boundary between letters and digits", () => {
    expect(buildSearchKeywords("FM1017")).toEqual(["FM", "1017"]);
  });

  it("matches frequency numbers with decimal form", () => {
    expect(
      stationMatchesKeywords(
        { name: "FM 101.7 City Radio", tags: "" },
        ["1017"]
      )
    ).toBe(true);
  });

  it("requires all keywords to match", () => {
    expect(
      stationMatchesKeywords(
        { name: "CNR 音乐之声", tags: "music" },
        ["CNR", "音乐"]
      )
    ).toBe(true);

    expect(
      stationMatchesKeywords(
        { name: "CNR 音乐之声", tags: "music" },
        ["CNR", "交通"]
      )
    ).toBe(false);
  });
});
```

- [ ] **Step 3: Run tests to verify failure**

Run:

```bash
cd WebApp
npm run test -- src/features/stations/stationFilters.test.ts src/features/stations/stationSearch.test.ts
```

Expected: FAIL because helper modules do not exist.

- [ ] **Step 4: Implement station filters**

Write `WebApp/src/features/stations/stationFilters.ts`:

```ts
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
```

- [ ] **Step 5: Implement search helpers**

Write `WebApp/src/features/stations/stationSearch.ts`:

```ts
type SearchableStationFields = {
  name: string;
  tags: string;
};

export function buildSearchKeywords(input: string): string[] {
  const spaced = input.replace(/([^\d.\s])(\d)/g, "$1 $2");
  return spaced
    .trim()
    .split(/\s+/)
    .map((part) => part.trim())
    .filter(Boolean);
}

function decimalFrequency(keyword: string): string | null {
  if (!/^\d{3,4}$/.test(keyword)) return null;
  return `${keyword.slice(0, -1)}.${keyword.slice(-1)}`;
}

export function stationMatchesKeywords(
  station: SearchableStationFields,
  keywords: string[]
): boolean {
  const haystack = `${station.name} ${station.tags}`.toLowerCase();

  return keywords.every((keyword) => {
    const normalized = keyword.toLowerCase();
    if (haystack.includes(normalized)) return true;

    const frequency = decimalFrequency(normalized);
    return frequency !== null && haystack.includes(frequency);
  });
}
```

- [ ] **Step 6: Run tests**

Run:

```bash
cd WebApp
npm run test -- src/features/stations/stationFilters.test.ts src/features/stations/stationSearch.test.ts
```

Expected: PASS.

- [ ] **Step 7: Commit station helpers**

Run:

```bash
git add WebApp/src/features/stations
git commit -m "feat(web): add station filtering helpers"
```

---

### Task 4: radio-browser Server Client and Station Routes

**Files:**
- Create: `WebApp/src/server/radioBrowser.ts`
- Create: `WebApp/src/server/radioBrowser.test.ts`
- Create: `WebApp/src/app/api/stations/top/route.ts`
- Create: `WebApp/src/app/api/stations/search/route.ts`
- Create: `WebApp/src/app/api/stations/random/route.ts`

- [ ] **Step 1: Write failing server client tests**

Write `WebApp/src/server/radioBrowser.test.ts`:

```ts
import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  fetchRandomStation,
  fetchSearchStations,
  fetchTopStations,
} from "./radioBrowser";

const stationResponse = [
  {
    stationuuid: "station-1",
    name: "清晨音乐台",
    url: "http://example.com/live.mp3",
    url_resolved: "http://example.com/live.mp3",
    tags: "music",
    countrycode: "CN",
    lastcheckok: 1,
  },
];

describe("radioBrowser", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it("posts top station search payload to a mirror", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(new Response(JSON.stringify(stationResponse)));

    const stations = await fetchTopStations();

    expect(stations[0]?.id).toBe("station-1");
    expect(fetchMock).toHaveBeenCalledWith(
      "https://de1.api.radio-browser.info/json/stations/search",
      expect.objectContaining({
        method: "POST",
        headers: expect.objectContaining({
          "Content-Type": "application/json",
          "User-Agent": "RadioApp-Web/1.0",
        }),
      })
    );
  });

  it("falls back to the next mirror when the first mirror fails", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockRejectedValueOnce(new Error("network"))
      .mockResolvedValueOnce(new Response(JSON.stringify(stationResponse)));

    const stations = await fetchTopStations();

    expect(stations).toHaveLength(1);
  });

  it("returns search results filtered by all keywords", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify([
          ...stationResponse,
          {
            stationuuid: "station-2",
            name: "交通广播",
            url: "http://example.com/traffic.mp3",
            tags: "talk",
          },
        ])
      )
    );

    const stations = await fetchSearchStations("清晨 音乐");

    expect(stations.map((station) => station.name)).toEqual(["清晨音乐台"]);
  });

  it("returns null for random station when all candidates are excluded", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify(stationResponse))
    );

    const station = await fetchRandomStation("station-1");

    expect(station).toBeNull();
  });
});
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
cd WebApp
npm run test -- src/server/radioBrowser.test.ts
```

Expected: FAIL because `radioBrowser` does not exist.

- [ ] **Step 3: Implement radio-browser client**

Write `WebApp/src/server/radioBrowser.ts`:

```ts
import {
  dedupeStationsById,
  filterMusicStations,
  pickRandomStation,
} from "@/features/stations/stationFilters";
import {
  buildSearchKeywords,
  stationMatchesKeywords,
} from "@/features/stations/stationSearch";
import {
  normalizeStations,
} from "@/features/stations/stationNormalization";
import type { RadioBrowserStation, Station } from "@/features/stations/stationTypes";
import { presetStations } from "@/data/presetStations";

const MIRRORS = [
  "https://de1.api.radio-browser.info/json",
  "https://fr1.api.radio-browser.info/json",
  "https://at1.api.radio-browser.info/json",
  "https://nl1.api.radio-browser.info/json",
  "https://all.api.radio-browser.info/json",
];

type StationFilterPayload = {
  name?: string;
  countrycode?: string;
  tag?: string;
  order?: string;
  reverse?: boolean;
  limit?: number;
  offset?: number;
  hidebroken?: boolean;
};

async function postStationSearch(payload: StationFilterPayload): Promise<Station[]> {
  let lastError: unknown = null;

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
      });

      if (!response.ok) {
        throw new Error(`radio-browser ${response.status}`);
      }

      const data = (await response.json()) as RadioBrowserStation[];
      return dedupeStationsById(normalizeStations(data));
    } catch (error) {
      lastError = error;
    }
  }

  if (lastError instanceof Error) {
    throw lastError;
  }

  throw new Error("radio-browser request failed");
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

    const filtered = filterMusicStations(stations);
    return filtered.slice(0, limit);
  } catch {
    return presetStations.slice(0, limit);
  }
}

export async function fetchSearchStations(query: string): Promise<Station[]> {
  const keywords = buildSearchKeywords(query);
  if (keywords.length === 0) return [];

  const stations = await postStationSearch({
    name: keywords[0],
    limit: 500,
    hidebroken: true,
  });

  if (keywords.length === 1) {
    return stations;
  }

  const remaining = keywords.slice(1);
  const filtered = stations.filter((station) =>
    stationMatchesKeywords(station, remaining)
  );

  return filtered.length > 0 ? filtered : stations;
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
```

- [ ] **Step 4: Run server client tests**

Run:

```bash
cd WebApp
npm run test -- src/server/radioBrowser.test.ts
```

Expected: PASS.

- [ ] **Step 5: Add station route handlers**

Write `WebApp/src/app/api/stations/top/route.ts`:

```ts
import { fetchTopStations } from "@/server/radioBrowser";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const limit = Number(url.searchParams.get("limit") ?? 20);
  const stations = await fetchTopStations(Number.isFinite(limit) ? limit : 20);

  return Response.json({ stations });
}
```

Write `WebApp/src/app/api/stations/search/route.ts`:

```ts
import { fetchSearchStations } from "@/server/radioBrowser";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const query = url.searchParams.get("q")?.trim() ?? "";

  if (query.length === 0) {
    return Response.json({ stations: [] });
  }

  try {
    const stations = await fetchSearchStations(query);
    return Response.json({ stations });
  } catch {
    return Response.json(
      { error: "SEARCH_FAILED", message: "暂时无法搜索电台，请稍后再试。" },
      { status: 502 }
    );
  }
}
```

Write `WebApp/src/app/api/stations/random/route.ts`:

```ts
import { fetchRandomStation } from "@/server/radioBrowser";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const exclude = url.searchParams.get("exclude") ?? undefined;
  const station = await fetchRandomStation(exclude);

  return Response.json({ station });
}
```

- [ ] **Step 6: Run checks**

Run:

```bash
cd WebApp
npm run test
npm run lint
npm run build
```

Expected: PASS.

- [ ] **Step 7: Commit station API**

Run:

```bash
git add WebApp/src/app/api/stations WebApp/src/server WebApp/src/features/stations WebApp/src/data
git commit -m "feat(web): proxy station APIs"
```

---

### Task 5: Waitlist Schema, Supabase Repository, and API Route

**Files:**
- Create: `WebApp/supabase/migrations/0001_waitlist_submissions.sql`
- Create: `WebApp/src/features/waitlist/waitlistSchema.ts`
- Create: `WebApp/src/features/waitlist/waitlistSchema.test.ts`
- Create: `WebApp/src/lib/supabaseAdmin.ts`
- Create: `WebApp/src/server/waitlistRepository.ts`
- Create: `WebApp/src/server/waitlistRepository.test.ts`
- Create: `WebApp/src/app/api/waitlist/route.ts`

- [ ] **Step 1: Write failing waitlist schema tests**

Write `WebApp/src/features/waitlist/waitlistSchema.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { parseWaitlistRequest } from "./waitlistSchema";

describe("waitlistSchema", () => {
  it("normalizes valid email and source", () => {
    const result = parseWaitlistRequest({
      email: "  USER@Example.COM ",
      source: "recognition",
      stationId: "station-1",
      userAgent: "Mozilla",
    });

    expect(result).toEqual({
      ok: true,
      value: {
        email: "user@example.com",
        source: "recognition",
        stationId: "station-1",
        userAgent: "Mozilla",
      },
    });
  });

  it("rejects invalid email", () => {
    const result = parseWaitlistRequest({
      email: "not-email",
      source: "recognition",
    });

    expect(result).toEqual({
      ok: false,
      error: "请输入有效邮箱地址。",
    });
  });

  it("uses recognition source when source is missing", () => {
    const result = parseWaitlistRequest({
      email: "user@example.com",
    });

    expect(result).toEqual({
      ok: true,
      value: {
        email: "user@example.com",
        source: "recognition",
        stationId: null,
        userAgent: null,
      },
    });
  });
});
```

- [ ] **Step 2: Run schema tests to verify failure**

Run:

```bash
cd WebApp
npm run test -- src/features/waitlist/waitlistSchema.test.ts
```

Expected: FAIL because `waitlistSchema` does not exist.

- [ ] **Step 3: Implement waitlist schema**

Write `WebApp/src/features/waitlist/waitlistSchema.ts`:

```ts
export type WaitlistSource = "recognition" | "player" | "settings";

export type WaitlistSubmission = {
  email: string;
  source: WaitlistSource;
  stationId: string | null;
  userAgent: string | null;
};

type ParseResult =
  | { ok: true; value: WaitlistSubmission }
  | { ok: false; error: string };

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function normalizeSource(source: unknown): WaitlistSource {
  if (source === "player" || source === "settings") return source;
  return "recognition";
}

function nullableString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}

export function parseWaitlistRequest(input: unknown): ParseResult {
  const body = typeof input === "object" && input !== null ? input : {};
  const record = body as Record<string, unknown>;
  const email = typeof record.email === "string" ? record.email.trim().toLowerCase() : "";

  if (!EMAIL_PATTERN.test(email)) {
    return { ok: false, error: "请输入有效邮箱地址。" };
  }

  return {
    ok: true,
    value: {
      email,
      source: normalizeSource(record.source),
      stationId: nullableString(record.stationId),
      userAgent: nullableString(record.userAgent),
    },
  };
}
```

- [ ] **Step 4: Add Supabase migration**

Write `WebApp/supabase/migrations/0001_waitlist_submissions.sql`:

```sql
create table if not exists public.waitlist_submissions (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  source text not null,
  station_id text,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists waitlist_submissions_created_at_idx
  on public.waitlist_submissions (created_at desc);
```

- [ ] **Step 5: Write failing repository tests**

Write `WebApp/src/server/waitlistRepository.test.ts`:

```ts
import { describe, expect, it, vi } from "vitest";
import { saveWaitlistSubmission } from "./waitlistRepository";

describe("waitlistRepository", () => {
  it("upserts normalized waitlist data", async () => {
    const upsert = vi.fn().mockResolvedValue({ error: null });
    const from = vi.fn().mockReturnValue({ upsert });
    const client = { from };

    const result = await saveWaitlistSubmission(client, {
      email: "user@example.com",
      source: "recognition",
      stationId: "station-1",
      userAgent: "Mozilla",
    });

    expect(result).toEqual({ ok: true });
    expect(from).toHaveBeenCalledWith("waitlist_submissions");
    expect(upsert).toHaveBeenCalledWith(
      {
        email: "user@example.com",
        source: "recognition",
        station_id: "station-1",
        user_agent: "Mozilla",
      },
      { onConflict: "email" }
    );
  });

  it("returns a safe error when Supabase fails", async () => {
    const upsert = vi.fn().mockResolvedValue({ error: new Error("secret") });
    const from = vi.fn().mockReturnValue({ upsert });
    const client = { from };

    const result = await saveWaitlistSubmission(client, {
      email: "user@example.com",
      source: "recognition",
      stationId: null,
      userAgent: null,
    });

    expect(result).toEqual({
      ok: false,
      error: "暂时无法加入等待名单，请稍后再试。",
    });
  });
});
```

- [ ] **Step 6: Implement Supabase admin and repository**

Write `WebApp/src/lib/supabaseAdmin.ts`:

```ts
import { createClient } from "@supabase/supabase-js";

export function createSupabaseAdminClient() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SECRET_KEY;

  if (!url || !key) {
    throw new Error("Missing Supabase server environment variables");
  }

  return createClient(url, key, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}
```

Write `WebApp/src/server/waitlistRepository.ts`:

```ts
import type { WaitlistSubmission } from "@/features/waitlist/waitlistSchema";

type SupabaseLikeClient = {
  from: (table: string) => {
    upsert: (
      values: Record<string, string | null>,
      options: { onConflict: string }
    ) => Promise<{ error: unknown }>;
  };
};

type SaveResult =
  | { ok: true }
  | { ok: false; error: "暂时无法加入等待名单，请稍后再试。" };

export async function saveWaitlistSubmission(
  client: SupabaseLikeClient,
  submission: WaitlistSubmission
): Promise<SaveResult> {
  const { error } = await client.from("waitlist_submissions").upsert(
    {
      email: submission.email,
      source: submission.source,
      station_id: submission.stationId,
      user_agent: submission.userAgent,
    },
    { onConflict: "email" }
  );

  if (error) {
    return { ok: false, error: "暂时无法加入等待名单，请稍后再试。" };
  }

  return { ok: true };
}
```

- [ ] **Step 7: Add waitlist route**

Write `WebApp/src/app/api/waitlist/route.ts`:

```ts
import { parseWaitlistRequest } from "@/features/waitlist/waitlistSchema";
import { createSupabaseAdminClient } from "@/lib/supabaseAdmin";
import { saveWaitlistSubmission } from "@/server/waitlistRepository";

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const parsed = parseWaitlistRequest(body);

  if (!parsed.ok) {
    return Response.json({ error: parsed.error }, { status: 400 });
  }

  const client = createSupabaseAdminClient();
  const result = await saveWaitlistSubmission(client, parsed.value);

  if (!result.ok) {
    return Response.json({ error: result.error }, { status: 502 });
  }

  return Response.json({ ok: true });
}
```

- [ ] **Step 8: Run tests**

Run:

```bash
cd WebApp
npm run test -- src/features/waitlist/waitlistSchema.test.ts src/server/waitlistRepository.test.ts
npm run lint
npm run build
```

Expected: PASS.

- [ ] **Step 9: Commit waitlist API**

Run:

```bash
git add WebApp/src/features/waitlist WebApp/src/server/waitlistRepository.ts WebApp/src/server/waitlistRepository.test.ts WebApp/src/lib/supabaseAdmin.ts WebApp/src/app/api/waitlist WebApp/supabase
git commit -m "feat(web): add macOS waitlist API"
```

---

### Task 6: Web Visual System Foundation

**Files:**
- Modify: `WebApp/src/app/globals.css`
- Modify: `WebApp/src/app/layout.tsx`
- Create: `WebApp/src/components/AnimatedMeshBackground.tsx`
- Create: `WebApp/src/components/GlassCard.tsx`
- Create: `WebApp/src/components/IconButton.tsx`
- Create: `WebApp/src/components/StationAvatar.tsx`
- Create: `WebApp/src/components/StationAvatar.test.tsx`
- Create: `WebApp/src/components/EmptyState.tsx`

- [ ] **Step 1: Write failing avatar tests**

Write `WebApp/src/components/StationAvatar.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { StationAvatar } from "./StationAvatar";

describe("StationAvatar", () => {
  it("renders a remote image when favicon exists", () => {
    render(
      <StationAvatar
        name="清晨音乐台"
        stationId="station-1"
        favicon="https://example.com/favicon.png"
      />
    );

    expect(screen.getByAltText("清晨音乐台")).toHaveAttribute(
      "src",
      "https://example.com/favicon.png"
    );
  });

  it("renders branded initials when favicon is empty", () => {
    render(
      <StationAvatar name="清晨音乐台" stationId="station-1" favicon="" />
    );

    expect(screen.getByText("清")).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run avatar tests to verify failure**

Run:

```bash
cd WebApp
npm run test -- src/components/StationAvatar.test.tsx
```

Expected: FAIL because `StationAvatar` does not exist.

- [ ] **Step 3: Replace global CSS with RadioApp tokens**

Write `WebApp/src/app/globals.css`:

```css
@import "tailwindcss";

:root {
  --neon-cyan: #00d9ff;
  --neon-magenta: #ff006e;
  --neon-purple: #8338ec;
  --neon-electric: #7b2cbf;
  --neon-warm-pink: #ff5e78;
  --neon-mint: #00f5d4;
  --neon-gold: #ffd23f;
  --neon-red: #ff3b30;
  --neon-dark-bg: #0a0a0f;
  --neon-card-bg: #151520;
  --neon-surface-bg: #1a1a2e;
  --text-primary: #ffffff;
  --text-secondary: rgba(255, 255, 255, 0.68);
}

* {
  box-sizing: border-box;
}

html,
body {
  min-height: 100%;
  background: var(--neon-dark-bg);
  color: var(--text-primary);
}

body {
  margin: 0;
  overflow-x: hidden;
}

button,
input {
  font: inherit;
}

.neon-glow-cyan {
  box-shadow:
    0 0 8px rgba(0, 217, 255, 0.6),
    0 0 18px rgba(0, 217, 255, 0.35);
}

.neon-glow-magenta {
  box-shadow:
    0 0 10px rgba(255, 0, 110, 0.6),
    0 0 22px rgba(255, 0, 110, 0.35);
}
```

- [ ] **Step 4: Update metadata and layout shell**

Write `WebApp/src/app/layout.tsx`:

```tsx
import type { Metadata } from "next";
import type { ReactNode } from "react";
import "./globals.css";

export const metadata: Metadata = {
  title: "拾音 FM",
  description: "打开浏览器，收听全球电台。",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: ReactNode;
}>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
```

- [ ] **Step 5: Add visual primitives**

Write `WebApp/src/components/AnimatedMeshBackground.tsx`:

```tsx
export function AnimatedMeshBackground() {
  return (
    <div aria-hidden="true" className="fixed inset-0 -z-10 overflow-hidden bg-[var(--neon-dark-bg)]">
      <div className="absolute -left-36 -top-48 h-[34rem] w-[34rem] rounded-full bg-[radial-gradient(circle,var(--neon-purple)_0%,transparent_62%)] opacity-40 blur-3xl" />
      <div className="absolute -bottom-44 right-[-8rem] h-[32rem] w-[32rem] rounded-full bg-[radial-gradient(circle,var(--neon-cyan)_0%,transparent_62%)] opacity-30 blur-3xl" />
      <div className="absolute right-10 top-24 h-80 w-80 rounded-full bg-[radial-gradient(circle,var(--neon-magenta)_0%,transparent_62%)] opacity-20 blur-3xl" />
      <div className="absolute inset-0 opacity-[0.03] [background-image:radial-gradient(circle,white_1px,transparent_1px)] [background-size:18px_18px]" />
    </div>
  );
}
```

Write `WebApp/src/components/GlassCard.tsx`:

```tsx
import clsx from "clsx";
import type { ReactNode } from "react";

type GlassCardProps = {
  children: ReactNode;
  className?: string;
  active?: boolean;
};

export function GlassCard({ children, className, active = false }: GlassCardProps) {
  return (
    <div
      className={clsx(
        "rounded-2xl border bg-[rgba(21,21,32,0.72)] backdrop-blur-xl",
        active
          ? "border-[rgba(0,217,255,0.72)] neon-glow-cyan"
          : "border-[rgba(255,255,255,0.12)]",
        className
      )}
    >
      {children}
    </div>
  );
}
```

Write `WebApp/src/components/IconButton.tsx`:

```tsx
import clsx from "clsx";
import type { ButtonHTMLAttributes, ReactNode } from "react";

type IconButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  label: string;
  active?: boolean;
  children: ReactNode;
};

export function IconButton({
  label,
  active = false,
  children,
  className,
  ...props
}: IconButtonProps) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      className={clsx(
        "grid h-11 w-11 place-items-center rounded-full border transition active:scale-95",
        active
          ? "border-[rgba(0,217,255,0.7)] bg-[rgba(0,217,255,0.16)] text-[var(--neon-cyan)] neon-glow-cyan"
          : "border-[rgba(255,255,255,0.12)] bg-white/10 text-white/75 hover:text-[var(--neon-cyan)]",
        className
      )}
      {...props}
    >
      {children}
    </button>
  );
}
```

Write `WebApp/src/components/StationAvatar.tsx`:

```tsx
/* eslint-disable @next/next/no-img-element */

type StationAvatarProps = {
  name: string;
  stationId: string;
  favicon: string;
  sizeClassName?: string;
};

export function StationAvatar({
  name,
  stationId,
  favicon,
  sizeClassName = "h-16 w-16",
}: StationAvatarProps) {
  const initial = name.trim().slice(0, 1) || "F";

  if (favicon && !favicon.startsWith("bundle://")) {
    return (
      <img
        src={favicon}
        alt={name}
        className={`${sizeClassName} rounded-2xl object-cover bg-[var(--neon-card-bg)]`}
      />
    );
  }

  return (
    <div
      data-station-id={stationId}
      className={`${sizeClassName} grid place-items-center rounded-2xl bg-[linear-gradient(135deg,var(--neon-cyan),var(--neon-purple),var(--neon-magenta))] text-xl font-black text-white shadow-lg`}
    >
      {initial}
    </div>
  );
}
```

Write `WebApp/src/components/EmptyState.tsx`:

```tsx
type EmptyStateProps = {
  title: string;
  description: string;
};

export function EmptyState({ title, description }: EmptyStateProps) {
  return (
    <div className="rounded-2xl border border-white/10 bg-white/[0.04] px-5 py-8 text-center">
      <h3 className="text-lg font-bold text-white">{title}</h3>
      <p className="mt-2 text-sm leading-6 text-white/60">{description}</p>
    </div>
  );
}
```

- [ ] **Step 6: Run visual primitive tests**

Run:

```bash
cd WebApp
npm run test -- src/components/StationAvatar.test.tsx
npm run lint
```

Expected: PASS.

- [ ] **Step 7: Commit visual foundation**

Run:

```bash
git add WebApp/src/app WebApp/src/components
git commit -m "feat(web): add neon design primitives"
```

---

### Task 7: Local Persistence Hooks

**Files:**
- Create: `WebApp/src/lib/localJsonStorage.ts`
- Create: `WebApp/src/lib/localJsonStorage.test.ts`
- Create: `WebApp/src/hooks/useLocalStations.ts`
- Create: `WebApp/src/hooks/useLocalStations.test.tsx`

- [ ] **Step 1: Write failing local storage tests**

Write `WebApp/src/lib/localJsonStorage.test.ts`:

```ts
import { beforeEach, describe, expect, it } from "vitest";
import { readJson, writeJson } from "./localJsonStorage";

describe("localJsonStorage", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("returns fallback when key is missing", () => {
    expect(readJson("missing", ["fallback"])).toEqual(["fallback"]);
  });

  it("writes and reads JSON", () => {
    writeJson("items", [{ id: "one" }]);
    expect(readJson("items", [])).toEqual([{ id: "one" }]);
  });

  it("returns fallback for invalid JSON", () => {
    window.localStorage.setItem("broken", "{");
    expect(readJson("broken", [])).toEqual([]);
  });
});
```

Write `WebApp/src/hooks/useLocalStations.test.tsx`:

```tsx
import { act, renderHook } from "@testing-library/react";
import { beforeEach, describe, expect, it } from "vitest";
import { stationFixture } from "@/test/fixtures";
import { useLocalStations } from "./useLocalStations";

describe("useLocalStations", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("adds and removes favorite stations", () => {
    const { result } = renderHook(() =>
      useLocalStations("radioapp:web:favorites", 30)
    );

    act(() => result.current.addStation(stationFixture));
    expect(result.current.stations).toEqual([stationFixture]);
    expect(result.current.hasStation(stationFixture.id)).toBe(true);

    act(() => result.current.removeStation(stationFixture.id));
    expect(result.current.stations).toEqual([]);
  });

  it("keeps the newest station at the front and caps length", () => {
    const { result } = renderHook(() =>
      useLocalStations("radioapp:web:recent", 1)
    );

    act(() => result.current.addStation(stationFixture));
    act(() =>
      result.current.addStation({
        ...stationFixture,
        id: "station-2",
        stationuuid: "station-2",
        name: "Second",
      })
    );

    expect(result.current.stations.map((station) => station.id)).toEqual([
      "station-2",
    ]);
  });
});
```

- [ ] **Step 2: Run local storage tests to verify failure**

Run:

```bash
cd WebApp
npm run test -- src/lib/localJsonStorage.test.ts src/hooks/useLocalStations.test.tsx
```

Expected: FAIL because modules do not exist.

- [ ] **Step 3: Implement local JSON storage**

Write `WebApp/src/lib/localJsonStorage.ts`:

```ts
export function readJson<T>(key: string, fallback: T): T {
  if (typeof window === "undefined") return fallback;

  try {
    const raw = window.localStorage.getItem(key);
    if (raw === null) return fallback;
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

export function writeJson<T>(key: string, value: T): void {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(key, JSON.stringify(value));
}
```

- [ ] **Step 4: Implement station persistence hook**

Write `WebApp/src/hooks/useLocalStations.ts`:

```ts
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

export function useLocalStations(key: string, limit: number): LocalStationsState {
  const [stations, setStations] = useState<Station[]>([]);

  useEffect(() => {
    setStations(readJson<Station[]>(key, []));
  }, [key]);

  useEffect(() => {
    writeJson(key, stations);
  }, [key, stations]);

  return useMemo(
    () => ({
      stations,
      addStation: (station: Station) => {
        setStations((current) => {
          const withoutDuplicate = current.filter((item) => item.id !== station.id);
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
```

- [ ] **Step 5: Run local persistence tests**

Run:

```bash
cd WebApp
npm run test -- src/lib/localJsonStorage.test.ts src/hooks/useLocalStations.test.tsx
```

Expected: PASS.

- [ ] **Step 6: Commit local persistence**

Run:

```bash
git add WebApp/src/lib/localJsonStorage.ts WebApp/src/lib/localJsonStorage.test.ts WebApp/src/hooks
git commit -m "feat(web): persist local stations"
```

---

### Task 8: Audio Player Context and Controls

**Files:**
- Create: `WebApp/src/features/player/audioPlayerTypes.ts`
- Create: `WebApp/src/features/player/audioPlayerReducer.ts`
- Create: `WebApp/src/features/player/audioPlayerReducer.test.ts`
- Create: `WebApp/src/features/player/AudioPlayerProvider.tsx`
- Create: `WebApp/src/components/MiniPlayer.tsx`
- Create: `WebApp/src/components/PlayerPanel.tsx`

- [ ] **Step 1: Write failing reducer tests**

Write `WebApp/src/features/player/audioPlayerReducer.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { stationFixture, secondStationFixture } from "@/test/fixtures";
import { audioPlayerReducer, initialAudioPlayerState } from "./audioPlayerReducer";

describe("audioPlayerReducer", () => {
  it("starts a station with playlist context", () => {
    const state = audioPlayerReducer(initialAudioPlayerState, {
      type: "playStation",
      station: stationFixture,
      playlist: [stationFixture, secondStationFixture],
      playlistTitle: "发现",
    });

    expect(state.currentStation?.id).toBe("station-1");
    expect(state.playlistTitle).toBe("发现");
    expect(state.isLoading).toBe(true);
    expect(state.playbackError).toBeNull();
  });

  it("moves to next and previous stations", () => {
    const playing = audioPlayerReducer(initialAudioPlayerState, {
      type: "playStation",
      station: stationFixture,
      playlist: [stationFixture, secondStationFixture],
      playlistTitle: "发现",
    });

    const next = audioPlayerReducer(playing, { type: "next" });
    expect(next.currentStation?.id).toBe("station-2");

    const previous = audioPlayerReducer(next, { type: "previous" });
    expect(previous.currentStation?.id).toBe("station-1");
  });

  it("stores playback error without clearing station", () => {
    const playing = audioPlayerReducer(initialAudioPlayerState, {
      type: "playStation",
      station: stationFixture,
      playlist: [stationFixture],
      playlistTitle: "发现",
    });

    const failed = audioPlayerReducer(playing, {
      type: "playbackError",
      message: "该电台暂不支持浏览器播放。",
    });

    expect(failed.currentStation?.id).toBe("station-1");
    expect(failed.isPlaying).toBe(false);
    expect(failed.playbackError).toBe("该电台暂不支持浏览器播放。");
  });
});
```

- [ ] **Step 2: Run reducer tests to verify failure**

Run:

```bash
cd WebApp
npm run test -- src/features/player/audioPlayerReducer.test.ts
```

Expected: FAIL because player modules do not exist.

- [ ] **Step 3: Add player types and reducer**

Write `WebApp/src/features/player/audioPlayerTypes.ts`:

```ts
import type { Station } from "@/features/stations/stationTypes";

export type AudioPlayerState = {
  currentStation: Station | null;
  playlist: Station[];
  playlistTitle: string;
  isPlaying: boolean;
  isLoading: boolean;
  playbackError: string | null;
  volume: number;
  isExpanded: boolean;
};

export type AudioPlayerAction =
  | {
      type: "playStation";
      station: Station;
      playlist: Station[];
      playlistTitle: string;
    }
  | { type: "playbackStarted" }
  | { type: "pause" }
  | { type: "playbackError"; message: string }
  | { type: "next" }
  | { type: "previous" }
  | { type: "setVolume"; volume: number }
  | { type: "setExpanded"; expanded: boolean };
```

Write `WebApp/src/features/player/audioPlayerReducer.ts`:

```ts
import type { AudioPlayerAction, AudioPlayerState } from "./audioPlayerTypes";

export const initialAudioPlayerState: AudioPlayerState = {
  currentStation: null,
  playlist: [],
  playlistTitle: "播放列表",
  isPlaying: false,
  isLoading: false,
  playbackError: null,
  volume: 0.5,
  isExpanded: false,
};

function currentIndex(state: AudioPlayerState): number {
  if (!state.currentStation) return -1;
  return state.playlist.findIndex((station) => station.id === state.currentStation?.id);
}

export function audioPlayerReducer(
  state: AudioPlayerState,
  action: AudioPlayerAction
): AudioPlayerState {
  switch (action.type) {
    case "playStation":
      return {
        ...state,
        currentStation: action.station,
        playlist: action.playlist,
        playlistTitle: action.playlistTitle,
        isLoading: true,
        isPlaying: false,
        playbackError: null,
      };
    case "playbackStarted":
      return { ...state, isLoading: false, isPlaying: true, playbackError: null };
    case "pause":
      return { ...state, isPlaying: false, isLoading: false };
    case "playbackError":
      return {
        ...state,
        isPlaying: false,
        isLoading: false,
        playbackError: action.message,
      };
    case "next": {
      const index = currentIndex(state);
      if (index < 0 || state.playlist.length === 0) return state;
      const station = state.playlist[(index + 1) % state.playlist.length];
      return station
        ? { ...state, currentStation: station, isLoading: true, playbackError: null }
        : state;
    }
    case "previous": {
      const index = currentIndex(state);
      if (index < 0 || state.playlist.length === 0) return state;
      const station =
        state.playlist[(index - 1 + state.playlist.length) % state.playlist.length];
      return station
        ? { ...state, currentStation: station, isLoading: true, playbackError: null }
        : state;
    }
    case "setVolume":
      return { ...state, volume: Math.min(1, Math.max(0, action.volume)) };
    case "setExpanded":
      return { ...state, isExpanded: action.expanded };
    default:
      return state;
  }
}
```

- [ ] **Step 4: Add player provider**

Write `WebApp/src/features/player/AudioPlayerProvider.tsx`:

```tsx
"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useReducer,
  useRef,
  type ReactNode,
} from "react";
import type { Station } from "@/features/stations/stationTypes";
import { readJson, writeJson } from "@/lib/localJsonStorage";
import { audioPlayerReducer, initialAudioPlayerState } from "./audioPlayerReducer";
import type { AudioPlayerState } from "./audioPlayerTypes";

type AudioPlayerContextValue = {
  state: AudioPlayerState;
  playStation: (station: Station, playlist: Station[], playlistTitle: string) => void;
  togglePlayPause: () => void;
  next: () => void;
  previous: () => void;
  setVolume: (volume: number) => void;
  setExpanded: (expanded: boolean) => void;
};

const AudioPlayerContext = createContext<AudioPlayerContextValue | null>(null);

export function AudioPlayerProvider({
  children,
  onPlayedStation,
}: {
  children: ReactNode;
  onPlayedStation?: (station: Station) => void;
}) {
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const [state, dispatch] = useReducer(audioPlayerReducer, {
    ...initialAudioPlayerState,
    volume: readJson<number>("radioapp:web:volume", 0.5),
  });

  useEffect(() => {
    audioRef.current = new Audio();
    audioRef.current.volume = state.volume;
    return () => {
      audioRef.current?.pause();
      audioRef.current = null;
    };
  }, []);

  useEffect(() => {
    if (!audioRef.current || !state.currentStation) return;

    const audio = audioRef.current;
    audio.src = state.currentStation.urlResolved || state.currentStation.url;
    audio.volume = state.volume;

    const onPlaying = () => {
      dispatch({ type: "playbackStarted" });
      if (state.currentStation) onPlayedStation?.(state.currentStation);
    };
    const onError = () => {
      dispatch({
        type: "playbackError",
        message: "该电台暂不支持浏览器播放。",
      });
    };

    audio.addEventListener("playing", onPlaying);
    audio.addEventListener("error", onError);
    void audio.play().catch(() => onError());

    return () => {
      audio.removeEventListener("playing", onPlaying);
      audio.removeEventListener("error", onError);
    };
  }, [onPlayedStation, state.currentStation, state.volume]);

  useEffect(() => {
    if (audioRef.current) audioRef.current.volume = state.volume;
    writeJson("radioapp:web:volume", state.volume);
  }, [state.volume]);

  const playStation = useCallback(
    (station: Station, playlist: Station[], playlistTitle: string) => {
      dispatch({ type: "playStation", station, playlist, playlistTitle });
    },
    []
  );

  const togglePlayPause = useCallback(() => {
    const audio = audioRef.current;
    if (!audio || !state.currentStation) return;

    if (state.isPlaying) {
      audio.pause();
      dispatch({ type: "pause" });
    } else {
      void audio.play().catch(() =>
        dispatch({
          type: "playbackError",
          message: "该电台暂不支持浏览器播放。",
        })
      );
    }
  }, [state.currentStation, state.isPlaying]);

  const value = useMemo<AudioPlayerContextValue>(
    () => ({
      state,
      playStation,
      togglePlayPause,
      next: () => dispatch({ type: "next" }),
      previous: () => dispatch({ type: "previous" }),
      setVolume: (volume: number) => dispatch({ type: "setVolume", volume }),
      setExpanded: (expanded: boolean) =>
        dispatch({ type: "setExpanded", expanded }),
    }),
    [playStation, state, togglePlayPause]
  );

  return (
    <AudioPlayerContext.Provider value={value}>
      {children}
    </AudioPlayerContext.Provider>
  );
}

export function useAudioPlayer() {
  const value = useContext(AudioPlayerContext);
  if (!value) {
    throw new Error("useAudioPlayer must be used inside AudioPlayerProvider");
  }
  return value;
}
```

- [ ] **Step 5: Add MiniPlayer and PlayerPanel**

Write `WebApp/src/components/MiniPlayer.tsx`:

```tsx
"use client";

import { Pause, Play } from "lucide-react";
import { StationAvatar } from "./StationAvatar";
import { useAudioPlayer } from "@/features/player/AudioPlayerProvider";

export function MiniPlayer() {
  const { state, togglePlayPause, setExpanded } = useAudioPlayer();

  if (!state.currentStation) return null;

  return (
    <div className="fixed inset-x-4 bottom-4 z-40 mx-auto max-w-2xl rounded-3xl border border-[rgba(0,217,255,0.35)] bg-[rgba(12,14,24,0.94)] p-3 backdrop-blur-xl neon-glow-cyan">
      <div className="flex items-center gap-3">
        <button
          type="button"
          className="flex min-w-0 flex-1 items-center gap-3 text-left"
          onClick={() => setExpanded(true)}
        >
          <StationAvatar
            name={state.currentStation.name}
            stationId={state.currentStation.id}
            favicon={state.currentStation.favicon}
            sizeClassName="h-12 w-12"
          />
          <div className="min-w-0">
            <p className="truncate text-sm font-bold text-white">
              {state.currentStation.name}
            </p>
            <p className="truncate text-xs text-[var(--neon-cyan)]">
              {state.playbackError ?? state.playlistTitle}
            </p>
          </div>
        </button>
        <button
          type="button"
          aria-label={state.isPlaying ? "暂停" : "播放"}
          onClick={togglePlayPause}
          className="grid h-12 w-12 place-items-center rounded-full bg-[linear-gradient(135deg,var(--neon-magenta),var(--neon-purple))] text-white neon-glow-magenta"
        >
          {state.isPlaying ? <Pause size={20} /> : <Play size={20} />}
        </button>
      </div>
    </div>
  );
}
```

Write `WebApp/src/components/PlayerPanel.tsx`:

```tsx
"use client";

import { Heart, Pause, Play, RotateCcw, SkipBack, SkipForward, Sparkles, X } from "lucide-react";
import { StationAvatar } from "./StationAvatar";
import { IconButton } from "./IconButton";
import { useAudioPlayer } from "@/features/player/AudioPlayerProvider";
import type { Station } from "@/features/stations/stationTypes";

type PlayerPanelProps = {
  isFavorite: boolean;
  onToggleFavorite: (station: Station) => void;
  onOpenWaitlist: () => void;
};

export function PlayerPanel({
  isFavorite,
  onToggleFavorite,
  onOpenWaitlist,
}: PlayerPanelProps) {
  const {
    state,
    togglePlayPause,
    previous,
    next,
    setVolume,
    setExpanded,
    playStation,
  } = useAudioPlayer();

  if (!state.isExpanded || !state.currentStation) return null;

  return (
    <div className="fixed inset-0 z-50 bg-[rgba(10,10,15,0.94)] p-5 backdrop-blur-2xl">
      <div className="mx-auto flex h-full max-w-3xl flex-col">
        <div className="flex justify-end">
          <IconButton label="关闭播放器" onClick={() => setExpanded(false)}>
            <X size={20} />
          </IconButton>
        </div>

        <div className="flex flex-1 flex-col items-center justify-center gap-6 text-center">
          <StationAvatar
            name={state.currentStation.name}
            stationId={state.currentStation.id}
            favicon={state.currentStation.favicon}
            sizeClassName="h-44 w-44"
          />
          <div>
            <h2 className="text-3xl font-black text-white">
              {state.currentStation.name}
            </h2>
            <p className="mt-2 text-sm text-[var(--neon-cyan)]">
              {state.currentStation.tags || state.currentStation.country}
            </p>
            {state.playbackError ? (
              <p className="mt-3 rounded-full border border-[rgba(255,59,48,0.35)] bg-[rgba(255,59,48,0.12)] px-4 py-2 text-sm text-white/80">
                {state.playbackError}
              </p>
            ) : null}
          </div>

          <div className="flex items-center gap-4">
            <IconButton label="上一台" onClick={previous}>
              <SkipBack size={20} />
            </IconButton>
            <button
              type="button"
              aria-label={state.isPlaying ? "暂停" : "播放"}
              onClick={togglePlayPause}
              className="grid h-20 w-20 place-items-center rounded-full bg-[linear-gradient(135deg,var(--neon-magenta),var(--neon-purple))] text-white neon-glow-magenta active:scale-95"
            >
              {state.isPlaying ? <Pause size={30} /> : <Play size={30} />}
            </button>
            <IconButton label="下一台" onClick={next}>
              <SkipForward size={20} />
            </IconButton>
          </div>

          <div className="flex items-center gap-3">
            <IconButton
              label={isFavorite ? "取消收藏" : "收藏"}
              active={isFavorite}
              onClick={() => onToggleFavorite(state.currentStation!)}
            >
              <Heart size={20} fill={isFavorite ? "currentColor" : "none"} />
            </IconButton>
            <IconButton
              label="重试播放"
              onClick={() =>
                playStation(state.currentStation!, state.playlist, state.playlistTitle)
              }
            >
              <RotateCcw size={20} />
            </IconButton>
            <IconButton label="识别歌曲" onClick={onOpenWaitlist}>
              <Sparkles size={20} />
            </IconButton>
          </div>

          <label className="flex w-full max-w-xs items-center gap-3 text-sm text-white/60">
            音量
            <input
              aria-label="音量"
              type="range"
              min="0"
              max="1"
              step="0.01"
              value={state.volume}
              onChange={(event) => setVolume(Number(event.target.value))}
              className="w-full accent-[var(--neon-cyan)]"
            />
          </label>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 6: Run player tests**

Run:

```bash
cd WebApp
npm run test -- src/features/player/audioPlayerReducer.test.ts
npm run lint
npm run build
```

Expected: PASS.

- [ ] **Step 7: Commit player state**

Run:

```bash
git add WebApp/src/features/player WebApp/src/components/MiniPlayer.tsx WebApp/src/components/PlayerPanel.tsx
git commit -m "feat(web): add audio player state"
```

---

### Task 9: Station Data Hooks and Cards

**Files:**
- Create: `WebApp/src/lib/stationApi.ts`
- Create: `WebApp/src/hooks/useStations.ts`
- Create: `WebApp/src/components/StationCard.tsx`
- Create: `WebApp/src/components/StationCard.test.tsx`
- Create: `WebApp/src/components/StationGrid.tsx`

- [ ] **Step 1: Write failing StationCard test**

Write `WebApp/src/components/StationCard.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { stationFixture } from "@/test/fixtures";
import { StationCard } from "./StationCard";

describe("StationCard", () => {
  it("renders station metadata and starts playback", async () => {
    const onPlay = vi.fn();
    const user = userEvent.setup();

    render(
      <StationCard
        station={stationFixture}
        isPlaying={false}
        isFavorite={false}
        onPlay={onPlay}
        onToggleFavorite={vi.fn()}
      />
    );

    expect(screen.getByText("清晨音乐台")).toBeInTheDocument();
    expect(screen.getByText("music,pop music")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "播放 清晨音乐台" }));
    expect(onPlay).toHaveBeenCalledWith(stationFixture);
  });

  it("toggles favorite without starting playback", async () => {
    const onPlay = vi.fn();
    const onToggleFavorite = vi.fn();
    const user = userEvent.setup();

    render(
      <StationCard
        station={stationFixture}
        isPlaying={false}
        isFavorite={false}
        onPlay={onPlay}
        onToggleFavorite={onToggleFavorite}
      />
    );

    await user.click(screen.getByRole("button", { name: "收藏 清晨音乐台" }));
    expect(onToggleFavorite).toHaveBeenCalledWith(stationFixture);
    expect(onPlay).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run StationCard test to verify failure**

Run:

```bash
cd WebApp
npm run test -- src/components/StationCard.test.tsx
```

Expected: FAIL because `StationCard` does not exist.

- [ ] **Step 3: Add station API fetcher and SWR hooks**

Write `WebApp/src/lib/stationApi.ts`:

```ts
import type { Station } from "@/features/stations/stationTypes";

type StationsResponse = { stations: Station[] };
type RandomStationResponse = { station: Station | null };

async function fetchJson<T>(url: string): Promise<T> {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Request failed: ${response.status}`);
  return (await response.json()) as T;
}

export async function getTopStations(): Promise<Station[]> {
  const data = await fetchJson<StationsResponse>("/api/stations/top");
  return data.stations;
}

export async function searchStations(query: string): Promise<Station[]> {
  if (query.trim().length === 0) return [];
  const data = await fetchJson<StationsResponse>(
    `/api/stations/search?q=${encodeURIComponent(query)}`
  );
  return data.stations;
}

export async function getRandomStation(exclude?: string): Promise<Station | null> {
  const suffix = exclude ? `?exclude=${encodeURIComponent(exclude)}` : "";
  const data = await fetchJson<RandomStationResponse>(
    `/api/stations/random${suffix}`
  );
  return data.station;
}
```

Write `WebApp/src/hooks/useStations.ts`:

```ts
"use client";

import useSWR from "swr";
import { getTopStations, searchStations } from "@/lib/stationApi";

export function useTopStations() {
  return useSWR("stations:top", getTopStations);
}

export function useStationSearch(query: string) {
  return useSWR(
    query.trim().length > 0 ? ["stations:search", query] : null,
    ([, value]) => searchStations(value)
  );
}
```

- [ ] **Step 4: Implement StationCard and StationGrid**

Write `WebApp/src/components/StationCard.tsx`:

```tsx
"use client";

import { Heart, Play } from "lucide-react";
import type { Station } from "@/features/stations/stationTypes";
import { GlassCard } from "./GlassCard";
import { IconButton } from "./IconButton";
import { StationAvatar } from "./StationAvatar";

type StationCardProps = {
  station: Station;
  isPlaying: boolean;
  isFavorite: boolean;
  onPlay: (station: Station) => void;
  onToggleFavorite: (station: Station) => void;
};

export function StationCard({
  station,
  isPlaying,
  isFavorite,
  onPlay,
  onToggleFavorite,
}: StationCardProps) {
  return (
    <GlassCard active={isPlaying} className="p-3">
      <div className="flex gap-3">
        <button
          type="button"
          aria-label={`播放 ${station.name}`}
          className="min-w-0 flex flex-1 gap-3 text-left"
          onClick={() => onPlay(station)}
        >
          <StationAvatar
            name={station.name}
            stationId={station.id}
            favicon={station.favicon}
            sizeClassName="h-16 w-16"
          />
          <span className="min-w-0 flex-1">
            <span className="block truncate font-bold text-white">{station.name}</span>
            <span className="mt-1 block truncate text-xs text-[var(--neon-cyan)]">
              {station.tags || station.country || "Radio"}
            </span>
            <span className="mt-2 inline-flex items-center gap-1 text-xs text-white/50">
              <Play size={12} />
              {station.codec || "STREAM"}
            </span>
          </span>
        </button>
        <IconButton
          label={`${isFavorite ? "取消收藏" : "收藏"} ${station.name}`}
          active={isFavorite}
          onClick={() => onToggleFavorite(station)}
        >
          <Heart size={18} fill={isFavorite ? "currentColor" : "none"} />
        </IconButton>
      </div>
    </GlassCard>
  );
}
```

Write `WebApp/src/components/StationGrid.tsx`:

```tsx
"use client";

import type { Station } from "@/features/stations/stationTypes";
import { StationCard } from "./StationCard";

type StationGridProps = {
  stations: Station[];
  currentStationId?: string;
  favoriteIds: Set<string>;
  playlistTitle: string;
  onPlayStation: (station: Station, playlist: Station[], playlistTitle: string) => void;
  onToggleFavorite: (station: Station) => void;
};

export function StationGrid({
  stations,
  currentStationId,
  favoriteIds,
  playlistTitle,
  onPlayStation,
  onToggleFavorite,
}: StationGridProps) {
  return (
    <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
      {stations.map((station) => (
        <StationCard
          key={station.id}
          station={station}
          isPlaying={station.id === currentStationId}
          isFavorite={favoriteIds.has(station.id)}
          onPlay={() => onPlayStation(station, stations, playlistTitle)}
          onToggleFavorite={onToggleFavorite}
        />
      ))}
    </div>
  );
}
```

- [ ] **Step 5: Run component tests**

Run:

```bash
cd WebApp
npm run test -- src/components/StationCard.test.tsx
npm run lint
```

Expected: PASS.

- [ ] **Step 6: Commit station UI primitives**

Run:

```bash
git add WebApp/src/lib/stationApi.ts WebApp/src/hooks/useStations.ts WebApp/src/components/StationCard.tsx WebApp/src/components/StationCard.test.tsx WebApp/src/components/StationGrid.tsx
git commit -m "feat(web): add station cards"
```

---

### Task 10: Main Web App Experience

**Files:**
- Modify: `WebApp/src/app/page.tsx`
- Create: `WebApp/src/app/page.test.tsx`

- [ ] **Step 1: Write failing page smoke test**

Write `WebApp/src/app/page.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import Home from "./page";

vi.mock("@/hooks/useStations", () => ({
  useTopStations: () => ({
    data: [],
    error: null,
    isLoading: false,
    mutate: vi.fn(),
  }),
  useStationSearch: () => ({
    data: [],
    error: null,
    isLoading: false,
  }),
}));

describe("Home page", () => {
  it("renders the RadioApp web shell", () => {
    render(<Home />);

    expect(screen.getByText("发现")).toBeInTheDocument();
    expect(screen.getByText("探索全球电台")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "发现" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "搜索" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "收藏" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "最近" })).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run page test to verify failure**

Run:

```bash
cd WebApp
npm run test -- src/app/page.test.tsx
```

Expected: FAIL until page is replaced with the RadioApp shell.

- [ ] **Step 3: Implement page**

Write `WebApp/src/app/page.tsx`:

```tsx
"use client";

import { Clock3, Heart, History, Loader2, Radio, Search, Shuffle, Sparkles } from "lucide-react";
import { useMemo, useState } from "react";
import { AnimatedMeshBackground } from "@/components/AnimatedMeshBackground";
import { EmptyState } from "@/components/EmptyState";
import { GlassCard } from "@/components/GlassCard";
import { MiniPlayer } from "@/components/MiniPlayer";
import { PlayerPanel } from "@/components/PlayerPanel";
import { StationGrid } from "@/components/StationGrid";
import { AudioPlayerProvider, useAudioPlayer } from "@/features/player/AudioPlayerProvider";
import type { Station } from "@/features/stations/stationTypes";
import { useLocalStations } from "@/hooks/useLocalStations";
import { useStationSearch, useTopStations } from "@/hooks/useStations";
import { getRandomStation } from "@/lib/stationApi";

type Tab = "home" | "search" | "favorites" | "recent";

function WebRadioExperience() {
  const [tab, setTab] = useState<Tab>("home");
  const [query, setQuery] = useState("");
  const [waitlistOpen, setWaitlistOpen] = useState(false);
  const favorites = useLocalStations("radioapp:web:favorites", 100);
  const recent = useLocalStations("radioapp:web:recent", 30);
  const topStations = useTopStations();
  const searchResults = useStationSearch(query);
  const player = useAudioPlayer();

  const favoriteIds = useMemo(
    () => new Set(favorites.stations.map((station) => station.id)),
    [favorites.stations]
  );

  const playStation = (station: Station, playlist: Station[], playlistTitle: string) => {
    player.playStation(station, playlist, playlistTitle);
  };

  const toggleFavorite = (station: Station) => {
    if (favorites.hasStation(station.id)) favorites.removeStation(station.id);
    else favorites.addStation(station);
  };

  const playRandom = async () => {
    const station = await getRandomStation(player.state.currentStation?.id);
    if (station) playStation(station, [station], "随便听听");
  };

  const currentStationId = player.state.currentStation?.id;

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-6xl flex-col px-4 pb-28 pt-12 md:px-8">
      <header className="mb-6 flex items-start gap-3">
        <div>
          <h1 className="text-5xl font-black tracking-normal text-white">发现</h1>
          <p className="mt-2 text-base font-medium text-[var(--neon-cyan)]">
            探索全球电台
          </p>
        </div>
        <button
          type="button"
          onClick={playRandom}
          className="ml-auto grid h-12 w-12 place-items-center rounded-full bg-[linear-gradient(135deg,var(--neon-magenta),var(--neon-purple))] text-white neon-glow-magenta active:scale-95"
          aria-label="随便听听"
        >
          <Shuffle size={20} />
        </button>
      </header>

      <GlassCard className="mb-4 p-3">
        <label className="flex items-center gap-3">
          <Search className="text-[var(--neon-cyan)]" size={20} />
          <input
            value={query}
            onChange={(event) => {
              setQuery(event.target.value);
              setTab("search");
            }}
            placeholder="搜索电台、风格、地区..."
            className="min-w-0 flex-1 bg-transparent py-2 text-white outline-none placeholder:text-white/40"
          />
          <Sparkles className="text-[var(--neon-purple)]" size={18} />
        </label>
      </GlassCard>

      <nav className="mb-6 grid grid-cols-4 gap-2">
        {[
          ["home", "发现", Radio],
          ["search", "搜索", Search],
          ["favorites", "收藏", Heart],
          ["recent", "最近", History],
        ].map(([value, label, Icon]) => (
          <button
            key={value as string}
            type="button"
            aria-label={label as string}
            onClick={() => setTab(value as Tab)}
            className={`rounded-2xl border px-3 py-3 text-sm font-bold ${
              tab === value
                ? "border-[rgba(0,217,255,0.7)] bg-[rgba(0,217,255,0.16)] text-white neon-glow-cyan"
                : "border-white/10 bg-white/[0.04] text-white/55"
            }`}
          >
            <Icon className="mx-auto mb-1" size={18} />
            {label as string}
          </button>
        ))}
      </nav>

      {tab === "home" ? (
        <section className="space-y-4">
          {topStations.isLoading ? (
            <div className="flex items-center justify-center py-12 text-[var(--neon-cyan)]">
              <Loader2 className="animate-spin" />
            </div>
          ) : topStations.error ? (
            <EmptyState title="暂时无法加载推荐" description="请稍后重试，当前播放不会受到影响。" />
          ) : (
            <StationGrid
              stations={topStations.data ?? []}
              currentStationId={currentStationId}
              favoriteIds={favoriteIds}
              playlistTitle="发现"
              onPlayStation={playStation}
              onToggleFavorite={toggleFavorite}
            />
          )}
        </section>
      ) : null}

      {tab === "search" ? (
        <section>
          {query.trim().length === 0 ? (
            <EmptyState title="输入关键词开始搜索" description="可以搜索电台名、风格、地区或频率。" />
          ) : searchResults.isLoading ? (
            <div className="flex items-center justify-center py-12 text-[var(--neon-cyan)]">
              <Loader2 className="animate-spin" />
            </div>
          ) : searchResults.error ? (
            <EmptyState title="搜索暂时失败" description="请保留关键词稍后重试。" />
          ) : (
            <StationGrid
              stations={searchResults.data ?? []}
              currentStationId={currentStationId}
              favoriteIds={favoriteIds}
              playlistTitle="搜索"
              onPlayStation={playStation}
              onToggleFavorite={toggleFavorite}
            />
          )}
        </section>
      ) : null}

      {tab === "favorites" ? (
        favorites.stations.length === 0 ? (
          <EmptyState title="还没有收藏" description="在发现或搜索里点亮心形，就能把电台留在这里。" />
        ) : (
          <StationGrid
            stations={favorites.stations}
            currentStationId={currentStationId}
            favoriteIds={favoriteIds}
            playlistTitle="收藏"
            onPlayStation={playStation}
            onToggleFavorite={toggleFavorite}
          />
        )
      ) : null}

      {tab === "recent" ? (
        recent.stations.length === 0 ? (
          <EmptyState title="最近播放为空" description="听过的电台会自动出现在这里。" />
        ) : (
          <StationGrid
            stations={recent.stations}
            currentStationId={currentStationId}
            favoriteIds={favoriteIds}
            playlistTitle="最近播放"
            onPlayStation={playStation}
            onToggleFavorite={toggleFavorite}
          />
        )
      ) : null}

      <button
        type="button"
        onClick={() => setWaitlistOpen(true)}
        className="mt-8 inline-flex items-center justify-center gap-2 rounded-2xl border border-[rgba(255,0,110,0.3)] bg-[rgba(255,0,110,0.1)] px-4 py-3 text-sm font-bold text-white/85"
      >
        <Clock3 size={18} />
        识别歌曲：macOS 版即将推出
      </button>

      <MiniPlayer />
      <PlayerPanel
        isFavorite={
          player.state.currentStation
            ? favorites.hasStation(player.state.currentStation.id)
            : false
        }
        onToggleFavorite={toggleFavorite}
        onOpenWaitlist={() => setWaitlistOpen(true)}
      />
      {waitlistOpen ? (
        <div className="fixed inset-0 z-[60] grid place-items-center bg-black/70 p-4 backdrop-blur-xl">
          <div
            role="dialog"
            aria-modal="true"
            aria-label="macOS 等待名单"
            className="w-full max-w-md rounded-3xl border border-[rgba(255,0,110,0.35)] bg-[rgba(21,21,32,0.96)] p-5"
          >
            <h2 className="text-2xl font-black text-white">macOS 版即将推出</h2>
            <p className="mt-2 text-sm leading-6 text-white/65">
              网页版先专心做好收音机。歌曲识别、歌词和更稳定的后台体验会优先在 macOS 版开放。
            </p>
            <button
              type="button"
              onClick={() => setWaitlistOpen(false)}
              className="mt-4 rounded-2xl bg-[linear-gradient(135deg,var(--neon-magenta),var(--neon-purple))] px-4 py-3 font-bold text-white"
            >
              我知道了
            </button>
          </div>
        </div>
      ) : null}
    </main>
  );
}

export default function Home() {
  const recent = useLocalStations("radioapp:web:recent", 30);

  return (
    <>
      <AnimatedMeshBackground />
      <AudioPlayerProvider onPlayedStation={recent.addStation}>
        <WebRadioExperience />
      </AudioPlayerProvider>
    </>
  );
}
```

- [ ] **Step 4: Run page test**

Run:

```bash
cd WebApp
npm run test -- src/app/page.test.tsx
```

Expected: PASS after the page shell renders.

- [ ] **Step 5: Run full checks**

Run:

```bash
cd WebApp
npm run test
npm run lint
npm run build
```

Expected: PASS.

- [ ] **Step 6: Commit main experience**

Run:

```bash
git add WebApp/src/app/page.tsx WebApp/src/app/page.test.tsx
git commit -m "feat(web): build radio listening shell"
```

---

### Task 11: Waitlist Modal UI

**Files:**
- Create: `WebApp/src/components/WaitlistModal.tsx`
- Create: `WebApp/src/components/WaitlistModal.test.tsx`
- Modify: `WebApp/src/app/page.tsx`

- [ ] **Step 1: Write failing modal tests**

Write `WebApp/src/components/WaitlistModal.test.tsx`:

```tsx
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { WaitlistModal } from "./WaitlistModal";

describe("WaitlistModal", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it("submits an email to the waitlist API", async () => {
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(new Response(JSON.stringify({ ok: true })));
    const user = userEvent.setup();

    render(<WaitlistModal open onClose={vi.fn()} />);

    await user.type(screen.getByLabelText("邮箱"), "user@example.com");
    await user.click(screen.getByRole("button", { name: "加入等待名单" }));

    await waitFor(() => {
      expect(screen.getByText("已加入等待名单")).toBeInTheDocument();
    });
    expect(fetchMock).toHaveBeenCalledWith(
      "/api/waitlist",
      expect.objectContaining({
        method: "POST",
        headers: { "Content-Type": "application/json" },
      })
    );
  });

  it("keeps email visible when submission fails", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ error: "暂时无法加入等待名单，请稍后再试。" }), {
        status: 502,
      })
    );
    const user = userEvent.setup();

    render(<WaitlistModal open onClose={vi.fn()} />);

    const input = screen.getByLabelText("邮箱");
    await user.type(input, "user@example.com");
    await user.click(screen.getByRole("button", { name: "加入等待名单" }));

    await waitFor(() => {
      expect(screen.getByText("暂时无法加入等待名单，请稍后再试。")).toBeInTheDocument();
    });
    expect(input).toHaveValue("user@example.com");
  });
});
```

- [ ] **Step 2: Run modal tests to verify failure**

Run:

```bash
cd WebApp
npm run test -- src/components/WaitlistModal.test.tsx
```

Expected: FAIL because `WaitlistModal` does not exist.

- [ ] **Step 3: Implement WaitlistModal**

Write `WebApp/src/components/WaitlistModal.tsx`:

```tsx
"use client";

import { Loader2, X } from "lucide-react";
import { useState } from "react";
import { IconButton } from "./IconButton";

type WaitlistModalProps = {
  open: boolean;
  onClose: () => void;
};

export function WaitlistModal({ open, onClose }: WaitlistModalProps) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<"idle" | "submitting" | "success" | "error">("idle");
  const [message, setMessage] = useState("");

  if (!open) return null;

  const submit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setStatus("submitting");
    setMessage("");

    const response = await fetch("/api/waitlist", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        email,
        source: "recognition",
        userAgent: navigator.userAgent,
      }),
    });

    const data = (await response.json().catch(() => ({}))) as { error?: string };

    if (!response.ok) {
      setStatus("error");
      setMessage(data.error ?? "暂时无法加入等待名单，请稍后再试。");
      return;
    }

    setStatus("success");
    setMessage("已加入等待名单");
  };

  return (
    <div className="fixed inset-0 z-[60] grid place-items-center bg-black/70 p-4 backdrop-blur-xl">
      <div className="w-full max-w-md rounded-3xl border border-[rgba(255,0,110,0.35)] bg-[rgba(21,21,32,0.96)] p-5 shadow-2xl">
        <div className="mb-4 flex items-start gap-3">
          <div>
            <h2 className="text-2xl font-black text-white">macOS 版即将推出</h2>
            <p className="mt-2 text-sm leading-6 text-white/65">
              网页版先专心做好收音机。歌曲识别、歌词和更稳定的后台体验会优先在 macOS 版开放。
            </p>
          </div>
          <IconButton label="关闭等待名单" onClick={onClose}>
            <X size={18} />
          </IconButton>
        </div>

        <form onSubmit={submit} className="space-y-3">
          <label className="block text-sm font-bold text-white/80">
            邮箱
            <input
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              type="email"
              required
              className="mt-2 w-full rounded-2xl border border-white/10 bg-white/[0.06] px-4 py-3 text-white outline-none focus:border-[var(--neon-cyan)]"
              placeholder="you@example.com"
            />
          </label>

          <button
            type="submit"
            disabled={status === "submitting"}
            className="flex w-full items-center justify-center gap-2 rounded-2xl bg-[linear-gradient(135deg,var(--neon-magenta),var(--neon-purple))] px-4 py-3 font-black text-white neon-glow-magenta disabled:opacity-60"
          >
            {status === "submitting" ? <Loader2 className="animate-spin" size={18} /> : null}
            加入等待名单
          </button>
        </form>

        {message ? (
          <p
            className={`mt-3 rounded-2xl px-4 py-3 text-sm ${
              status === "success"
                ? "bg-[rgba(0,217,255,0.12)] text-[var(--neon-cyan)]"
                : "bg-[rgba(255,59,48,0.12)] text-white/85"
            }`}
          >
            {message}
          </p>
        ) : null}
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Replace the inline page prompt with WaitlistModal**

In `WebApp/src/app/page.tsx`, add this import next to the other component imports:

```tsx
import { WaitlistModal } from "@/components/WaitlistModal";
```

Then replace the inline `waitlistOpen ? (...) : null` dialog block at the end of `WebRadioExperience` with:

```tsx
<WaitlistModal open={waitlistOpen} onClose={() => setWaitlistOpen(false)} />
```

- [ ] **Step 5: Run modal tests**

Run:

```bash
cd WebApp
npm run test -- src/components/WaitlistModal.test.tsx
npm run lint
npm run build
```

Expected: PASS.

- [ ] **Step 6: Commit waitlist modal**

Run:

```bash
git add WebApp/src/components/WaitlistModal.tsx WebApp/src/components/WaitlistModal.test.tsx WebApp/src/app/page.tsx
git commit -m "feat(web): add waitlist modal"
```

---

### Task 12: Playwright Smoke Tests and Final Verification

**Files:**
- Create: `WebApp/playwright.config.ts`
- Create: `WebApp/tests/e2e/web-mvp.spec.ts`
- Modify: `WebApp/package.json`
- Create: `WebApp/README.md`

- [ ] **Step 1: Add Playwright config**

Write `WebApp/playwright.config.ts`:

```ts
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  webServer: {
    command: "npm run dev",
    url: "http://127.0.0.1:3000",
    reuseExistingServer: true,
  },
  use: {
    baseURL: "http://127.0.0.1:3000",
    trace: "on-first-retry",
  },
  projects: [
    {
      name: "Mobile Safari",
      use: { ...devices["iPhone 15"] },
    },
    {
      name: "Desktop Chrome",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
```

- [ ] **Step 2: Write Playwright smoke test**

Write `WebApp/tests/e2e/web-mvp.spec.ts`:

```ts
import { expect, test } from "@playwright/test";

test("loads the Web MVP shell", async ({ page }) => {
  await page.route("**/api/stations/top", async (route) => {
    await route.fulfill({
      json: {
        stations: [
          {
            changeuuid: "change-1",
            stationuuid: "station-1",
            id: "station-1",
            name: "清晨音乐台",
            url: "https://example.com/live.mp3",
            urlResolved: "https://example.com/live.mp3",
            homepage: "",
            favicon: "",
            tags: "music,pop music",
            country: "China",
            countrycode: "CN",
            state: "",
            language: "chinese",
            languagecodes: "zh",
            votes: 1,
            codec: "MP3",
            bitrate: 128,
            hls: 0,
            lastcheckok: 1,
            clickcount: 1,
            clicktrend: 1,
          },
        ],
      },
    });
  });

  await page.goto("/");

  await expect(page.getByRole("heading", { name: "发现" })).toBeVisible();
  await expect(page.getByText("探索全球电台")).toBeVisible();
  await expect(page.getByText("清晨音乐台")).toBeVisible();
});

test("submits waitlist email", async ({ page }) => {
  await page.route("**/api/stations/top", async (route) => {
    await route.fulfill({ json: { stations: [] } });
  });
  await page.route("**/api/waitlist", async (route) => {
    await route.fulfill({ json: { ok: true } });
  });

  await page.goto("/");
  await page.getByRole("button", { name: /识别歌曲/ }).click();
  await page.getByLabel("邮箱").fill("user@example.com");
  await page.getByRole("button", { name: "加入等待名单" }).click();

  await expect(page.getByText("已加入等待名单")).toBeVisible();
});
```

- [ ] **Step 3: Add README**

Write `WebApp/README.md`:

```md
# RadioApp Web MVP

Browser client for 拾音 FM.

## Development

```bash
npm install
npm run dev
```

Open http://localhost:3000.

## Environment

Copy `.env.example` to `.env.local` and set:

```dotenv
SUPABASE_URL=...
SUPABASE_SECRET_KEY=...
```

`SUPABASE_SECRET_KEY` must only be used by server-side route handlers.

## Checks

```bash
npm run test
npm run lint
npm run build
npm run e2e
```

## Scope

The MVP supports station discovery, search, playback, local favorites, local recent plays, and the macOS waitlist. Web song recognition is intentionally outside the MVP.
```

- [ ] **Step 4: Install Playwright browsers**

Run:

```bash
cd WebApp
npx playwright install --with-deps
```

Expected: Playwright browser installation succeeds.

- [ ] **Step 5: Run all verification**

Run:

```bash
cd WebApp
npm run test
npm run lint
npm run build
npm run e2e
```

Expected: PASS.

- [ ] **Step 6: Manual visual verification**

Run:

```bash
cd WebApp
npm run dev
```

Open `http://localhost:3000` and verify:

- Mobile viewport shows dark neon mesh background.
- Home first screen is the radio product, not a marketing page.
- Cards use glass surfaces and cyan active borders.
- Play button uses magenta/purple gradient.
- Station images fall back to branded gradient initials.
- Mini player stays readable at the bottom.
- Waitlist modal copy mentions macOS and does not mention iOS.

- [ ] **Step 7: Commit verification assets and docs**

Run:

```bash
git add WebApp/playwright.config.ts WebApp/tests WebApp/README.md WebApp/package.json WebApp/package-lock.json
git commit -m "test(web): add smoke coverage"
```

---

### Task 13: Final Integration Pass

**Files:**
- Modify only files under `WebApp/` if verification reveals WebApp issues.

- [ ] **Step 1: Confirm repository status**

Run:

```bash
git status --short
```

Expected: No unexpected changes outside `WebApp/`. The existing `RadioApp.xcodeproj/xcshareddata/xcschemes/RadioApp.xcscheme` change may still be present from before this plan and should not be included in WebApp commits.

- [ ] **Step 2: Confirm WebApp builds from clean install**

Run:

```bash
cd WebApp
rm -rf .next
npm ci
npm run test
npm run lint
npm run build
```

Expected: PASS.

- [ ] **Step 3: Confirm API route behavior locally**

Run:

```bash
cd WebApp
npm run dev
```

In another terminal:

```bash
curl -s http://127.0.0.1:3000/api/stations/top | head
curl -s "http://127.0.0.1:3000/api/stations/search?q=%E9%9F%B3%E4%B9%90" | head
curl -s http://127.0.0.1:3000/api/stations/random | head
```

Expected: Each response is JSON. The waitlist route requires Supabase environment variables, so test it with mocked automated tests unless `.env.local` is configured.

- [ ] **Step 4: Add final commit if integration fixes were needed**

If Step 2 or Step 3 required fixes, run:

```bash
git add WebApp
git commit -m "fix(web): complete MVP integration"
```

If no fixes were needed, do not create an empty commit.

---

## Plan Self-Review Checklist

- Spec coverage: Tasks cover `/WebApp`, Next.js, TypeScript, radio-browser proxy, local favorites/recent, playback, waitlist, Supabase schema, iOS-style visual system, tests, and Vercel-friendly environment variables.
- Scope control: Real song recognition, auth, sync, payments, widgets, and iOS conversion stay out of the implementation.
- Type consistency: `Station`, `RadioBrowserStation`, `WaitlistSubmission`, and player state names match across tasks.
- Verification: Unit tests, component tests, build, lint, Playwright, and manual visual checks are included.
