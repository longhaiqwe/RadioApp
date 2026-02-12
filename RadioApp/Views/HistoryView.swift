import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecognizedSong.timestamp, order: .reverse) private var songs: [RecognizedSong]
    @Environment(\.presentationMode) var presentationMode
    
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
                    
                    if !songs.isEmpty {
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
                
                if songs.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.2))
                        Text("还没有识别记录")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                        Text("点击主页的识别按钮，发现此时此刻的好音乐")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    List {
                        ForEach(songs) { song in
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
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func deleteSong(_ song: RecognizedSong) {
        withAnimation {
            modelContext.delete(song)
            try? modelContext.save()
        }
    }
    
    private func clearAllHistory() {
        withAnimation {
            try? modelContext.delete(model: RecognizedSong.self)
            try? modelContext.save()
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
