import Foundation

@main
struct StreamPlaybackPreflightTests {
    static func main() async {
        testRequiresProbeForZenoStreams()
        testDoesNotProbeOrdinaryMp3Streams()
        testRejectsUnauthorizedHTTPResponse()
        testAcceptsSuccessfulAudioResponse()
        await testFiltersUnavailablePreflightStreamsFromResults()
        await testKeepsOrdinaryStreamsWithoutProbe()
        print("StreamPlaybackPreflightTests passed")
    }

    private static func testRequiresProbeForZenoStreams() {
        let url = URL(string: "https://stream.zeno.fm/zibntg5gtr7vv")!

        expectTrue(
            StreamPlaybackPreflight.requiresProbe(for: url),
            "Zeno stream URLs should be probed before handing them to AVPlayer"
        )
    }

    private static func testDoesNotProbeOrdinaryMp3Streams() {
        let url = URL(string: "https://lhttp.qingting.fm/live/4804/64k.mp3")!

        expectFalse(
            StreamPlaybackPreflight.requiresProbe(for: url),
            "Ordinary MP3 streams should continue to start immediately"
        )
    }

    private static func testRejectsUnauthorizedHTTPResponse() {
        expectFalse(
            StreamPlaybackPreflight.isPlayableHTTPResponse(statusCode: 401, contentType: nil),
            "HTTP 401 responses should be treated as unplayable"
        )
    }

    private static func testAcceptsSuccessfulAudioResponse() {
        expectTrue(
            StreamPlaybackPreflight.isPlayableHTTPResponse(statusCode: 200, contentType: "audio/mpeg"),
            "Successful audio responses should be treated as playable"
        )
    }

    private static func testFiltersUnavailablePreflightStreamsFromResults() async {
        let zeno = makeStation(id: "zeno", urlResolved: "https://stream.zeno.fm/zibntg5gtr7vv")
        let ordinary = makeStation(id: "ordinary", urlResolved: "https://lhttp.qingting.fm/live/4804/64k.mp3")

        let filtered = await StreamPlaybackPreflight.filterPlayableStations([zeno, ordinary]) { url in
            expectEqual(url.absoluteString, zeno.urlResolved, "Only preflight-required URLs should be probed")
            return false
        }

        expectEqual(filtered.map(\.id), [ordinary.id], "Unavailable preflight streams should be hidden from result lists")
    }

    private static func testKeepsOrdinaryStreamsWithoutProbe() async {
        let ordinary = makeStation(id: "ordinary", urlResolved: "https://lhttp.qingting.fm/live/4804/64k.mp3")
        var didProbe = false

        let filtered = await StreamPlaybackPreflight.filterPlayableStations([ordinary]) { _ in
            didProbe = true
            return false
        }

        expectFalse(didProbe, "Ordinary streams should not add a search-time network probe")
        expectEqual(filtered.map(\.id), [ordinary.id], "Ordinary streams should remain visible")
    }
}

private func makeStation(id: String, urlResolved: String) -> Station {
    Station(
        changeuuid: id,
        stationuuid: id,
        name: id,
        url: urlResolved,
        urlResolved: urlResolved,
        homepage: "",
        favicon: "",
        tags: "",
        country: "",
        countrycode: "",
        state: "",
        language: "",
        languagecodes: nil,
        votes: 0,
        lastchangetime: "",
        codec: "MP3",
        bitrate: 128,
        hls: 0,
        lastcheckok: 1,
        lastchecktime: "",
        lastcheckoktime: "",
        lastlocalchecktime: "",
        clicktimestamp: "",
        clickcount: 0,
        clicktrend: 0
    )
}

private func expectTrue(_ value: Bool, _ message: String) {
    guard value else {
        fatalError(message)
    }
}

private func expectFalse(_ value: Bool, _ message: String) {
    guard !value else {
        fatalError(message)
    }
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    guard actual == expected else {
        fatalError("\(message). Expected \(expected), got \(actual)")
    }
}
