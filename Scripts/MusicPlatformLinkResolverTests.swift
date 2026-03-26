import Foundation

@main
struct MusicPlatformLinkResolverTests {
    static func main() {
        testNetEaseSongTargets()
        testNetEaseSearchTargets()
        testNetEaseDesktopAppTargets()
        testQQSongTargets()
        testQQDesktopAppTargets()
        testMissingTitleReturnsNil()
        print("MusicPlatformLinkResolverTests passed")
    }

    private static func testNetEaseSongTargets() {
        let targets = MusicPlatformLinkResolver.makeTargets(
            platform: .netease,
            songID: "123456",
            title: "夜曲",
            artist: "周杰伦"
        )

        expectEqual(targets?.primaryURL.absoluteString, "orpheus://song/123456", "NetEase app song URL should use orpheus scheme")
        expectEqual(targets?.fallbackURL?.absoluteString, "https://music.163.com/#/song?id=123456", "NetEase fallback song URL should use web song page")
    }

    private static func testNetEaseSearchTargets() {
        let targets = MusicPlatformLinkResolver.makeTargets(
            platform: .netease,
            songID: nil,
            title: "夜曲",
            artist: "周杰伦"
        )

        expectEqual(
            targets?.primaryURL.absoluteString,
            "orpheus://search?keyword=%E5%A4%9C%E6%9B%B2%20%E5%91%A8%E6%9D%B0%E4%BC%A6&type=1",
            "NetEase app search URL should search by title and artist"
        )
        expectEqual(
            targets?.fallbackURL?.absoluteString,
            "https://music.163.com/#/search/m/?s=%E5%A4%9C%E6%9B%B2%20%E5%91%A8%E6%9D%B0%E4%BC%A6&type=1",
            "NetEase fallback search URL should use the web search page"
        )
    }

    private static func testNetEaseDesktopAppTargets() {
        let targets = MusicPlatformLinkResolver.makeTargets(
            platform: .netease,
            songID: "123456",
            title: "夜曲",
            artist: "周杰伦",
            openingPreference: .neteaseDesktopApp
        )

        expectEqual(
            targets?.primaryURL.absoluteString,
            "orpheus://eyJjbWQiOiJwbGF5IiwidHlwZSI6InNvbmciLCJpZCI6IjEyMzQ1NiIsImNoYW5uZWwiOiJ3ZWJzZXQifQ==",
            "Mac NetEase mode should use the desktop app private play command"
        )
        expectEqual(
            targets?.followUpLaunch?.url.absoluteString,
            "orpheus://eyJjbWQiOiJwbGF5IiwidHlwZSI6InNvbmciLCJpZCI6IjEyMzQ1NiIsImNoYW5uZWwiOiJ3ZWJzZXQifQ==",
            "Mac NetEase mode should replay the private command after the app finishes waking up"
        )
        expectEqual(
            targets?.followUpLaunch?.delay,
            4,
            "Mac NetEase mode should wait long enough for the vinyl page model to initialize"
        )
        expectNil(
            targets?.fallbackURL,
            "Mac NetEase desktop mode should stay inside the native app instead of bouncing to the web"
        )
    }

    private static func testQQSongTargets() {
        let targets = MusicPlatformLinkResolver.makeTargets(
            platform: .qq,
            songID: "004VBMk71TdUuR",
            title: "起风了",
            artist: "买辣椒也用券"
        )

        expectEqual(
            targets?.fallbackURL?.absoluteString,
            "https://y.qq.com/n/ryqq/songDetail/004VBMk71TdUuR",
            "QQ fallback song URL should use the public web detail page"
        )
    }

    private static func testQQDesktopAppTargets() {
        let songTargets = MusicPlatformLinkResolver.makeTargets(
            platform: .qq,
            songID: "004VBMk71TdUuR",
            title: "起风了",
            artist: "买辣椒也用券",
            openingPreference: .qqDesktopApp
        )

        expectEqual(
            songTargets?.primaryURL.absoluteString,
            "qqmusicmac://qq.com/media/playSonglist?p=%7B%22song%22:%5B%7B%22type%22:%220%22,%22songmid%22:%22004VBMk71TdUuR%22%7D%5D,%22action%22:%22play%22%7D",
            "Mac QQ mode should use the desktop app song deep link"
        )
        expectNil(
            songTargets?.fallbackURL,
            "Mac QQ desktop mode should stay inside the native app instead of bouncing to the web"
        )

        let searchTargets = MusicPlatformLinkResolver.makeTargets(
            platform: .qq,
            songID: nil,
            title: "起风了",
            artist: "买辣椒也用券",
            openingPreference: .qqDesktopApp
        )

        expectEqual(
            searchTargets?.primaryURL.absoluteString,
            "qqmusicmac://qq.com/ui/search?w=%E8%B5%B7%E9%A3%8E%E4%BA%86%20%E4%B9%B0%E8%BE%A3%E6%A4%92%E4%B9%9F%E7%94%A8%E5%88%B8",
            "Mac QQ mode should use the desktop app search deep link"
        )
        expectNil(
            searchTargets?.fallbackURL,
            "Mac QQ desktop search mode should not fall back to the web"
        )
    }

    private static func testMissingTitleReturnsNil() {
        let targets = MusicPlatformLinkResolver.makeTargets(
            platform: .netease,
            songID: nil,
            title: "   ",
            artist: "周杰伦"
        )

        expectNil(targets, "Missing title should not produce open targets")
    }

    private static func expectEqual(_ lhs: String?, _ rhs: String, _ message: String) {
        guard lhs == rhs else {
            fatalError("\(message)\nExpected: \(rhs)\nActual: \(lhs ?? "nil")")
        }
    }

    private static func expectEqual(_ lhs: TimeInterval?, _ rhs: TimeInterval, _ message: String) {
        guard lhs == rhs else {
            fatalError("\(message)\nExpected: \(rhs)\nActual: \(String(describing: lhs))")
        }
    }

    private static func expectNil(_ value: Any?, _ message: String) {
        guard value == nil else {
            fatalError("\(message)\nExpected nil but got \(String(describing: value))")
        }
    }
}
