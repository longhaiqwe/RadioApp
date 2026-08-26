export type ShareCardData = {
  title: string;
  artist: string;
  album?: string | null;
  artworkUrl?: string | null;
  artworkDataUrl?: string | null;
  releaseDate?: string | Date | null;
  stationName?: string | null;
  timestamp: Date;
};

const CARD_WIDTH = 360;
const CARD_HEIGHT = 620;
const WAVEFORM_HEIGHTS = [
  18, 28, 14, 24, 34, 20, 38, 16, 40, 24, 30, 18, 22, 26, 20, 30, 28, 22,
  36, 24, 32, 34, 40, 42, 20, 26, 34, 38, 24, 40, 16, 30,
];
const MINI_WAVEFORM_HEIGHTS = [12, 18, 10, 22, 14, 24, 12, 20];
const SHARE_SITE_URL = "https://www.shiyinfm.cn/";
const SHARE_SITE_DISPLAY_URL = "www.shiyinfm.cn";
const SHARE_SITE_QR_ROWS = [
  "1111111000011100101111111",
  "1000001001101111101000001",
  "1011101010101001001011101",
  "1011101010001110001011101",
  "1011101010001000101011101",
  "1000001011100111101000001",
  "1111111010101010101111111",
  "0000000011001001000000000",
  "1011111000111110101111100",
  "0110100100111100110100010",
  "1100011110011011111111011",
  "0010100111011011010100001",
  "1010101001100100011110111",
  "1100000110101100110101010",
  "1001011011000111011111011",
  "1010110101101001010110001",
  "1011111001001110111110100",
  "0000000011100001100011000",
  "1111111000011100101010111",
  "1000001010110010100011001",
  "1011101011011111111110100",
  "1011101010001100101011111",
  "1011101010000111000001101",
  "1000001001010000110111001",
  "1111111010111100000111111",
];

