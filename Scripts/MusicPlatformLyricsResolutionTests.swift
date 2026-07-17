import Foundation

struct LyricSnippet: Hashable, Sendable {
    let text: String
    let start: TimeInterval?
    let end: TimeInterval?
    let confidenceScore: Double
}

@main
struct MusicPlatformLyricsResolutionTests {
    static func main() async {
        await testMovieSuffixTypoSkipsInstrumentalPlaceholderAndFindsTimedLyrics()
        await testEnglishAliasTitleWithChineseArtistAnchorResolvesChineseMetadata()
        print("MusicPlatformLyricsResolutionTests passed")
    }

    private static func testMovieSuffixTypoSkipsInstrumentalPlaceholderAndFindsTimedLyrics() async {
        let lyrics = await MusicPlatformService.shared.fetchLyrics(
            title: "一起走过的日子 (电影《尊无上II之永霸天下》歌曲)",
            artist: "刘德华"
        )

        guard let lyrics else {
            fatalError("Expected lyrics for 刘德华《一起走过的日子》")
        }

        let lines = LRCParser.parse(lrc: lyrics)
        guard lines.count >= 8 else {
            fatalError(
                """
                Expected timed lyric lines, but got \(lines.count).
                Raw lyrics prefix: \(String(lyrics.prefix(120)))
                """
            )
        }

        expectTrue(
            lines.contains { $0.text.contains("如何面对") || $0.text.contains("曾一起走过的日子") },
            "Resolved lyrics should be the vocal song, not an instrumental placeholder"
        )
    }

    private static func testEnglishAliasTitleWithChineseArtistAnchorResolvesChineseMetadata() async {
        let metadata = await MusicPlatformService.shared.fetchChineseMetadata(
            title: "You My Deskmate",
            artist: "老狼 | Emotional Erhu"
        )

        expectEqual(metadata?.title, "同桌的你", "English alias title should resolve to the Chinese song title")
        expectEqual(metadata?.artist, "老狼", "Chinese artist anchor should resolve to the canonical Chinese artist")
    }
}

private func expectTrue(_ value: Bool, _ message: String) {
    guard value else {
        fatalError(message)
    }
}

private func expectEqual(_ actual: String?, _ expected: String, _ message: String) {
    guard actual == expected else {
        fatalError("\(message). Expected \(expected), got \(actual ?? "nil")")
    }
}
