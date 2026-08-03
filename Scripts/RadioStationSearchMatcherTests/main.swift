import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

expect(
    RadioStationSearchMatcher.fallbackTerms(for: "中广新闻").first == "中廣新聞",
    "simplified station names should try a traditional source alias first"
)
expect(
    RadioStationSearchMatcher.matches(
        name: "中廣新聞網",
        tags: "news",
        country: "Taiwan, Republic Of China",
        language: "chinese",
        query: "中广新闻"
    ),
    "traditional source names should match simplified queries"
)
expect(
    !RadioStationSearchMatcher.matches(
        name: "环球广播",
        tags: "",
        country: "China",
        language: "chinese",
        query: "环宇广播"
    ),
    "different Chinese station names should not be treated as typos"
)
expect(
    RadioStationSearchMatcher.matches(
        name: "NHK WORLD RADIO",
        tags: "international",
        country: "Japan",
        language: "",
        query: "NHK WORLD-JAPAN 华语广播"
    ),
    "a Chinese language qualifier should be optional when the Latin station identity matches"
)
expect(
    !RadioStationSearchMatcher.matches(
        name: "Jazz FM",
        tags: "jazz",
        country: "United States",
        language: "english",
        query: "jazz rock"
    ),
    "server candidates missing a submitted keyword should be rejected"
)

print("RadioStationSearchMatcher tests passed")