export function createShareCardSvg(data: ShareCardData) {
  const titleLines = splitTitleLines(data.title);
  const artistAlbum = data.album
    ? `${data.artist}  ·  ${data.album}`
    : data.artist;
  const stationName = data.stationName?.trim() || "拾音FM";
  const releaseMemory = formatReleaseMemory(data.releaseDate, data.timestamp);
  const artworkDataUrl = readShareCardArtworkDataUrl(data);
  const titleStartY = titleLines.length > 1 ? 312 : 326;
  const subtitleY = titleLines.length > 1 ? 376 : 360;
  const releaseY = titleLines.length > 1 ? 404 : 388;

  return `<svg width="${CARD_WIDTH}" height="${CARD_HEIGHT}" viewBox="0 0 ${CARD_WIDTH} ${CARD_HEIGHT}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="cardClip">
      <rect width="${CARD_WIDTH}" height="${CARD_HEIGHT}" rx="24" ry="24"/>
    </clipPath>
    <clipPath id="artworkClip">
      <rect x="80" y="78" width="200" height="200" rx="20" ry="20"/>
    </clipPath>
    <linearGradient id="cardStroke" x1="0" y1="0" x2="360" y2="620" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#00D9FF" stop-opacity="0.4"/>
      <stop offset="0.45" stop-color="#8338EC" stop-opacity="0.3"/>
      <stop offset="0.78" stop-color="#FF006E" stop-opacity="0.2"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="artworkFill" x1="90" y1="80" x2="270" y2="280" gradientUnits="userSpaceOnUse">
      <stop stop-color="#1A1A2E"/>
      <stop offset="1" stop-color="#151520"/>
    </linearGradient>
    <linearGradient id="waveFill" x1="0" y1="454" x2="0" y2="404" gradientUnits="userSpaceOnUse">
      <stop stop-color="#00D9FF"/>
      <stop offset="1" stop-color="#8338EC"/>
    </linearGradient>
    <linearGradient id="brandFill" x1="120" y1="528" x2="168" y2="576" gradientUnits="userSpaceOnUse">
      <stop stop-color="#00D9FF"/>
      <stop offset="1" stop-color="#8338EC"/>
    </linearGradient>
    <linearGradient id="dividerFill" x1="32" y1="516" x2="328" y2="516" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFFFFF" stop-opacity="0"/>
      <stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0.15"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
    <filter id="softBlur" x="-60%" y="-60%" width="220%" height="220%">
      <feGaussianBlur stdDeviation="34"/>
    </filter>
    <filter id="artGlow" x="-50%" y="-50%" width="200%" height="200%">
      <feDropShadow dx="0" dy="15" stdDeviation="18" flood-color="#8338EC" flood-opacity="0.55"/>
      <feDropShadow dx="0" dy="5" stdDeviation="12" flood-color="#00D9FF" flood-opacity="0.28"/>
    </filter>
    <filter id="cyanTextGlow" x="-35%" y="-35%" width="170%" height="170%">
      <feDropShadow dx="0" dy="0" stdDeviation="3" flood-color="#00D9FF" flood-opacity="0.32"/>
    </filter>
    <filter id="barGlow" x="-120%" y="-60%" width="340%" height="220%">
      <feDropShadow dx="0" dy="0" stdDeviation="2" flood-color="#00D9FF" flood-opacity="0.42"/>
    </filter>
    <style>
      .font { font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Microsoft YaHei", sans-serif; }
    </style>
  </defs>
  <g clip-path="url(#cardClip)">
    <rect width="${CARD_WIDTH}" height="${CARD_HEIGHT}" fill="#0A0A0F"/>
    <circle cx="78" cy="24" r="250" fill="#8338EC" opacity="0.35" filter="url(#softBlur)"/>
    <circle cx="282" cy="500" r="200" fill="#00D9FF" opacity="0.2" filter="url(#softBlur)"/>
    <circle cx="240" cy="92" r="150" fill="#FF006E" opacity="0.15" filter="url(#softBlur)"/>
    ${makeNoiseDots()}

    <circle cx="180" cy="178" r="128" fill="#8338EC" opacity="0.22"/>
    <circle cx="180" cy="178" r="88" fill="#8338EC" opacity="0.18"/>
    <g filter="url(#artGlow)">
      <rect x="80" y="78" width="200" height="200" rx="20" fill="url(#artworkFill)" stroke="#00D9FF" stroke-opacity="0.2"/>
      ${
        artworkDataUrl
          ? `<image href="${escapeSvg(artworkDataUrl)}" x="80" y="78" width="200" height="200" preserveAspectRatio="xMidYMid slice" clip-path="url(#artworkClip)"/>`
          : `<text class="font" x="180" y="170" text-anchor="middle" font-size="66" font-weight="300" fill="#00D9FF" opacity="0.5">♪</text>
      ${makeMiniWaveformBars()}`
      }
      <rect x="80.5" y="78.5" width="199" height="199" rx="19.5" fill="none" stroke="#FFFFFF" stroke-opacity="0.12"/>
    </g>

    <g class="font" text-anchor="middle" filter="url(#cyanTextGlow)">
      ${titleLines
        .map(
          (line, index) =>
            `<text x="180" y="${titleStartY + index * 30}" font-size="24" font-weight="700" fill="#FFFFFF">${escapeSvg(line)}</text>`
        )
        .join("")}
    </g>
    <text class="font" x="180" y="${subtitleY}" text-anchor="middle" font-size="16" font-weight="500" fill="#00D9FF" opacity="0.8">${escapeSvg(
      truncateText(artistAlbum, 28)
    )}</text>
    ${
      releaseMemory
        ? `<text class="font" x="180" y="${releaseY}" text-anchor="middle" font-size="13" font-weight="500" fill="#FFFFFF" opacity="0.48">◷ ${escapeSvg(
            releaseMemory
          )}</text>`
        : ""
    }

    <g filter="url(#barGlow)">
      ${makeWaveformBars()}
    </g>

    <g class="font" fill="#FFFFFF" opacity="0.5">
      <text x="24" y="486" font-size="12">◉</text>
      <text x="44" y="486" font-size="13" font-weight="500">${escapeSvg(
        truncateText(stationName, 13)
      )}</text>
    </g>
    <g class="font" fill="#FFFFFF" opacity="0.4">
      <text x="214" y="486" font-size="12">◷</text>
      <text x="234" y="486" font-size="13">${formatShareDate(data.timestamp)}</text>
    </g>

    <rect x="32" y="516" width="296" height="1" fill="url(#dividerFill)"/>

    <circle cx="58" cy="552" r="24" fill="url(#brandFill)" filter="url(#barGlow)"/>
    <text class="font" x="58" y="560" text-anchor="middle" font-size="23" font-weight="700" fill="#FFFFFF">♫</text>
    <text class="font" x="92" y="548" font-size="18" font-weight="700" fill="#FFFFFF">拾音FM</text>
    <text class="font" x="92" y="570" font-size="12" fill="#FFFFFF" opacity="0.58">${escapeSvg(
      SHARE_SITE_DISPLAY_URL
    )}</text>
    ${makeShareSiteQrCode(268, 526, 60)}
  </g>
  <rect x="0.75" y="0.75" width="358.5" height="618.5" rx="23.25" fill="none" stroke="url(#cardStroke)" stroke-width="1.5"/>
</svg>`;
}

