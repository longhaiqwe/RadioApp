import { describe, expect, it } from "vitest";
import {
  buildOpenRouterLyricsRequest,
  extractLikelyLyricSnippets,
  parseOpenRouterLyricsResponse,
} from "./openRouterLyrics";

describe("openRouterLyrics", () => {
  it("builds the multimodal lyrics extraction request without exposing secrets in payload", () => {
    const request = buildOpenRouterLyricsRequest({
      apiKey: "sk-test",
      audioBase64: "UklGRg==",
      model: "xiaomi/mimo-v2.5",
      languageHint: "zh",
    });

    expect(request.url).toBe("https://openrouter.ai/api/v1/chat/completions");
    expect(request.init.headers).toMatchObject({
      Authorization: "Bearer sk-test",
      "Content-Type": "application/json",
    });
    expect(JSON.stringify(request.body)).toContain("xiaomi/mimo-v2.5");
    expect(JSON.stringify(request.body)).toContain("input_audio");
    expect(JSON.stringify(request.body)).toContain("Likely language: zh.");
    expect(JSON.stringify(request.body)).not.toContain("sk-test");
  });

  it("uses fetch-safe ASCII headers for OpenRouter requests", () => {
    const request = buildOpenRouterLyricsRequest({
      apiKey: "sk-test",
      audioBase64: "UklGRg==",
      model: "xiaomi/mimo-v2.5",
    });

    expect(() => new Headers(request.init.headers)).not.toThrow();
    expect(request.init.headers).toMatchObject({
      "X-OpenRouter-Title": "Shiyin FM Web",
    });
  });

  it("parses fenced JSON model output and extracts unique useful lyric snippets", () => {
    const transcription = parseOpenRouterLyricsResponse({
      choices: [
        {
          message: {
            content:
              "```json\n{\"transcript\":\"我怀念的是无话不说 我怀念的是一起做梦\",\"snippets\":[{\"text\":\"我怀念的是无话不说\",\"start_seconds\":1.2,\"end_seconds\":4.5,\"confidence\":0.83},{\"text\":\"DJ: 欢迎收听\",\"confidence\":0.95},{\"text\":\"我怀念的是无话不说\",\"confidence\":0.7}]}\n```",
          },
        },
      ],
    });

    expect(transcription.text).toBe("我怀念的是无话不说 我怀念的是一起做梦");
    expect(extractLikelyLyricSnippets(transcription)).toEqual([
      {
        text: "我怀念的是无话不说",
        start: 1.2,
        end: 4.5,
        confidenceScore: 0.83,
      },
    ]);
  });
});
