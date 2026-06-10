import { expect, test } from "@playwright/test";

const topStations = {
  stations: [
    {
      changeuuid: "change-1",
      stationuuid: "station-1",
      id: "station-1",
      name: "清晨音乐台",
      url: "https://example.com/live.mp3",
      urlResolved: "https://example.com/live.mp3",
      homepage: "https://example.com",
      favicon: "",
      tags: "music,pop",
      country: "China",
      countrycode: "CN",
      state: "Shanghai",
      language: "chinese",
      languagecodes: "zh",
      votes: 42,
      codec: "MP3",
      bitrate: 128,
      hls: 0,
      lastcheckok: 1,
      clickcount: 120,
      clicktrend: 12,
    },
  ],
};

test.beforeEach(async ({ page }) => {
  await page.route("**/api/stations/top", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(topStations),
    });
  });

  await page.route("**/api/stations/search?*", async (route) => {
    const url = new URL(route.request().url());
    const query = url.searchParams.get("q");
    const stations =
      query === "jazz"
        ? topStations.stations
        : [];

    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ stations }),
    });
  });

  await page.route("**/api/stations/random**", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ station: topStations.stations[0] }),
    });
  });

  await page.route("**/api/waitlist", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ ok: true }),
    });
  });
});

test("renders the main listening shell", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByRole("heading", { name: "发现" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "推荐电台" })).toBeVisible();
  await expect(page.getByText("清晨音乐台")).toBeVisible();
  await expect(
    page.getByPlaceholder("搜索电台、风格、地区...")
  ).toBeVisible();
});

test("shows empty search feedback for unmatched keywords", async ({ page }) => {
  await page.goto("/");

  await page.getByPlaceholder("搜索电台、风格、地区...").fill("ambient");

  await expect(page.getByText("还没有找到匹配电台")).toBeVisible();
});

test("submits the macOS waitlist modal", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: "识别歌曲：macOS 版即将推出" }).click();

  await expect(page.getByRole("dialog")).toBeVisible();
  await page.getByLabel("邮箱地址").fill("listener@example.com");
  await page.getByRole("button", { name: "加入等待名单" }).click();

  await expect(page.getByText("已经帮你排上了")).toBeVisible();
});