export function createShareCardSvgDataUrl(data: ShareCardData) {
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(
    createShareCardSvg(data)
  )}`;
}

export async function prepareShareCardData(
  data: ShareCardData
): Promise<ShareCardData> {
  if (data.artworkDataUrl || !data.artworkUrl) return data;
  if (data.artworkUrl.startsWith("data:image/")) {
    return { ...data, artworkDataUrl: data.artworkUrl };
  }
  if (typeof window === "undefined") return data;

  const artworkDataUrl = await fetchArtworkAsDataUrl(data.artworkUrl).catch(
    () => null
  );

  return artworkDataUrl ? { ...data, artworkDataUrl } : data;
}

export function makeArtworkProxyUrl(url: string | null | undefined) {
  const trimmedUrl = url?.trim();
  if (!trimmedUrl) return null;
  if (trimmedUrl.startsWith("data:image/")) return trimmedUrl;

  return `/api/artwork?url=${encodeURIComponent(trimmedUrl)}`;
}

export async function shareOrDownloadShareCard(data: ShareCardData) {
  const blob = await renderShareCardPngBlob(data);
  const filename = `${sanitizeFileName(data.title || "拾音FM分享图")}-拾音FM.png`;

  if (typeof File !== "undefined") {
    const file = new File([blob], filename, { type: "image/png" });
    const navigatorWithFiles = navigator as Navigator & {
      canShare?: (data: ShareData) => boolean;
    };

    if (
      navigatorWithFiles.share &&
      navigatorWithFiles.canShare?.({ files: [file] })
    ) {
      await navigatorWithFiles.share({
        files: [file],
        title: `${data.title} - ${data.artist}`,
        text: "我在拾音FM识别到这首歌",
      });
      return;
    }
  }

  downloadBlob(blob, filename);
}

export async function downloadShareCard(data: ShareCardData) {
  const blob = await renderShareCardPngBlob(data);
  const filename = `${sanitizeFileName(data.title || "拾音FM分享图")}-拾音FM.png`;

  downloadBlob(blob, filename);
}

async function renderShareCardPngBlob(data: ShareCardData) {
  if (typeof document === "undefined") {
    throw new Error("分享图只能在浏览器中生成");
  }

  const preparedData = await prepareShareCardData(data);
  const image = new Image();
  const svgBlob = new Blob([createShareCardSvg(preparedData)], {
    type: "image/svg+xml;charset=utf-8",
  });
  const objectUrl = URL.createObjectURL(svgBlob);

  try {
    await new Promise<void>((resolve, reject) => {
      image.onload = () => resolve();
      image.onerror = () => reject(new Error("分享图预览加载失败"));
      image.src = objectUrl;
    });

    const pixelRatio = Math.min(window.devicePixelRatio || 2, 3);
    const canvas = document.createElement("canvas");
    canvas.width = CARD_WIDTH * pixelRatio;
    canvas.height = CARD_HEIGHT * pixelRatio;

    const context = canvas.getContext("2d");
    if (!context) throw new Error("当前浏览器不支持生成分享图");

    context.scale(pixelRatio, pixelRatio);
    context.drawImage(image, 0, 0, CARD_WIDTH, CARD_HEIGHT);

    return await new Promise<Blob>((resolve, reject) => {
      canvas.toBlob((blob) => {
        if (blob) {
          resolve(blob);
          return;
        }

        reject(new Error("分享图生成失败"));
      }, "image/png");
    });
  } finally {
    URL.revokeObjectURL(objectUrl);
  }
}

async function fetchArtworkAsDataUrl(url: string) {
  const proxyUrl = makeArtworkProxyUrl(url);
  if (!proxyUrl) return null;

  const response = await fetch(proxyUrl);
  if (!response.ok) return null;

  const blob = await response.blob();
  const contentType = blob.type || response.headers.get("content-type") || "";
  if (!contentType.toLowerCase().startsWith("image/")) return null;
  const readableBlob = blob.type ? blob : new Blob([blob], { type: contentType });

  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === "string") {
        resolve(reader.result);
        return;
      }

      reject(new Error("封面读取失败"));
    };
    reader.onerror = () => reject(new Error("封面读取失败"));
    reader.readAsDataURL(readableBlob);
  });
}

function downloadBlob(blob: Blob, filename: string) {
  const objectUrl = URL.createObjectURL(blob);
  const anchor = document.createElement("a");

  anchor.href = objectUrl;
  anchor.download = filename;
  anchor.rel = "noreferrer";
  document.body.append(anchor);
  anchor.click();
  anchor.remove();

  window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
}

function makeShareSiteQrCode(x: number, y: number, size: number) {
  const quietModules = 2;
  const moduleCount = SHARE_SITE_QR_ROWS.length + quietModules * 2;
  const moduleSize = size / moduleCount;
  const modules = SHARE_SITE_QR_ROWS.flatMap((row, rowIndex) =>
    [...row].map((cell, columnIndex) => {
      if (cell !== "1") return "";

      return `<rect class="qrModule" x="${formatSvgNumber(
        x + (columnIndex + quietModules) * moduleSize
      )}" y="${formatSvgNumber(
        y + (rowIndex + quietModules) * moduleSize
      )}" width="${formatSvgNumber(moduleSize)}" height="${formatSvgNumber(
        moduleSize
      )}" fill="#0A0A0F"/>`;
    })
  ).join("");

  return `<g id="shareSiteQr" data-url="${escapeSvg(SHARE_SITE_URL)}">
      <rect x="${x}" y="${y}" width="${size}" height="${size}" rx="8" fill="#FFFFFF"/>
      ${modules}
    </g>`;
}

