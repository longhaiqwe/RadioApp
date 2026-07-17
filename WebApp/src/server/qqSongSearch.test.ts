import { describe, expect, it, vi } from "vitest";
import { searchQQSongCandidates } from "./qqSongSearch";

describe("qqSongSearch", () => {
  it("searches QQ Music with lyric snippets and returns the original domestic song first", async () => {
    const fetchImpl = vi.fn(async () =>
      new Response(
        JSON.stringify({
          req_1: {
            data: {
              body: {
                song: {
                  list: [
                    {
                      mid: "001L1lqm4UAdyo",
                      title: "退后",
                      singer: [{ name: "周杰伦" }],
                      album: {
                        name: "依然范特西",
                        mid: "002jLGWe16Tf1H",
                        time_public: "2006-09-05",
                      },
                    },
                    {
                      mid: "0044OEUM3Hx8oc",
                      title: "天空灰的像哭过 离开你以后",
                      singer: [{ name: "白允y" }],
                    },
                  ],
                },
              },
            },
          },
        })
      )
    );

    const candidates = await searchQQSongCandidates(
      [
        {
          text: "天空灰得像哭过 离开你以后并没有更自由",
          confidenceScore: 0.94,
        },
      ],
      { fetchImpl }
    );

    expect(candidates[0]).toMatchObject({
      id: "001L1lqm4UAdyo",
      title: "退后",
      artist: "周杰伦",
      album: "依然范特西",
      artworkUrl:
        "https://y.gtimg.cn/music/photo_new/T002R300x300M000002jLGWe16Tf1H.jpg?max_age=2592000",
      releaseDate: "2006-09-05",
      source: "qq",
      matchedSnippet: "天空灰得像哭过 离开你以后并没有更自由",
      confidenceScore: 0.94,
    });
    expect(String(fetchImpl.mock.calls[0]?.[0])).toBe(
      "https://u.y.qq.com/cgi-bin/musicu.fcg"
    );
    expect(JSON.parse(String(fetchImpl.mock.calls[0]?.[1]?.body))).toMatchObject({
      req_1: {
        param: {
          query: "天空灰得像哭过 离开你以后并没有更自由",
          search_type: 0,
        },
      },
    });
  });
});
