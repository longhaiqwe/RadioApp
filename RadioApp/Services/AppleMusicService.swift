import Foundation
import MusicKit
import StoreKit
import Combine

class AppleMusicService: ObservableObject {
    static let shared = AppleMusicService()
    
    @Published var isAuthorized = false
    @Published var userPlaylists: [Playlist] = []
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        Task {
            let status = MusicAuthorization.currentStatus
            await MainActor.run {
                self.isAuthorized = (status == .authorized)
            }
        }
    }
    
    func requestAuthorization() async -> Bool {
        let status = await MusicAuthorization.request()
        await MainActor.run {
            self.isAuthorized = (status == .authorized)
        }
        return status == .authorized
    }
    
    // MARK: - Catalog Search
    
    /// 根据标题和歌手搜索 Apple Music 目录
    /// 根据标题和歌手搜索 Apple Music 目录
    func searchCatalog(title: String, artist: String) async throws -> Song? {
        // 0. 检查是否能获取到当前及第的 Storefront (Country Code)
        // 如果这里失败，通常意味着用户的 Apple ID 地区设置有问题，或者没登录
        do {
            let _ = try await MusicDataRequest.currentCountryCode
        } catch {
            print("❌ 获取 Storefront 失败: \(error)")
            throw NSError(domain: "AppleMusicService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取 Apple Music 地区信息，请检查您的 Apple ID 登录状态。"])
        }
        
        // 1. 尝试 "Title Artist" 组合搜索
        let searchTerm = "\(title) \(artist)".trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔍 Apple Music Search: [\(searchTerm)]")
        
        if searchTerm.isEmpty { return nil }
        
        var request = MusicCatalogSearchRequest(term: searchTerm, types: [Song.self])
        request.limit = 5
        request.includeTopResults = true // 尝试包含最佳匹配
        
        do {
            let response = try await request.response()
            
            if let song = response.songs.first {
                print("✅ Found song: \(song.title) by \(song.artistName)")
                return song
            }
        } catch {
            print("❌ Search failed for term [\(searchTerm)]: \(error)")
            
            // 检查是否在模拟器上运行
            #if targetEnvironment(simulator)
            if let _ = error as? DecodingError {
                throw NSError(domain: "AppleMusicService", code: -2, userInfo: [NSLocalizedDescriptionKey: "模拟器不支持 MusicKit 搜索请求，请在真机上运行测试。"])
            }
            #endif
            
            // 如果是因为格式问题失败，尝试简化搜索
            // (MusicKit有时的确会报 Decoding Error 如果返回数据也是空的但格式不对)
            if let decodingError = error as? DecodingError {
                print("⚠️ Decoding Error detected: \(decodingError)")
                 throw NSError(domain: "AppleMusicService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Apple Music 数据解析失败。请确保您已登录并在真机上运行。"])
            }
            throw error // Rethrow to let UI handle it, or maybe Fallback?
        }
        
        print("⚠️ No results found for [\(searchTerm)]")
        return nil
    }
    
    // MARK: - Playlist Management
    
    /// 获取用户创建的歌单 (可写入的)
    func fetchUserPlaylists() async throws {
        // 使用 MusicLibraryRequest 获取歌单
        let request = MusicLibraryRequest<Playlist>()
        // request.filter(matching: \.isLibraryBacked, equalTo: true) // Invalid for Playlist
        
        let response = try await request.response()
        
        // 过滤: 尽量只显示用户创建的歌单
        // 由于 MusicKit 的 Playlist 属性有限，我们暂时返回所有资料库歌单
        // 实际添加时如果是只读歌单会抛出错误，我们在 UI 层处理
        let editablePlaylists = response.items
        
        
        await MainActor.run {
            self.userPlaylists = Array(editablePlaylists)
        }
    }
    
    /// 创建新歌单
    func createPlaylist(name: String, description: String? = nil) async throws -> Playlist? {
        #if !targetEnvironment(macCatalyst)
        let library = MusicLibrary.shared
        return try await library.createPlaylist(name: name, description: description)
        #else
        throw NSError(domain: "AppleMusicService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Mac 版暂不支持创建歌单，请使用 iOS 版本。"])
        #endif
    }
    
    /// 添加歌曲到歌单
    func addSongToPlaylist(song: Song, playlist: Playlist) async throws {
        #if !targetEnvironment(macCatalyst)
        let library = MusicLibrary.shared
        try await library.add(song, to: playlist)
        #else
        throw NSError(domain: "AppleMusicService", code: -5, userInfo: [NSLocalizedDescriptionKey: "Mac 版暂不支持添加歌曲到歌单，请使用 iOS 版本。"])
        #endif
    }
}