function formatSvgNumber(value: number) {
  return Number(value.toFixed(3));
}

function makeWaveformBars() {
  const totalWidth = WAVEFORM_HEIGHTS.length * 4 + (WAVEFORM_HEIGHTS.length - 1) * 3;
  const startX = (CARD_WIDTH - totalWidth) / 2;

  return WAVEFORM_HEIGHTS.map((height, index) => {
    const x = startX + index * 7;
    const y = 430 - height / 2;
    return `<rect x="${x}" y="${y}" width="4" height="${height}" rx="2" fill="url(#waveFill)"/>`;
  }).join("");
}

function makeMiniWaveformBars() {
  const totalWidth =
    MINI_WAVEFORM_HEIGHTS.length * 3 + (MINI_WAVEFORM_HEIGHTS.length - 1) * 3;
  const startX = 180 - totalWidth / 2;

  return MINI_WAVEFORM_HEIGHTS.map((height, index) => {
    const x = startX + index * 6;
    const y = 218 - height / 2;
    return `<rect x="${x}" y="${y}" width="3" height="${height}" rx="1.5" fill="#00D9FF" opacity="0.3"/>`;
  }).join("");
}

function makeNoiseDots() {
  const dots = [
    [24, 96, 0.04],
    [62, 400, 0.035],
    [104, 520, 0.05],
    [142, 42, 0.04],
    [192, 120, 0.035],
    [238, 334, 0.05],
    [286, 248, 0.03],
    [324, 548, 0.045],
    [318, 72, 0.035],
    [36, 572, 0.04],
    [82, 238, 0.035],
    [212, 594, 0.03],
  ];

  return dots
    .map(
      ([x, y, opacity]) =>
        `<circle cx="${x}" cy="${y}" r="0.7" fill="#FFFFFF" opacity="${opacity}"/>`
    )
    .join("");
}

