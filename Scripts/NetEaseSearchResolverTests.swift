import Foundation

@main
struct NetEaseSearchResolverTests {
    static func main() throws {
        testCloudSearchRequestUsesWorkingEndpoint()
        try testParseSongsSupportsCloudSearchShape()
        try testParseSongsReturnsEmptyForUnexpectedPayload()
        testMatchPriorityPrefersOriginalAlbumOverCompilation()
        print("NetEaseSearchResolverTests passed")
    }
}

private func testCloudSearchRequestUsesWorkingEndpoint() {
        let request = NetEaseSearchResolver.makeSearchRequest(keyword: "海阔天空 Beyond", limit: 5)

        expectEqual(
            request?.url?.absoluteString,
            "https://music.163.com/api/cloudsearch/pc?s=%E6%B5%B7%E9%98%94%E5%A4%A9%E7%A9%BA%20Beyond&type=1&offset=0&limit=5",
            "NetEase search should use the cloudsearch endpoint that still returns songs"
        )
        expectEqual(
            request?.value(forHTTPHeaderField: "Referer"),
            "https://music.163.com/",
            "NetEase search should keep the desktop app referer"
        )
}

private func testParseSongsSupportsCloudSearchShape() throws {
        let data = Data(
            """
            {
              "result": {
                "songs": [
                  {
                    "id": 347230,
                    "name": "海阔天空",
                    "ar": [
                      { "name": "Beyond" }
                    ],
                    "al": {
                      "name": "海阔天空"
                    }
                  },
                  {
                    "id": 1357375695,
                    "name": "海阔天空",
                    "artists": [
                      { "name": "Beyond" }
                    ],
                    "album": {
                      "name": "华纳廿三周年纪念精选系列"
                    }
                  }
                ]
              }
            }
            """.utf8
        )

        let songs = try NetEaseSearchResolver.parseSongs(from: data)

        expectEqual(songs.count, 2, "Cloud search payload should parse every song entry")
        expectEqual(songs.first?.id, "347230", "Song id should be converted to a string")
        expectEqual(songs.first?.title, "海阔天空", "Song title should come from name")
        expectEqual(songs.first?.artist, "Beyond", "Cloud search parser should read artists from ar")
        expectEqual(songs.first?.album, "海阔天空", "Cloud search parser should read albums from al")
        expectEqual(songs.last?.artist, "Beyond", "Parser should also support the legacy artists key")
}

private func testParseSongsReturnsEmptyForUnexpectedPayload() throws {
        let data = Data(#"{"result":"encrypted"}"#.utf8)
        let songs = try NetEaseSearchResolver.parseSongs(from: data)
        expectEqual(songs.count, 0, "Unexpected payloads should not fabricate results")
}

private func testMatchPriorityPrefersOriginalAlbumOverCompilation() {
        let compilationScore = NetEaseSearchResolver.matchPriority(
            queryTitle: "海阔天空",
            queryArtist: "Beyond",
            songTitle: "海阔天空",
            songArtist: "Beyond",
            songAlbum: "华纳超极品音色系列"
        )

        let originalAlbumScore = NetEaseSearchResolver.matchPriority(
            queryTitle: "海阔天空",
            queryArtist: "Beyond",
            songTitle: "海阔天空",
            songArtist: "Beyond",
            songAlbum: "海阔天空"
        )

        guard originalAlbumScore > compilationScore else {
            fatalError(
                """
                Original single should outrank compilation results for deep linking
                Original score: \(originalAlbumScore)
                Compilation score: \(compilationScore)
                """
            )
        }
}

private func expectEqual(_ lhs: String?, _ rhs: String, _ message: String) {
        guard lhs == rhs else {
            fatalError("\(message)\nExpected: \(rhs)\nActual: \(lhs ?? "nil")")
        }
}

private func expectEqual(_ lhs: Int?, _ rhs: Int, _ message: String) {
        guard lhs == rhs else {
            fatalError("\(message)\nExpected: \(rhs)\nActual: \(String(describing: lhs))")
        }
}
