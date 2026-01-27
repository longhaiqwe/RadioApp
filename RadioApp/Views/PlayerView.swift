import SwiftUI
import Combine
import ShazamKit

struct PlayerView: View {
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var favoritesManager = FavoritesManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var volume: CGFloat = 0.5
    @State private var rotation: Double = 0
    @State private var showVolumeSlider = true
    @State private var showFavoritesList = false
    @ObservedObject var shazamMatcher = ShazamMatcher.shared
    
    var body: some View {
        ZStack {
            // MARK: - 动态背景
            playerBackground
            
            VStack(spacing: 0) {
                // MARK: - 顶部栏
                topBar
                    .padding(.top, 20)
                
                Spacer()
                
                // MARK: - 封面区域
                albumArtSection
                
                // MARK: - 可视化
                if playerManager.isPlaying {
                    EnhancedVisualizerView(isPlaying: playerManager.isPlaying)
                        .frame(height: 50)
                        .padding(.vertical, 20)
                } else {
                    Spacer().frame(height: 90)
                }
                
                // MARK: - 电台信息
                stationInfo
                
                Spacer()
                
                // MARK: - 控制按钮
                controlButtons
                    .padding(.bottom, 30)
                
                // MARK: - 音量滑块
                volumeControl
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
            }
        }
    }
    
    // MARK: - 背景
    private var playerBackground: some View {
        ZStack {
            // 基础暗色
            NeonColors.darkBg.ignoresSafeArea()
            
            // 动态封面模糊背景
            if let station = playerManager.currentStation {
                if let url = URL(string: station.favicon), !station.favicon.isEmpty {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 80)
                                .opacity(0.4)
                        }
                    }
                    .ignoresSafeArea()
                }
            }
            
            // 渐变叠加
            LinearGradient(
                colors: [
                    NeonColors.purple.opacity(0.3),
                    NeonColors.darkBg.opacity(0.8),
                    NeonColors.darkBg
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // 霓虹光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [NeonColors.magenta.opacity(0.2), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .offset(y: -150)
                .blur(radius: 50)
        }
    }
    
    // MARK: - 顶部栏
    private var topBar: some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.3))
                    )
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("正在播放")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(NeonColors.cyan.opacity(0.8))
                    .textCase(.uppercase)
                    .kerning(2)
            }
            
            Spacer()
            
            // 识别按钮
            Button(action: {
                if shazamMatcher.isMatching {
                    shazamMatcher.stopMatching()
                } else {
                    shazamMatcher.startMatching()
                }
            }) {
                ZStack {
                    if shazamMatcher.isMatching {
                        Circle()
                            .stroke(NeonColors.cyan, lineWidth: 2)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .trim(from: 0, to: 0.7)
                                    .stroke(NeonColors.magenta, lineWidth: 2)
                                    .rotationEffect(Angle(degrees: shazamMatcher.isMatching ? 360 : 0))
                                    .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: shazamMatcher.isMatching)
                            )
                    } else {
                         // Normal state background for better visibility in top bar
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.3))
                            .frame(width: 44, height: 44)
                    }
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 20))
                        .foregroundColor(shazamMatcher.isMatching ? NeonColors.magenta : .white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - 封面区域
    private var albumArtSection: some View {
        ZStack {
            // 外层发光环
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [NeonColors.cyan, NeonColors.purple, NeonColors.magenta, NeonColors.cyan],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 290, height: 290)
                .blur(radius: 4)
                .opacity(playerManager.isPlaying ? 0.8 : 0.3)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    if playerManager.isPlaying {
                        startRotation()
                    }
                }
                .onChange(of: playerManager.isPlaying) { _, isPlaying in
                    if isPlaying {
                        startRotation()
                    }
                }
            
            // 发光背景
            Circle()
                .fill(
                    RadialGradient(
                        colors: [NeonColors.purple.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 100,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
            
            // 封面图片
            Group {
                if let station = playerManager.currentStation {
                    if let url = URL(string: station.favicon), !station.favicon.isEmpty {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                PlaceholderView(name: station.name, id: station.stationuuid)
                            }
                        }
                    } else {
                        PlaceholderView(name: station.name, id: station.stationuuid)
                    }
                } else {
                    ZStack {
                        NeonColors.cardBg
                        Image(systemName: "radio.fill")
                            .font(.system(size: 80))
                            .foregroundColor(NeonColors.cyan.opacity(0.3))
                    }
                }
            }
            .frame(width: 260, height: 260)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: NeonColors.purple.opacity(0.5), radius: 30, x: 0, y: 10)
        }
    }
    
    // MARK: - 电台信息
    private var stationInfo: some View {
        VStack(spacing: 8) {
            Text(playerManager.currentStation?.name ?? "未选择电台")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 20)
            
            Text(playerManager.currentStation?.tags ?? "")
                .font(.system(size: 15))
                .foregroundColor(NeonColors.cyan.opacity(0.7))
                .lineLimit(1)
        }
    }
    
    // MARK: - 控制按钮
    private var controlButtons: some View {
        HStack(spacing: 20) {
            // 收藏按钮
            if let station = playerManager.currentStation {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        favoritesManager.toggleFavorite(station)
                    }
                }) {
                    Image(systemName: favoritesManager.isFavorite(station) ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundColor(favoritesManager.isFavorite(station) ? NeonColors.magenta : .white.opacity(0.6))
                        .frame(width: 44, height: 44)
                }
                .neonGlow(color: favoritesManager.isFavorite(station) ? NeonColors.magenta : .clear, radius: 6)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            
            // 上一首
            Button(action: {
                playerManager.playPrevious()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            
            // 播放/暂停
            PlayButton(isPlaying: playerManager.isPlaying) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    playerManager.togglePlayPause()
                }
            }
            .keyboardShortcut(.space, modifiers: [])
            
            // 下一首
            Button(action: {
                playerManager.playNext()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            


            // 列表按钮
            Button(action: {
                showFavoritesList = true
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 44, height: 44)
            }
            .sheet(isPresented: $showFavoritesList) {
                FavoritesListView(onStationSelected: { station in
                    playerManager.play(station: station, in: FavoritesManager.shared.favoriteStations)
                    showFavoritesList = false
                })
            }
            

        }
        .padding(.horizontal, 20)
        .sheet(item: $shazamMatcher.lastMatch) { match in
            SongResultView(match: match)
        }
    }
    
    // MARK: - 音量控制
    private var volumeControl: some View {
        HStack(spacing: 16) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
            
            NeonSlider(value: $volume, trackColor: NeonColors.cyan)
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - 辅助方法
    private func startRotation() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
    

}

// 移除旧的 VisualizerView，使用 DesignSystem 中的 EnhancedVisualizerView

struct SongResultView: View {
    let match: SHMatchedMediaItem
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            NeonColors.darkBg.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Artwork
                if let url = match.artworkURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(12)
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: 200, height: 200)
                    .shadow(color: NeonColors.purple.opacity(0.5), radius: 20)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundColor(NeonColors.cyan)
                        .frame(width: 200, height: 200)
                        .background(NeonColors.cardBg)
                        .cornerRadius(12)
                }
                
                // Info
                VStack(spacing: 8) {
                    Text(match.title ?? "Unknown Title")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(match.artist ?? "Unknown Artist")
                        .font(.headline)
                        .foregroundColor(NeonColors.cyan)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Apple Music Button
                if let appleMusicURL = match.appleMusicURL {
                    Link(destination: appleMusicURL) {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text("Open in Apple Music")
                        }
                        .padding()
                        .background(NeonColors.magenta)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                
                Spacer()
            }
            .padding(.top, 50)
        }
    }
}


