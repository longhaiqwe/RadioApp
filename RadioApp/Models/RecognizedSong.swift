import Foundation
import SwiftData

@Model
final class RecognizedSong {
    var id: UUID
    var title: String
    var artist: String
    var album: String?
    var artworkURL: URL?
    var appleMusicID: String?
    var stationName: String?
    var timestamp: Date
    var source: String // "Shazam" or "ACRCloud" or "Manual"
    var releaseDate: Date? // 歌曲发行日期
    
    init(title: String, artist: String, album: String? = nil, artworkURL: URL? = nil, appleMusicID: String? = nil, stationName: String? = nil, timestamp: Date = Date(), source: String = "Shazam", releaseDate: Date? = nil) {
        self.id = UUID()
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.appleMusicID = appleMusicID
        self.stationName = stationName
        self.timestamp = timestamp
        self.source = source
        self.releaseDate = releaseDate
    }
}
