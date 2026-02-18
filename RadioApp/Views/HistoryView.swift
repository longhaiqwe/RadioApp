import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var searchText = ""
    @State private var showProUpgrade = false
    @Query private var allSongs: [RecognizedSong]
    
    var showBackButton: Bool = true
    
    var body: some View {
        ZStack {
            // 背景
            AnimatedMeshBackground()
                .ignoresSafeArea()
            
            VStack(alignment: .leading) {
                // 顶部标题栏
                HStack {
                    if showBackButton {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Circle().fill(.white.opacity(0.1)))
                        }
                    }
                    
                    Text("识别历史")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if !subscriptionManager.isPro {
                        Button(action: { showProUpgrade = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 12))
                                Text("Pro")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(NeonColors.gold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(NeonColors.gold.opacity(0.2)))
                            .overlay(
                                Capsule().stroke(NeonColors.gold.opacity(0.5), lineWidth: 1)
                            )
                        }
                    }
                    
                    if !allSongs.isEmpty {
                        Button(action: clearAllHistory) {
                            Text("清空")
                                .font(.system(size: 14))
                                .foregroundColor(NeonColors.red.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(NeonColors.red.opacity(0.1)))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.5))
                    TextField("搜索歌曲、歌手、专辑或电台", text: $searchText)
                        .foregroundColor(.white)
                        .accentColor(NeonColors.cyan)
                        .submitLabel(.search) // 将回车键变为“搜索”
                        .onSubmit {
                            hideKeyboard() // 点击搜索收起键盘
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 10)
                
                // 列表内容
                HistoryListView(filter: searchText, showProUpgrade: $showProUpgrade)
                    .id(searchText) // 强制 SwiftUI 在搜索词变化时重新创建视图，触发新 Query
                    .onTapGesture {
                        hideKeyboard() // 点击列表收起键盘
                    }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showProUpgrade) {
            ProUpgradeView()
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func clearAllHistory() {
        withAnimation {
            try? modelContext.delete(model: RecognizedSong.self)
            try? modelContext.save()
        }
    }
}

struct HistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Query(sort: \RecognizedSong.timestamp, order: .reverse) private var allSongs: [RecognizedSong]
    let filterString: String
    @Binding var showProUpgrade: Bool

    @State private var selectedSongForPlaylist: RecognizedSong? // for sheet
    @State private var showSharePreview = false // 显示分享预览
    @State private var shareCardImage: UIImage? = nil // 分享卡片图片
    
    init(filter: String = "", showProUpgrade: Binding<Bool>) {
        self.filterString = filter
        self._showProUpgrade = showProUpgrade
    }
    
    /// 在内存中过滤（SwiftData 的 SQL 谓词对中文和可选字段支持不佳）
    private var filteredSongs: [RecognizedSong] {
        guard !filterString.isEmpty else { return allSongs }
        let keyword = filterString.lowercased()
        return allSongs.filter { song in
            song.title.lowercased().contains(keyword) ||
            song.artist.lowercased().contains(keyword) ||
            (song.album?.lowercased().contains(keyword) ?? false) ||
            (song.stationName?.lowercased().contains(keyword) ?? false)
        }
    }
    
    var body: some View {
        if filteredSongs.isEmpty {
            Spacer()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.2))
                        
                        if filterString.isEmpty {
                            Text("还没有识别记录")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.5))
                            Text("点击主页的识别按钮，发现此时此刻的好音乐")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.3))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        } else {
                            Text("没有找到相关记录")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    
                    // Pro 推广卡片 (仅非 Pro 用户显示)
                    if !subscriptionManager.isPro && filterString.isEmpty {
                        Button(action: { showProUpgrade = true }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [NeonColors.gold, Color.orange],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 48, height: 48)
                                    
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("升级到 Pro 版")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("解锁 50 次高精度识别，支持 Apple Music 同步")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(NeonColors.gold.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                }
                .padding(.top, 60) // 给上面留点空间
            }
            Spacer()
        } else {
            List {
                ForEach(filteredSongs) { song in
                    NeonSongRow(song: song)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteSong(song)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Task {
                                    await shareSong(song)
                                }
                            } label: {
                                Label("分享", systemImage: "square.and.arrow.up")
                            }
                            .tint(NeonColors.cyan)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                selectedSongForPlaylist = song
                            } label: {
                                Label("加入歌单", systemImage: "plus.circle")
                            }
                            .tint(NeonColors.purple)
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .sheet(item: $selectedSongForPlaylist) { song in
                AddToPlaylistView(
                     songTitle: song.title,
                     songArtist: song.artist,
                     artworkURL: song.artworkURL
                )
                AddToPlaylistView(
                     songTitle: song.title,
                     songArtist: song.artist,
                     artworkURL: song.artworkURL
                )
            }
            .fullScreenCover(isPresented: $showSharePreview) {
                if let image = shareCardImage {
                    ShareCardPreviewView(
                        image: image,
                        onShare: {
                            ShareCardGenerator.shareImage(image) {
                                // 分享/保存成功后关闭预览
                                showSharePreview = false
                            }
                        },
                        onDismiss: {
                            showSharePreview = false
                        }
                    )
                }
            }
        }
    }
    
    private func deleteSong(_ song: RecognizedSong) {
        withAnimation {
            modelContext.delete(song)
            try? modelContext.save()
        }
    }
    
    @MainActor
    private func shareSong(_ song: RecognizedSong) async {
        if let image = await ShareCardGenerator.generateCardImage(
            title: song.title,
            artist: song.artist,
            album: song.album,
            artworkURL: song.artworkURL,
            stationName: song.stationName,
            timestamp: song.timestamp,
            releaseDate: song.releaseDate
        ) {
            self.shareCardImage = image
            self.showSharePreview = true
        }
    }
}

struct NeonSongRow: View {
    let song: RecognizedSong
    
    var body: some View {
        HStack(spacing: 12) {
            // 封面
            ZStack {
                if let url = song.artworkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Image(systemName: "music.note")
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                } else {
                     // 默认图标
                     ZStack {
                         Color.white.opacity(0.1)
                         Image(systemName: "music.note")
                             .font(.system(size: 20))
                             .foregroundColor(NeonColors.cyan)
                     }
                }
            }
            .frame(width: 56, height: 56)
            .cornerRadius(8)
            .neonGlow(color: NeonColors.cyan.opacity(0.3), radius: 5)
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(song.artist)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                    
                    if let album = song.album, !album.isEmpty {
                        Text("• \(album)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    
                    if let station = song.stationName {
                        Text("• \(station)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }
                
                HStack {
                    Text(formatDate(song.timestamp))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Spacer()
                    
                    if song.source == "ACRCloud" {
                        Text("Pro")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(NeonColors.gold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(NeonColors.gold.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding(12)
        .background(
            GlassmorphicBackground(cornerRadius: 12, glowColor: NeonColors.purple.opacity(0.3))
        )
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
