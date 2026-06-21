import Foundation

struct NetEaseSearchSong: Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let artworkURL: String?
    let releaseDate: Date?
}

enum NetEaseSearchResolver {
    nonisolated static func makeSearchRequest(keyword: String, limit: Int, offset: Int = 0) -> URLRequest? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "music.163.com"
        components.path = "/api/cloudsearch/pc"
        components.queryItems = [
            URLQueryItem(name: "s", value: keyword),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        guard let url = components.url else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        return request
    }

    nonisolated static func parseSongs(from data: Data) throws -> [NetEaseSearchSong] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]] else {
            return []
        }

        return songs.compactMap(parseSong)
    }

    nonisolated static func matchPriority(
        queryTitle: String,
        queryArtist: String,
        songTitle: String,
        songArtist: String,
        songAlbum: String?
    ) -> Int {
        let normalizedQueryTitle = normalized(queryTitle)
        let normalizedQueryArtist = normalized(queryArtist)
        let normalizedSongTitle = normalized(songTitle)
        let normalizedSongArtist = normalized(songArtist)
        let normalizedSongAlbum = normalized(songAlbum ?? "")
        let loweredAlbum = (songAlbum ?? "").lowercased()
        let loweredTitle = songTitle.lowercased()

        var score = 0

        if normalizedSongTitle == normalizedQueryTitle {
            score += 100
        } else if normalizedSongTitle.contains(normalizedQueryTitle) || normalizedQueryTitle.contains(normalizedSongTitle) {
            score += 40
        }

        if !normalizedQueryArtist.isEmpty, !normalizedSongArtist.isEmpty {
            if normalizedSongArtist == normalizedQueryArtist {
                score += 60
            } else if normalizedSongArtist.contains(normalizedQueryArtist) || normalizedQueryArtist.contains(normalizedSongArtist) {
                score += 20
            }
        }

        if !normalizedSongAlbum.isEmpty {
            if normalizedSongAlbum == normalizedQueryTitle {
                score += 50
            } else if normalizedSongAlbum.contains(normalizedQueryTitle) || normalizedQueryTitle.contains(normalizedSongAlbum) {
                score += 10
            }
        }

        for keyword in ["精选", "纪念", "合集", "珍藏", "超极品", "live", "演唱会"] {
            if loweredAlbum.contains(keyword) {
                score -= 25
            }
        }

        if loweredTitle.contains("live") {
            score -= 15
        }

        return score
    }

    private nonisolated static func parseSong(from song: [String: Any]) -> NetEaseSearchSong? {
        let title = (song["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else {
            return nil
        }

        let songID: String?
        if let intID = song["id"] as? Int {
            songID = String(intID)
        } else {
            songID = song["id"] as? String
        }

        guard let id = songID?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            return nil
        }

        let artistObjects = (song["artists"] as? [[String: Any]]) ?? (song["ar"] as? [[String: Any]]) ?? []
        let artist = artistObjects
            .compactMap { $0["name"] as? String }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let albumObject = (song["album"] as? [String: Any]) ?? (song["al"] as? [String: Any])
        let album = (albumObject?["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let artworkURL = albumObject?["picUrl"] as? String
        
        var releaseDate: Date? = nil
        if let publishTime = song["publishTime"] as? Double {
            releaseDate = Date(timeIntervalSince1970: publishTime / 1000.0)
        } else if let publishTime = song["publishTime"] as? Int64 {
            releaseDate = Date(timeIntervalSince1970: Double(publishTime) / 1000.0)
        } else if let publishTime = song["publishTime"] as? Int {
            releaseDate = Date(timeIntervalSince1970: Double(publishTime) / 1000.0)
        }

        return NetEaseSearchSong(
            id: id,
            title: title,
            artist: artist,
            album: album,
            artworkURL: artworkURL,
            releaseDate: releaseDate
        )
    }

    private nonisolated static func normalized(_ text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.punctuationCharacters.union(.symbols).union(.whitespacesAndNewlines))
            .joined()
    }
}
