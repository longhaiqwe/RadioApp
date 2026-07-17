import { describe, expect, it, vi } from "vitest";
import {
  makeNetEaseSongSearchRequest,
  parseNetEaseSongSearchResponse,
  searchNetEaseSongCandidates,
} from "./neteaseSongSearch";

describe("neteaseSongSearch", () => {
  it("creates a NetEase cloudsearch request for lyric snippets", () => {
    const request = makeNetEaseSongSearchRequest("我怀念的是无话不说", 6);

    expect(request.url).toBe(
      "https://music.163.com/api/cloudsearch/pc?s=%E6%88%91%E6%80%80%E5%BF%B5%E7%9A%84%E6%98%AF%E6%97%A0%E8%AF%9D%E4%B8%8D%E8%AF%B4&type=1006&offset=0&limit=6"
    );
    expect(request.headers.get("Referer")).toBe("https://music.163.com/");
  });

  it("normalizes NetEase song search results", () => {
    const songs = parseNetEaseSongSearchResponse({
      result: {
        songs: [
          {
            id: 123,
            name: "我怀念的",
            artists: [{ name: "孙燕姿" }],
            album: {
              name: "逆光",
              picUrl: "http://p1.music.126.net/album.jpg",
              publishTime: 1177603200000,
            },
          },
        ],
      },
    });

    expect(songs).toEqual([
      {
        id: "123",
        title: "我怀念的",
        artist: "孙燕姿",
        album: "逆光",
        artworkUrl: "https://p1.music.126.net/album.jpg?param=300y300",
        releaseDate: "2007-04-27",
        source: "netease",
        url: "https://music.163.com/song?id=123",
      },
    ]);
  });

  it("requests compact NetEase artwork so share cards do not embed huge album files", () => {
    const songs = parseNetEaseSongSearchResponse({
      result: {
        songs: [
          {
            id: 190532,
            name: "小小的太阳",
            artists: [{ name: "张宇" }],
            album: {
              name: "月亮 太阳",
              picUrl:
                "http://p1.music.126.net/2SKyO_NjdYOdsmLiqUyPhQ==/109951167893538409.jpg",
            },
          },
        ],
      },
    });

    expect(songs[0]?.artworkUrl).toBe(
      "https://p1.music.126.net/2SKyO_NjdYOdsmLiqUyPhQ==/109951167893538409.jpg?param=300y300"
    );
  });

  it("dedupes lyric candidates across snippets while preserving the strongest match", async () => {
    const fetchImpl = vi.fn(async () =>
      new Response(
        JSON.stringify({
          result: {
            songs: [
              {
                id: 123,
                name: "我怀念的",
                artists: [{ name: "孙燕姿" }],
                album: { name: "逆光" },
                lyrics: [
                  "<b>我怀念的 是无话不说</b>",
                  "<b>我怀念的 是一起做梦</b>",
                ],
              },
            ],
          },
        })
      )
    );

    const candidates = await searchNetEaseSongCandidates(
      [
        { text: "我怀念的是无话不说", confidenceScore: 0.82 },
        { text: "我怀念的是一起做梦", confidenceScore: 0.76 },
      ],
      { fetchImpl }
    );

    expect(fetchImpl).toHaveBeenCalledTimes(2);
    expect(candidates).toEqual([
      {
        id: "123",
        title: "我怀念的",
        artist: "孙燕姿",
        album: "逆光",
        source: "netease",
        url: "https://music.163.com/song?id=123",
        matchedSnippet: "我怀念的是无话不说",
        confidenceScore: 0.82,
        popularityScore: 0,
      },
    ]);
  });

  it("matches snippets across adjacent lyric lines and ranks popular originals first", async () => {
    const fetchImpl = vi.fn(async () =>
      new Response(
        JSON.stringify({
          result: {
            songs: [
              {
                id: 456,
                name: "爱在记忆中找李",
                artists: [{ name: "李无悔" }],
                album: { name: "爱在记忆中找李" },
                pop: 20,
                lyrics: ["可以恨你 全力痛恨你", "连遇上亦要躲避"],
              },
              {
                id: 113373,
                name: "爱在记忆中找你",
                artists: [{ name: "林峯" }],
                album: { name: "爱在记忆中找你" },
                pop: 100,
                lyrics: ["可以恨你 全力痛恨你", "连遇上亦要躲避"],
              },
            ],
          },
        })
      )
    );

    const candidates = await searchNetEaseSongCandidates(
      [
        {
          text: "如何可以恨你 全力痛恨你 連遇上亦要躲避",
          confidenceScore: 0.9,
        },
      ],
      { fetchImpl }
    );

    expect(candidates.map((candidate) => candidate.title)).toEqual([
      "爱在记忆中找你",
      "爱在记忆中找李",
    ]);
    expect(candidates[0]).toMatchObject({
      artist: "林峯",
      popularityScore: 1,
    });
  });

  it("uses stream metadata to prefer the currently playing artist over a hotter cover", async () => {
    const fetchImpl = vi.fn(async () =>
      new Response(
        JSON.stringify({
          result: {
            songs: [
              {
                id: 200,
                name: "一生中最爱",
                artists: [{ name: "李健" }],
                album: { name: "我是歌手" },
                pop: 100,
                lyrics: ["如果痴痴的等某日", "终于可等到一生中最爱"],
              },
              {
                id: 100,
                name: "一生中最爱",
                artists: [{ name: "谭咏麟" }],
                album: { name: "神话1991" },
                pop: 60,
                lyrics: ["如果痴痴的等某日", "终于可等到一生中最爱"],
              },
            ],
          },
        })
      )
    );

    const candidates = await searchNetEaseSongCandidates(
      [{ text: "如果痴痴的等某日 终于可等到一生中最爱", confidenceScore: 0.95 }],
      {
        fetchImpl,
        trackMetadata: {
          rawTitle: "谭咏麟 - 一生中最爱",
          artist: "谭咏麟",
          title: "一生中最爱",
        },
      }
    );

    expect(candidates.map((candidate) => candidate.artist)).toEqual([
      "谭咏麟",
      "李健",
    ]);
    expect(candidates[0]).toMatchObject({
      title: "一生中最爱",
      metadataScore: 1,
    });
  });

  it("dedupes alternate releases with the same title and artist", async () => {
    const fetchImpl = vi.fn(async () =>
      new Response(
        JSON.stringify({
          result: {
            songs: [
              {
                id: 113373,
                name: "爱在记忆中找你",
                artists: [{ name: "林峯" }],
                album: { name: "爱在记忆中找你" },
                pop: 100,
                lyrics: ["无非想放下你 还是挂念你"],
              },
              {
                id: 5252465,
                name: "爱在记忆中找你",
                artists: [{ name: "林峯" }],
                album: { name: "好歌典范" },
                pop: 80,
                lyrics: ["无非想放下你 还是挂念你"],
              },
            ],
          },
        })
      )
    );

    const candidates = await searchNetEaseSongCandidates(
      [{ text: "無非想放下你 還是掛念你", confidenceScore: 0.95 }],
      { fetchImpl }
    );

    expect(candidates).toHaveLength(1);
    expect(candidates[0]).toMatchObject({
      id: "113373",
      title: "爱在记忆中找你",
      popularityScore: 1,
    });
  });

  it("does not surface regular song matches without lyric evidence", async () => {
    const fetchImpl = vi.fn(async () =>
      new Response(
        JSON.stringify({
          result: {
            songs: [
              {
                id: 3392309648,
                name: "分手",
                artists: [{ name: "青龙环宇" }],
                album: { name: "分手" },
              },
            ],
          },
        })
      )
    );

    const candidates = await searchNetEaseSongCandidates(
      [
        {
          text: "最多一次最多一次 得分手 等最后以次白头 爱多一次痛",
          confidenceScore: 0.7,
        },
      ],
      { fetchImpl }
    );

    expect(candidates).toEqual([]);
  });
});