function splitTitleLines(title: string) {
  const cleanedTitle = title.trim() || "识别结果";
  const characters = [...cleanedTitle];

  if (characters.length <= 12) return [cleanedTitle];

  return [
    characters.slice(0, 12).join(""),
    truncateText(characters.slice(12).join(""), 12),
  ];
}

function truncateText(value: string, maxLength: number) {
  const characters = [...value.trim()];
  if (characters.length <= maxLength) return characters.join("");
  return `${characters.slice(0, Math.max(maxLength - 1, 0)).join("")}…`;
}

function readShareCardArtworkDataUrl(data: ShareCardData) {
  if (data.artworkDataUrl?.startsWith("data:image/")) {
    return data.artworkDataUrl;
  }

  return data.artworkUrl?.startsWith("data:image/") ? data.artworkUrl : null;
}

export function formatReleaseMemory(
  releaseDate: ShareCardData["releaseDate"],
  referenceDate: Date = new Date()
) {
  const parsedReleaseDate = parseReleaseDate(releaseDate);
  if (!parsedReleaseDate) return null;

  const reference = Number.isNaN(referenceDate.getTime())
    ? new Date()
    : referenceDate;
  const releaseYear = parsedReleaseDate.getFullYear();
  const elapsedYears = countFullYearsBetween(parsedReleaseDate, reference);
  const memory = elapsedYears > 0 ? `${elapsedYears}年前` : "今年";

  return `发行于 ${releaseYear} · ${memory}`;
}

function parseReleaseDate(value: ShareCardData["releaseDate"]) {
  if (!value) return null;

  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }

  const trimmed = value.trim();
  if (!trimmed) return null;

  const dateMatch = trimmed.match(/^(\d{4})(?:[-/](\d{2})(?:[-/](\d{2}))?)?/);
  if (dateMatch) {
    const year = Number(dateMatch[1]);
    const month = Number(dateMatch[2] ?? "01") - 1;
    const day = Number(dateMatch[3] ?? "01");
    const date = new Date(year, month, day);
    return Number.isNaN(date.getTime()) ? null : date;
  }

  const parsed = new Date(trimmed);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function countFullYearsBetween(start: Date, end: Date) {
  let years = end.getFullYear() - start.getFullYear();
  const hasHadAnniversary =
    end.getMonth() > start.getMonth() ||
    (end.getMonth() === start.getMonth() && end.getDate() >= start.getDate());

  if (!hasHadAnniversary) years -= 1;

  return Math.max(years, 0);
}

function escapeSvg(value: string) {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function formatShareDate(date: Date) {
  const year = date.getFullYear();
  const month = padDatePart(date.getMonth() + 1);
  const day = padDatePart(date.getDate());
  const hours = padDatePart(date.getHours());
  const minutes = padDatePart(date.getMinutes());

  return `${year}.${month}.${day} ${hours}:${minutes}`;
}

function padDatePart(value: number) {
  return String(value).padStart(2, "0");
}

function sanitizeFileName(value: string) {
  return value.trim().replace(/[\\/:*?"<>|]+/g, "-").slice(0, 48) || "拾音FM分享图";
}
