import Foundation

enum MusicPlatformLink: String {
    case netease
    case qq
}

enum MusicPlatformLinkOpeningPreference {
    case appPreferred
    case directWeb
    case neteaseDesktopApp
    case qqDesktopApp
}

struct MusicPlatformLinkFollowUpLaunch: Equatable {
    let url: URL
    let delay: TimeInterval
}

struct MusicPlatformLinkTargets: Equatable {
    let primaryURL: URL
    let followUpLaunch: MusicPlatformLinkFollowUpLaunch?
    let fallbackURL: URL?
}

enum MusicPlatformLinkResolver {
    static func makeTargets(
        platform: MusicPlatformLink,
        songID: String?,
        title: String,
        artist: String,
        openingPreference: MusicPlatformLinkOpeningPreference = .appPreferred
    ) -> MusicPlatformLinkTargets? {
        guard let query = makeQuery(title: title, artist: artist) else {
            return nil
        }

        if openingPreference == .neteaseDesktopApp, platform == .netease {
            return makeNetEaseDesktopTargets(songID: normalizedSongID(songID), query: query)
        }

        if openingPreference == .qqDesktopApp, platform == .qq {
            return makeQQDesktopTargets(songID: normalizedSongID(songID), query: query)
        }

        let appURL: URL
        let webURL: URL
        if let songID = normalizedSongID(songID) {
            appURL = appSongURL(for: platform, songID: songID)
            webURL = webSongURL(for: platform, songID: songID)
        } else {
            appURL = appSearchURL(for: platform, query: query)
            webURL = webSearchURL(for: platform, query: query)
        }

        switch openingPreference {
        case .appPreferred:
            return MusicPlatformLinkTargets(primaryURL: appURL, followUpLaunch: nil, fallbackURL: webURL)
        case .directWeb:
            return MusicPlatformLinkTargets(primaryURL: webURL, followUpLaunch: nil, fallbackURL: nil)
        case .neteaseDesktopApp:
            return MusicPlatformLinkTargets(primaryURL: appURL, followUpLaunch: nil, fallbackURL: webURL)
        case .qqDesktopApp:
            return MusicPlatformLinkTargets(primaryURL: appURL, followUpLaunch: nil, fallbackURL: webURL)
        }
    }

    private static func makeQuery(title: String, artist: String) -> String? {
        let safeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !safeTitle.isEmpty else { return nil }

        let rawQuery: String
        if safeArtist.isEmpty || safeArtist == "未知歌手" {
            rawQuery = safeTitle
        } else {
            rawQuery = "\(safeTitle) \(safeArtist)"
        }

        return rawQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }

    private static func normalizedSongID(_ songID: String?) -> String? {
        guard let songID else { return nil }

        let trimmedSongID = songID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSongID.isEmpty else { return nil }

        return trimmedSongID
    }

    private static func appSongURL(for platform: MusicPlatformLink, songID: String) -> URL {
        switch platform {
        case .netease:
            return URL(string: "orpheus://song/\(songID)")!
        case .qq:
            let jsonString = "{\"song\":[{\"type\":\"0\",\"songmid\":\"\(songID)\"}],\"action\":\"play\"}"
            let encodedJSON = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            return URL(string: "qqmusic://qq.com/media/playSonglist?p=\(encodedJSON)")!
        }
    }

    private static func webSongURL(for platform: MusicPlatformLink, songID: String) -> URL {
        switch platform {
        case .netease:
            return URL(string: "https://music.163.com/#/song?id=\(songID)")!
        case .qq:
            return URL(string: "https://y.qq.com/n/ryqq/songDetail/\(songID)")!
        }
    }

    private static func appSearchURL(for platform: MusicPlatformLink, query: String) -> URL {
        switch platform {
        case .netease:
            return URL(string: "orpheus://search?keyword=\(query)&type=1")!
        case .qq:
            return URL(string: "qqmusic://qq.com/ui/search?w=\(query)")!
        }
    }

    private static func webSearchURL(for platform: MusicPlatformLink, query: String) -> URL {
        switch platform {
        case .netease:
            return URL(string: "https://music.163.com/#/search/m/?s=\(query)&type=1")!
        case .qq:
            return URL(string: "https://y.qq.com/n/ryqq/search?w=\(query)")!
        }
    }

    private static func makeNetEaseDesktopTargets(songID: String?, query: String) -> MusicPlatformLinkTargets {
        guard let songID else {
            return MusicPlatformLinkTargets(
                primaryURL: appSearchURL(for: .netease, query: query),
                followUpLaunch: nil,
                fallbackURL: nil
            )
        }

        let appURL = netEaseDesktopSongURL(songID: songID)
        return MusicPlatformLinkTargets(
            primaryURL: appURL,
            followUpLaunch: MusicPlatformLinkFollowUpLaunch(url: appURL, delay: 4),
            fallbackURL: nil
        )
    }

    private static func makeQQDesktopTargets(songID: String?, query: String) -> MusicPlatformLinkTargets {
        guard let songID else {
            return MusicPlatformLinkTargets(
                primaryURL: qqDesktopSearchURL(query: query),
                followUpLaunch: nil,
                fallbackURL: nil
            )
        }

        return MusicPlatformLinkTargets(
            primaryURL: qqDesktopSongURL(songID: songID),
            followUpLaunch: nil,
            fallbackURL: nil
        )
    }

    private static func netEaseDesktopSongURL(songID: String) -> URL {
        // macOS 桌面版网易云会把 Base64 JSON 载荷作为 webcmd 入口消费。
        let payload = "{\"cmd\":\"play\",\"type\":\"song\",\"id\":\"\(jsonStringLiteral(songID))\",\"channel\":\"webset\"}"
        let encodedPayload = Data(payload.utf8).base64EncodedString()
        return URL(string: "orpheus://\(encodedPayload)")!
    }

    private static func qqDesktopSongURL(songID: String) -> URL {
        let jsonString = "{\"song\":[{\"type\":\"0\",\"songmid\":\"\(songID)\"}],\"action\":\"play\"}"
        let encodedJSON = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        return URL(string: "qqmusicmac://qq.com/media/playSonglist?p=\(encodedJSON)")!
    }

    private static func qqDesktopSearchURL(query: String) -> URL {
        URL(string: "qqmusicmac://qq.com/ui/search?w=\(query)")!
    }

    private static func jsonStringLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
