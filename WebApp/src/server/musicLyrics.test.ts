import type { SongCandidate } from "@/features/recognition/recognitionTypes";
import { describe, expect, it, vi } from "vitest";
import {
  fetchSyncedLyricsForCandidates,
  fetchSyncedLyricsVersionsForCandidates,
} from "./musicLyrics";

const candidate: SongCandidate = {
  id: "113373",
  title: "爱在记忆中找你",
  artist: "林峯",
  source: "netease",
  url: "https://music.163.com/song?id=113373",
  matchedSnippet: "可以恨你 全力痛恨你 连遇上亦要躲避",
  confidenceScore: 0.95,
};

const snippets = [
  {
    text: "可以恨你 全力痛恨你 连遇上亦要躲避",
    start: 2,
    confidenceScore: 0.95,
  },
];

describe("musicLyrics", () => {
  it("fetches synced lyrics from QQ Music before trying NetEase", async () => {
    const fetchImpl = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            req_1: {
              code: 0,
              data: {
                body: {
                  song: {
                    list: [
                      {
                        mid: "003hAqji4DQa0x",
                        title: "爱在记忆中找你",
                        singer: [{ name: "林峯" }],
                      },
                    ],
                  },
                },
              },
            },
          })
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            lyric:
              "[00:10.00]可以恨你 全力痛恨你\n[00:13.50]连遇上亦要躲避",
          })
        )
      );

    const lyrics = await fetchSyncedLyricsForCandidates([candidate], snippets, {
      fetchImpl,
    });

    expect(lyrics).toMatchObject({
      source: "qq",
      estimatedOffsetSeconds: 8,
      matchedCandidate: { id: "113373", title: "爱在记忆中找你" },
      platformSongIds: { qq: "003hAqji4DQa0x", netease: "113373" },
    });
    expect(lyrics?.lines[0]).toMatchObject({
      text: "可以恨你 全力痛恨你",
    });
    expect(fetchImpl).toHaveBeenCalledTimes(2);
    expect(String(fetchImpl.mock.calls[0]?.[0])).toBe(
      "https://u.y.qq.com/cgi-bin/musicu.fcg"
    );
  });

  it("fetches lyrics directly for QQ Music candidates found by lyric search", async () => {
    const qqCandidate: SongCandidate = {
      id: "001L1lqm4UAdyo",
      title: "退后",
      artist: "周杰伦",
      album: "依然范特西",
      source: "qq",
      url: "https://y.qq.com/n/ryqq/songDetail/001L1lqm4UAdyo",
      matchedSnippet: "天空灰得像哭过 离开你以后并没有更自由",
      confidenceScore: 0.94,
    };
    const fetchImpl = vi.fn(async () =>
      new Response(
        JSON.stringify({
          lyric: "[00:10.00]天空灰得像哭过\n[00:14.00]离开你以后并没有更自由",
        })
      )
    );

    const lyrics = await fetchSyncedLyricsForCandidates(
      [qqCandidate],
      [
        {
          text: "天空灰得像哭过 离开你以后并没有更自由",
          start: 2,
          confidenceScore: 0.94,
        },
      ],
      { fetchImpl }
    );

    expect(lyrics).toMatchObject({
      source: "qq",
      matchedCandidate: qqCandidate,
      platformSongIds: { qq: "001L1lqm4UAdyo" },
      lines: [
        { text: "天空灰得像哭过" },
        { text: "离开你以后并没有更自由" },
      ],
    });
    expect(fetchImpl).toHaveBeenCalledTimes(1);
    expect(String(fetchImpl.mock.calls[0]?.[0])).toContain(
      "songmid=001L1lqm4UAdyo"
    );
  });

  it("enriches direct QQ candidates with release dates from classic search", async () => {
    const qqCandidate: SongCandidate = {
      id: "002LShag2hMouS",
      title: "勇",
      artist: "杨千嬅",
      album: "RECOLLECTION, VOL. I - MY Harmonic Minor",
      artworkUrl:
        "https://y.gtimg.cn/music/photo_new/T002R300x300M000004J5g461SAjbR.jpg?max_age=2592000",
      source: "qq",
      url: "https://y.qq.com/n/ryqq/songDetail/002LShag2hMouS",
      matchedSnippet: "沿途红灯再红 无人可挡我路",
      confidenceScore: 0.94,
    };
    const fetchImpl = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);

      if (url.includes("search_for_qq_cp")) {
        return new Response(
          JSON.stringify({
            code: 0,
            data: {
              song: {
                list: [
                  {
                    songmid: "002LShag2hMouS",
                    songname: "勇",
                    singer: [{ name: "杨千嬅" }],
                    albumname: "RECOLLECTION, VOL. I - MY Harmonic Minor",
                    albummid: "004J5g461SAjbR",
                    pubtime: 1762099200,
                  },
                ],
              },
            },
          })
        );
      }

      if (url.includes("fcg_query_lyric_new.fcg")) {
        return new Response(
          JSON.stringify({
            lyric: "[00:20.00]沿途红灯再红\n[00:24.00]无人可挡我路",
          })
        );
      }

      return new Response("{}", { status: 404 });
    });

    const lyrics = await fetchSyncedLyricsForCandidates(
      [qqCandidate],
      [{ text: "沿途红灯再红 无人可挡我路", confidenceScore: 0.94 }],
      { fetchImpl }
    );

    expect(lyrics).toMatchObject({
      source: "qq",
      matchedCandidate: {
        id: "002LShag2hMouS",
        title: "勇",
        artist: "杨千嬅",
        album: "RECOLLECTION, VOL. I - MY Harmonic Minor",
        releaseDate: "2025-11-03",
        source: "qq",
      },
      platformSongIds: { qq: "002LShag2hMouS" },
    });
    expect(fetchImpl.mock.calls.map((call) => String(call[0]))).toEqual([
      expect.stringContaining("search_for_qq_cp"),
      expect.stringContaining("fcg_query_lyric_new.fcg"),
    ]);
  });

  it("uses QQ Music metadata for the displayed version when QQ finds the exact song but the NetEase candidate artist is wrong", async () => {
    const fetchImpl = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            req_1: {
              code: 0,
              data: {
                body: {
                  song: {
                    list: [
                      {
                        mid: "004TempleSong",
                        title: "庙堂之外",
                        singer: [{ name: "陈楚生" }],
                        album: {
                          name: "长安的荔枝原声带",
                          mid: "003TempleAlbum",
                          time_public: "2025-07-18",
                        },
                      },
                    ],
                  },
                },
              },
            },
          })
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            lyric:
              "[00:10.00]庙堂之外《长安的荔枝》电影片尾曲 - 陈楚生\n[00:20.00]万家灯火映山河",
          })
        )
      );

    const versions = await fetchSyncedLyricsVersionsForCandidates(
      [
        {
          ...candidate,
          id: "wrong-net-ease-id",
          title: "庙堂之外",
          artist: "说晚安",
          album: "陈楚生南京演唱会",
          confidenceScore: 0.92,
        },
      ],
      [{ text: "万家灯火映山河", confidenceScore: 0.92 }],
      { fetchImpl }
    );

    expect(versions[0]).toMatchObject({
      id: "qq:004TempleSong",
      candidate: {
        id: "004TempleSong",
        title: "庙堂之外",
        artist: "陈楚生",
        album: "长安的荔枝原声带",
        artworkUrl:
          "https://y.gtimg.cn/music/photo_new/T002R300x300M000003TempleAlbum.jpg?max_age=2592000",
        releaseDate: "2025-07-18",
        source: "qq",
      },
      lyrics: {
        matchedCandidate: {
          id: "004TempleSong",
          title: "庙堂之外",
          artist: "陈楚生",
          album: "长安的荔枝原声带",
          artworkUrl:
            "https://y.gtimg.cn/music/photo_new/T002R300x300M000003TempleAlbum.jpg?max_age=2592000",
          releaseDate: "2025-07-18",
          source: "qq",
        },
        platformSongIds: { qq: "004TempleSong" },
      },
    });
  });

  it("rejects title-only QQ matches for different artists so Cantonese covers do not show the Mandarin original lyrics", async () => {
    const fetchImpl = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);

      if (url === "https://u.y.qq.com/cgi-bin/musicu.fcg") {
        return new Response(
          JSON.stringify({
            req_1: {
              code: 0,
              data: {
                body: {
                  song: {
                    list: [
                      {
                        mid: "001MandarinFire",
                        title: "过火",
                        singer: [{ name: "张信哲" }],
                        album: { name: "宽容" },
                      },
                    ],
                  },
                },
              },
            },
          })
        );
      }

      if (url.includes("fcg_query_lyric_new.fcg")) {
        return new Response(
          JSON.stringify({
            lyric:
              "[00:00.00]过火 - 张信哲 (Jeff Chang)\n[00:15.00]是否对你承诺了太多\n[00:20.00]还是我原本给的就不够",
          })
        );
      }

      if (url.includes("music.163.com/api/song/lyric?id=fire-cantonese")) {
        return new Response(
          JSON.stringify({
            lrc: {
              lyric:
                "[00:12.00]粤语正确一句\n[00:16.00]这刻心火仍然未停",
            },
          })
        );
      }

      return new Response("{}", { status: 404 });
    });

    const lyrics = await fetchSyncedLyricsForCandidates(
      [
        {
          ...candidate,
          id: "fire-cantonese",
          title: "过火（粤语）",
          artist: "祝赞",
          album: "粤语金曲2",
          confidenceScore: 0.95,
        },
      ],
      [{ text: "粤语正确一句", confidenceScore: 0.95 }],
      { fetchImpl }
    );

    expect(lyrics).toMatchObject({
      source: "netease",
      matchedCandidate: {
        id: "fire-cantonese",
        title: "过火（粤语）",
        artist: "祝赞",
      },
      platformSongIds: { netease: "fire-cantonese" },
      lines: [{ text: "粤语正确一句" }, { text: "这刻心火仍然未停" }],
    });
    expect(
      fetchImpl.mock.calls.some((call) =>
        String(call[0]).includes("fcg_query_lyric_new.fcg")
      )
    ).toBe(false);
  });

  it("falls back to NetEase lyrics when QQ has no matching song", async () => {
    const fetchImpl = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            req_1: { code: 0, data: { body: { song: { list: [] } } } },
          })
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            code: 0,
            data: { song: { list: [] } },
          })
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            lrc: {
              lyric:
                "[00:10.00]可以恨你 全力痛恨你\n[00:13.50]连遇上亦要躲避",
            },
          })
        )
      );

    const lyrics = await fetchSyncedLyricsForCandidates([candidate], snippets, {
      fetchImpl,
    });

    expect(lyrics).toMatchObject({
      source: "netease",
      estimatedOffsetSeconds: 8,
      matchedCandidate: { id: "113373", title: "爱在记忆中找你" },
      platformSongIds: { netease: "113373" },
    });
    expect(String(fetchImpl.mock.calls[2]?.[0])).toContain(
      "https://music.163.com/api/song/lyric?id=113373"
    );
  });

  it("uses QQ classic search when desktop search misses a known title and artist", async () => {
    const fetchImpl = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);

      if (url === "https://u.y.qq.com/cgi-bin/musicu.fcg") {
        return new Response(
          JSON.stringify({
            req_1: { code: 0, data: { body: { song: { list: [] } } } },
          })
        );
      }

      if (url.includes("search_for_qq_cp")) {
        return new Response(
          JSON.stringify({
            code: 0,
            data: {
              song: {
                list: [
                  {
                    songmid: "003z7r3M1WqtFX",
                    songname: "双城记",
                    singer: [{ name: "徐小凤" }],
                    albumname: "一生所爱",
                    albummid: "000o8Dxo48vhk6",
                    pubtime: 652633200,
                  },
                ],
              },
            },
          })
        );
      }

      if (url.includes("fcg_query_lyric_new.fcg")) {
        return new Response(
          JSON.stringify({
            lyric:
              "[00:17.76]你可知默默又一年\n[00:23.43]沉默里盼望你我依然",
          })
        );
      }

      return new Response("{}", { status: 404 });
    });

    const lyrics = await fetchSyncedLyricsForCandidates(
      [
        {
          ...candidate,
          id: "netease-double-city",
          title: "双城记",
          artist: "徐小凤",
          album: "徐小凤的故事",
          confidenceScore: 0.92,
        },
      ],
      [{ text: "你可知默默又一年 沉默里盼望你我依然", confidenceScore: 0.92 }],
      { fetchImpl }
    );

    expect(lyrics).toMatchObject({
      source: "qq",
      matchedCandidate: {
        id: "netease-double-city",
        title: "双城记",
        artist: "徐小凤",
        album: "徐小凤的故事",
        source: "netease",
      },
      platformSongIds: {
        qq: "003z7r3M1WqtFX",
        netease: "netease-double-city",
      },
      lines: [{ text: "你可知默默又一年" }, { text: "沉默里盼望你我依然" }],
    });
    expect(fetchImpl.mock.calls.map((call) => String(call[0]))).toEqual([
      "https://u.y.qq.com/cgi-bin/musicu.fcg",
      expect.stringContaining("search_for_qq_cp"),
      expect.stringContaining("fcg_query_lyric_new.fcg"),
    ]);
  });

  it("shows timed lyrics for high-confidence candidates even when ASR cannot estimate an offset", async () => {
    const fetchImpl = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            req_1: {
              code: 0,
              data: {
                body: {
                  song: {
                    list: [
                      {
                        mid: "000TEOWt4QMeLl",
                        title: "一时的选择",
                        singer: [{ name: "林俊杰" }],
                      },
                    ],
                  },
                },
              },
            },
          })
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            lyric:
              "[00:15.01]转眼天要亮了 我还辗转反侧\n[00:21.89]被放大的情绪 跟谁讲呢",
          })
        )
      );

    const lyrics = await fetchSyncedLyricsForCandidates(
      [
        {
          ...candidate,
          id: "2039156375",
          title: "一时的选择",
          artist: "林俊杰",
          album: "重拾_快乐",
          confidenceScore: 0.82,
        },
      ],
      [{ text: "一时的选择 林俊杰", confidenceScore: 0.8 }],
      { fetchImpl }
    );

    expect(lyrics).toMatchObject({
      source: "qq",
      matchedCandidate: { title: "一时的选择", artist: "林俊杰" },
      platformSongIds: { qq: "000TEOWt4QMeLl", netease: "2039156375" },
    });
    expect(lyrics?.lines[0]).toMatchObject({
      text: "转眼天要亮了 我还辗转反侧",
    });
    expect(lyrics?.estimatedOffsetSeconds).toBeUndefined();
  });

  it("keeps unmatched timed lyrics hidden for low-confidence candidates", async () => {
    const fetchImpl = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            req_1: {
              code: 0,
              data: {
                body: {
                  song: {
                    list: [
                      {
                        mid: "000TEOWt4QMeLl",
                        title: "一时的选择",
                        singer: [{ name: "林俊杰" }],
                      },
                    ],
                  },
                },
              },
            },
          })
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            lyric:
              "[00:15.01]转眼天要亮了 我还辗转反侧\n[00:21.89]被放大的情绪 跟谁讲呢",
          })
        )
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            lrc: {
              lyric:
                "[00:15.01]转眼天要亮了 我还辗转反侧\n[00:21.89]被放大的情绪 跟谁讲呢",
            },
          })
        )
      );

    const lyrics = await fetchSyncedLyricsForCandidates(
      [
        {
          ...candidate,
          id: "2039156375",
          title: "一时的选择",
          artist: "林俊杰",
          album: "重拾_快乐",
          confidenceScore: 0.5,
        },
      ],
      [{ text: "一时的选择 林俊杰", confidenceScore: 0.8 }],
      { fetchImpl }
    );

    expect(lyrics).toBeNull();
  });

  it("returns lyrics for multiple ambiguous versions so the user can choose", async () => {
    const tanCandidate: SongCandidate = {
      id: "100",
      title: "一生中最爱",
      artist: "谭咏麟",
      album: "神话1991",
      source: "netease",
      url: "https://music.163.com/song?id=100",
      matchedSnippet: "如果痴痴的等某日",
      confidenceScore: 0.95,
      metadataScore: 1,
    };
    const liCandidate: SongCandidate = {
      id: "200",
      title: "一生中最爱",
      artist: "李健",
      album: "我是歌手",
      source: "netease",
      url: "https://music.163.com/song?id=200",
      matchedSnippet: "如果痴痴的等某日",
      confidenceScore: 0.95,
      popularityScore: 1,
    };
    const fetchImpl = vi
      .fn()
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ req_1: { data: { body: { song: { list: [] } } } } }))
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ data: { song: { list: [] } } }))
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            lrc: { lyric: "[00:12.00]如果痴痴的等某日\n[00:18.00]谭咏麟版本" },
          })
        )
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ req_1: { data: { body: { song: { list: [] } } } } }))
      )
      .mockResolvedValueOnce(
        new Response(JSON.stringify({ data: { song: { list: [] } } }))
      )
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            lrc: { lyric: "[00:12.00]如果痴痴的等某日\n[00:18.00]李健版本" },
          })
        )
      );

    const versions = await fetchSyncedLyricsVersionsForCandidates(
      [tanCandidate, liCandidate],
      [{ text: "如果痴痴的等某日", confidenceScore: 0.9 }],
      { fetchImpl }
    );

    expect(versions.map((version) => version.candidate.artist)).toEqual([
      "谭咏麟",
      "李健",
    ]);
    expect(versions[0]).toMatchObject({
      id: "netease:100",
      lyrics: {
        matchedCandidate: { artist: "谭咏麟" },
        lines: [{ text: "如果痴痴的等某日" }, { text: "谭咏麟版本" }],
      },
    });
    expect(versions[1]?.lyrics.lines[1]).toMatchObject({ text: "李健版本" });
  });

  it("uses the strongest lyric alignment as the default version", async () => {
    const weakAlignmentCandidate: SongCandidate = {
      id: "001jclku27yMhP",
      title: "我生君未生 君生我已老",
      artist: "凯紫",
      source: "qq",
      url: "https://y.qq.com/n/ryqq/songDetail/001jclku27yMhP",
      matchedSnippet: "轻声阵阵飘渺红尘",
      confidenceScore: 0.8,
      popularityScore: 1,
    };
    const strongAlignmentCandidate: SongCandidate = {
      id: "001RYNBo3AK8pp",
      title: "渡红尘",
      artist: "张碧晨",
      source: "qq",
      url: "https://y.qq.com/n/ryqq/songDetail/001RYNBo3AK8pp",
      matchedSnippet: "我用千年的情深",
      confidenceScore: 0.8,
      popularityScore: 1,
    };
    const fetchImpl = vi.fn(async (input: RequestInfo | URL) => {
      const url = String(input);

      if (url.includes("songmid=001jclku27yMhP")) {
        return new Response(
          JSON.stringify({
            lyric:
              "[04:55.34]放眼孤城几声哀头走去人问琴声阵阵\n[05:02.88]飘渺红尘\n[05:07.22]我用千年的今生",
          })
        );
      }

      if (url.includes("songmid=001RYNBo3AK8pp")) {
        return new Response(
          JSON.stringify({
            lyric:
              "[00:55.35]飘渺红尘\n[01:00.35]我用千年的情深\n[01:03.49]即使修炼这一生",
          })
        );
      }

      return new Response("{}", { status: 404 });
    });

    const versions = await fetchSyncedLyricsVersionsForCandidates(
      [weakAlignmentCandidate, strongAlignmentCandidate],
      [
        { text: "轻声阵阵飘渺红尘", start: 3, confidenceScore: 0.8 },
        { text: "我用千年的情深", start: 8, confidenceScore: 0.8 },
        { text: "即使修炼这一生", start: 12, confidenceScore: 0.8 },
      ],
      { fetchImpl }
    );

    expect(versions.map((version) => version.candidate.title)).toEqual([
      "渡红尘",
      "我生君未生 君生我已老",
    ]);
    expect(versions[0]).toMatchObject({
      candidate: { title: "渡红尘", artist: "张碧晨" },
      lyrics: {
        matchedSnippet: "我用千年的情深",
        confidenceScore: expect.closeTo(0.97, 2),
        estimatedOffsetSeconds: expect.closeTo(52.35, 2),
      },
    });
  });
});
