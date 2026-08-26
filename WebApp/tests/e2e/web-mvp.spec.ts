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
    {
      changeuuid: "change-2",
      stationuuid: "station-2",
      id: "station-2",
      name: "一个名字特别长但仍然应该适配屏幕宽度的推荐音乐电台",
      url: "https://example.com/long-live.mp3",
      urlResolved: "https://example.com/long-live.mp3",
      homepage: "https://example.com/long",
      favicon: "",
      tags: "internet radio,oldies,indie,pop,music",
      country: "China",
      countrycode: "CN",
      state: "Guangdong",
      language: "chinese",
      languagecodes: "zh",
      votes: 18,
      codec: "MP3",
      bitrate: 128,
      hls: 0,
      lastcheckok: 1,
      clickcount: 60,
      clicktrend: 6,
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

test("keeps station cards inside the mobile viewport", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 844 });
  await page.goto("/");

  const favoriteButtons = page.getByRole("button", { name: /^收藏 / });
  await expect(favoriteButtons.first()).toBeVisible();

  const metrics = await page.evaluate(() => ({
    bodyClientWidth: document.body.clientWidth,
    bodyScrollWidth: document.body.scrollWidth,
    documentClientWidth: document.documentElement.clientWidth,
    documentScrollWidth: document.documentElement.scrollWidth,
  }));

  expect(metrics.bodyScrollWidth).toBeLessThanOrEqual(metrics.bodyClientWidth + 1);
  expect(metrics.documentScrollWidth).toBeLessThanOrEqual(
    metrics.documentClientWidth + 1,
  );

  const viewport = page.viewportSize();

  expect(viewport).not.toBeNull();

  for (let index = 0; index < await favoriteButtons.count(); index += 1) {
    const favoriteBox = await favoriteButtons.nth(index).boundingBox();

    expect(favoriteBox).not.toBeNull();
    expect(favoriteBox!.x).toBeGreaterThanOrEqual(0);
    expect(favoriteBox!.x + favoriteBox!.width).toBeLessThanOrEqual(
      viewport!.width,
    );
  }
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
