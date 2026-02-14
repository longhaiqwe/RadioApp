import Foundation
import SwiftData

@MainActor
class HistoryManager {
    static let shared = HistoryManager()
    
    let container: ModelContainer
    
    private init() {
        do {
            let schema = Schema([
                RecognizedSong.self,
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    // MARK: - API
    
    func addSong(title: String, artist: String, album: String? = nil, artworkURL: URL? = nil, appleMusicID: String? = nil, stationName: String? = nil, source: String = "Shazam", releaseDate: Date? = nil) {
        let context = container.mainContext
        
        // 简单去重：如果最近 (10分钟内) 有完全相同的歌，只更新时间
        let tenMinutesAgo = Date().addingTimeInterval(-600)
        let descriptor = FetchDescriptor<RecognizedSong>(
            predicate: #Predicate { song in
                song.title == title && song.artist == artist && song.timestamp > tenMinutesAgo
            }
        )
        
        do {
            let recentSongs = try context.fetch(descriptor)
            if let existingSong = recentSongs.first {
                print("[History] 更新现有记录时间: \(title)")
                existingSong.timestamp = Date()
                // 更新其他可能变更的字段
                if let newUrl = artworkURL { existingSong.artworkURL = newUrl }
                if let newAlbum = album { existingSong.album = newAlbum }
                if let newDate = releaseDate { existingSong.releaseDate = newDate }
            } else {
                print("[History] 添加新记录: \(title) - \(artist)")
                let newSong = RecognizedSong(
                    title: title,
                    artist: artist,
                    album: album,
                    artworkURL: artworkURL,
                    appleMusicID: appleMusicID,
                    stationName: stationName,
                    timestamp: Date(),
                    source: source,
                    releaseDate: releaseDate
                )
                context.insert(newSong)
            }
            try context.save()
        } catch {
            print("[History] 保存失败: \(error)")
        }
    }
    
    func deleteSong(_ song: RecognizedSong) {
        let context = container.mainContext
        context.delete(song)
        do {
            try context.save()
        } catch {
            print("[History] 删除失败: \(error)")
        }
    }
    
    func clearAll() {
        let context = container.mainContext
        do {
            try context.delete(model: RecognizedSong.self)
            try context.save()
        } catch {
            print("[History] 清空失败: \(error)")
        }
    }
}
