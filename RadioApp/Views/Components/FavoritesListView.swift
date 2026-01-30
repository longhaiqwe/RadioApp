import SwiftUI

struct FavoritesListView: View {
    @ObservedObject var favoritesManager = FavoritesManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @Environment(\.dismiss) var dismiss
    
    let onStationSelected: (Station) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                NeonColors.darkBg.ignoresSafeArea()
                
                // 渐变叠加
                LinearGradient(
                    colors: [
                        NeonColors.purple.opacity(0.2),
                        NeonColors.darkBg
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if favoritesManager.favoriteStations.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    // 收藏列表
                    favoritesList
                }
            }
            .navigationTitle("收藏电台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(NeonColors.darkBg.opacity(0.8), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundColor(NeonColors.cyan.opacity(0.5))
            
            Text("暂无收藏电台")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("点击电台旁的爱心按钮添加收藏")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - 收藏列表
    private var favoritesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(favoritesManager.favoriteStations) { station in
                    FavoriteStationRow(
                        station: station,
                        isCurrentlyPlaying: playerManager.currentStation?.id == station.id,
                        isPlaying: playerManager.isPlaying && playerManager.currentStation?.id == station.id
                    )
                    .onTapGesture {
                        onStationSelected(station)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - 收藏电台行
struct FavoriteStationRow: View {
    let station: Station
    let isCurrentlyPlaying: Bool
    let isPlaying: Bool
    @ObservedObject var favoritesManager = FavoritesManager.shared
    
    var body: some View {
        HStack(spacing: 14) {
            // 封面图
            ZStack {
                StationAvatarView(urlString: station.favicon, placeholderName: station.name, placeholderId: station.stationuuid)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isCurrentlyPlaying ? NeonColors.cyan : Color.white.opacity(0.1),
                        lineWidth: isCurrentlyPlaying ? 2 : 1
                    )
            )
            .shadow(color: isCurrentlyPlaying ? NeonColors.cyan.opacity(0.3) : .clear, radius: 8)
            
            // 电台信息
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isCurrentlyPlaying ? NeonColors.cyan : .white)
                    .lineLimit(1)
                
                if !station.tags.isEmpty {
                    Text(station.tags)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 播放指示器 + 取消收藏按钮
            HStack(spacing: 12) {
                if isPlaying {
                    // 播放动画指示器
                    PlayingIndicator()
                }
                
                // 取消收藏按钮
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        favoritesManager.removeFavorite(station)
                    }
                }) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))
                        .foregroundColor(NeonColors.magenta)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(NeonColors.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isCurrentlyPlaying 
                                ? NeonColors.cyan.opacity(0.3) 
                                : Color.white.opacity(0.05),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 播放指示器动画
struct PlayingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(NeonColors.cyan)
                    .frame(width: 3, height: isAnimating ? CGFloat.random(in: 8...18) : 8)
                    .animation(
                        Animation.easeInOut(duration: 0.4)
                            .repeatForever()
                            .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    FavoritesListView(onStationSelected: { _ in })
}
