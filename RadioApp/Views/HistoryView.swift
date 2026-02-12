import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @Query private var allSongs: [RecognizedSong]
    
    var body: some View {
        ZStack {
            // 背景
            AnimatedMeshBackground()
                .ignoresSafeArea()
            
            VStack(alignment: .leading) {
                // 顶部标题栏
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(.white.opacity(0.1)))
                    }
                    
                    Text("识别历史")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
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
                HistoryListView(filter: searchText)
                    .id(searchText) // 强制 SwiftUI 在搜索词变化时重新创建视图，触发新 Query
                    .onTapGesture {
                        hideKeyboard() // 点击列表收起键盘
                    }
            }
        }
        .navigationBarHidden(true)
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
    @Query(sort: \RecognizedSong.timestamp, order: .reverse) private var allSongs: [RecognizedSong]
    let filterString: String
    
    init(filter: String = "") {
        self.filterString = filter
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
            .frame(maxWidth: .infinity)
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
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
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
        await ShareCardGenerator.generateAndShare(
            title: song.title,
            artist: song.artist,
            album: song.album,
            artworkURL: song.artworkURL,
            stationName: song.stationName,
            timestamp: song.timestamp
        )
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
