type MusicPlatform = "netease" | "qq";

type MusicPlatformTargetsInput = {
  platform: MusicPlatform;
  songId?: string | null;
  title: string;
  artist: string;
};

type MusicPlatformTargets = {
  primaryHref: string;
  fallbackHref: string;
};

export function makeMusicPlatformTargets({
  platform,
  songId,
  title,
  artist,
}: MusicPlatformTargetsInput): MusicPlatformTargets | null {
  const query = makeQuery(title, artist);
  if (!query) return null;

  const normalizedSongId = normalizeSongId(songId);
  if (normalizedSongId) {
    return {
      primaryHref: appSongHref(platform, normalizedSongId),
      fallbackHref: webSongHref(platform, normalizedSongId),
    };
  }

  return {
    primaryHref: appSearchHref(platform, query),
    fallbackHref: webSearchHref(platform, query),
  };
}

function makeQuery(title: string, artist: string) {
  const safeTitle = title.trim();
  const safeArtist = artist.trim();
  if (!safeTitle) return null;

  const query =
    !safeArtist || safeArtist === "未知歌手" ? safeTitle : `${safeTitle} ${safeArtist}`;
  return encodeURIComponent(query);
}

function normalizeSongId(songId?: string | null) {
  const trimmedSongId = songId?.trim() ?? "";
  return trimmedSongId.length > 0 ? trimmedSongId : null;
}

function appSongHref(platform: MusicPlatform, songId: string) {
  if (platform === "netease") return `orpheus://song/${encodeURIComponent(songId)}`;

  const payload = encodeURIComponent(
    JSON.stringify({
      song: [{ type: "0", songmid: songId }],
      action: "play",
    })
  );
  return `qqmusic://qq.com/media/playSonglist?p=${payload}`;
}

function webSongHref(platform: MusicPlatform, songId: string) {
  if (platform === "netease") {
    return `https://music.163.com/#/song?id=${encodeURIComponent(songId)}`;
  }

  return `https://y.qq.com/n/ryqq/songDetail/${encodeURIComponent(songId)}`;
}

function appSearchHref(platform: MusicPlatform, query: string) {
  if (platform === "netease") return `orpheus://search?keyword=${query}&type=1`;

  return `qqmusic://qq.com/ui/search?w=${query}`;
}

function webSearchHref(platform: MusicPlatform, query: string) {
  if (platform === "netease") {
    return `https://music.163.com/#/search/m/?s=${query}&type=1`;
  }

  return `https://y.qq.com/n/ryqq/search?w=${query}`;
}
