import SwiftUI
import MusicKit

struct AddToPlaylistView: View {
    let songTitle: String
    let songArtist: String
    let artworkURL: URL?
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var appleMusicService = AppleMusicService.shared
    
    @State private var matchedSong: Song?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreatePlaylistAlert = false
    @State private var newPlaylistName = ""
    @State private var successMessage: String? // 显示成功提示
    
    var body: some View {
        NavigationView {
            ZStack {
                NeonColors.darkBg.ignoresSafeArea()
                
                if let success = successMessage {
                    successView(message: success)
                } else if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(message: error)
                } else {
                    mainContentView
                }
            }
            .navigationBarTitle("添加到 Apple Music", displayMode: .inline)
            .navigationBarItems(trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                startProcess()
            }
            .alert("新建歌单", isPresented: $showCreatePlaylistAlert) {
                TextField("歌单名称", text: $newPlaylistName)
                Button("取消", role: .cancel) { }
                Button("创建", role: .none) {
                    createNewPlaylist()
                }
            } message: {
                Text("请输入新歌单的名称")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: NeonColors.cyan))
                .scaleEffect(1.5)
            Text("正在连接 Apple Music...")
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(NeonColors.red)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal)
            
            if !appleMusicService.isAuthorized {
                 Button("去设置开启权限") {
                     if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                         UIApplication.shared.open(settingsUrl)
                     }
                 }
                 .padding()
                 .background(Capsule().stroke(NeonColors.cyan, lineWidth: 1))
                 .foregroundColor(NeonColors.cyan)
            } else {
                Button("重试") {
                    startProcess()
                }
                .padding()
                .background(Capsule().stroke(NeonColors.cyan, lineWidth: 1))
                .foregroundColor(NeonColors.cyan)
            }
        }
    }
    
    private func successView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(NeonColors.mint)
                .scaleEffect(1.2)
                .animation(.spring(), value: true)
            
            Text(message)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("已成功添加到您的资料库")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
        }
        .onAppear {
            // 1.5秒后自动关闭
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // 1. 匹配到的歌曲信息
            if let song = matchedSong {
                HStack(spacing: 16) {
                    if let artwork = song.artwork {
                        // 使用 MusicKit 的 Artwork
                        AsyncImage(url: artwork.url(width: 120, height: 120)) { image in
                             image.resizable()
                        } placeholder: {
                             Color.gray.opacity(0.3)
                        }
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                    } else if let url = artworkURL {
                        AsyncImage(url: url) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                    } else {
                        Image(systemName: "music.note")
                            .frame(width: 60, height: 60)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(song.artistName)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    Spacer()
                    
                    Image(systemName: "apple.logo")
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding()
                .background(Color.white.opacity(0.05))
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // 2. 歌单列表
            List {
                // 新建歌单入口
                Button(action: {
                    newPlaylistName = "" // 重置
                    showCreatePlaylistAlert = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(NeonColors.cyan)
                            .font(.title2)
                        Text("新建歌单")
                            .foregroundColor(NeonColors.cyan)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                
                // 现有歌单
                ForEach(appleMusicService.userPlaylists, id: \.id) { playlist in
                    Button(action: {
                        addToPlaylist(playlist)
                    }) {
                        HStack {
                            if let artwork = playlist.artwork {
                                AsyncImage(url: artwork.url(width: 80, height: 80)) { image in
                                     image.resizable()
                                } placeholder: {
                                     Color.gray.opacity(0.3)
                                }
                                .frame(width: 40, height: 40)
                                .cornerRadius(6)
                            } else {
                                Image(systemName: "music.note.list")
                                    .frame(width: 40, height: 40)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(6)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            
                            VStack(alignment: .leading) {
                                Text(playlist.name)
                                    .foregroundColor(.white)
                                Text(playlist.curatorName ?? "用户")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
        }
    }
    
    // MARK: - Logic
    
    private func startProcess() {
        Task {
            isLoading = true
            errorMessage = nil
            
            // 1. 检查/请求权限
            let authorized = await appleMusicService.requestAuthorization()
            guard authorized else {
                errorMessage = "请在设置中允许 App 访问 Apple Music 资料库"
                isLoading = false
                return
            }
            
            // 2. 搜索歌曲
            do {
                if let song = try await appleMusicService.searchCatalog(title: songTitle, artist: songArtist) {
                    matchedSong = song
                } else {
                    errorMessage = "未在 Apple Music 中找到该歌曲"
                    isLoading = false
                    return
                }
            } catch {
                print("❌ AddToPlaylistView Error: \(error)")
                if let _ = error as? DecodingError {
                     errorMessage = "数据解析出现的错误。可能是网络问题或 Apple Music 地区不支持。"
                } else if (error as NSError).code == -2 && (error as NSError).domain == "AppleMusicService" {
                     errorMessage = "模拟器不支持 MusicKit 请求，请使用真机测试。"
                } else if (error as NSError).code == -1 && (error as NSError).domain == "AppleMusicService" {
                     errorMessage = error.localizedDescription
                } else {
                    errorMessage = "搜索失败: \(error.localizedDescription)"
                }
                isLoading = false
                return
            }
            
            // 3. 获取歌单
            do {
                try await appleMusicService.fetchUserPlaylists()
                isLoading = false
            } catch {
                errorMessage = "获取歌单失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func createNewPlaylist() {
        guard !newPlaylistName.isEmpty else { return }
        
        Task {
            do {
                if let newPlaylist = try await appleMusicService.createPlaylist(name: newPlaylistName, description: "Created by 收音机 App") {
                    // 刷新列表
                    try await appleMusicService.fetchUserPlaylists()
                    // 自动添加到新歌单
                    addToPlaylist(newPlaylist)
                }
            } catch {
                // 简单处理：显示错误 (实际项目中可能用 Toast)
                print("创建歌单失败: \(error)")
            }
        }
    }
    
    private func addToPlaylist(_ playlist: Playlist) {
        guard let song = matchedSong else { return }
        
        Task {
            do {
                try await appleMusicService.addSongToPlaylist(song: song, playlist: playlist)
                await MainActor.run {
                    successMessage = "已添加到 \(playlist.name)"
                }
            } catch {
                await MainActor.run {
                    // 如果 API 报错，可能是因为重复添加，MusicKit 有时会抛出奇怪错误
                    // 这里简化处理
                    print("添加失败: \(error)")
                }
            }
        }
    }
}
