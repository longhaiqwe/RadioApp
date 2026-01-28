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
    @State private var loadingPlatform: String? = nil // "netease" or "qq"
    @ObservedObject var shazamMatcher = ShazamMatcher.shared
    
    var body: some View {
        ZStack {
            // MARK: - 动态背景
            playerBackground
            
            VStack(spacing: 0) {
                // MARK: - 顶部栏
                topBar
                    .padding(.top, 20)
                
                // MARK: - Shazam 识别结果 (已移至 Overlay)

                
                Spacer()
                
                // MARK: - 封面区域
                albumArtSection
                
                // MARK: - 可视化
                if playerManager.isPlaying {
                    EnhancedVisualizerView(isPlaying: playerManager.isPlaying)
                        .frame(height: 40)
                        .padding(.vertical, 15)
                } else {
                    Spacer().frame(height: 70)
                }
                
                // MARK: - 电台信息
                stationInfo
                
                Spacer()
                
                // MARK: - 控制按钮
                controlButtons
                    .padding(.bottom, 20)
                
                volumeControl
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
            
            // MARK: - Shazam Overlay Layer
            VStack(spacing: 0) {
                // 顶部留白：TopBar (44) + Padding (20) + Spacing (8)
                Color.clear.frame(height: 72)
                
                if let match = shazamMatcher.lastMatch {
                    shazamResultCard(match: match)
                } else if shazamMatcher.isMatching {
                    shazamMatchingIndicator
                } else if shazamMatcher.lastError != nil {
                    shazamErrorCard
                }
                
                Spacer()
            }
            .allowsHitTesting(shazamMatcher.lastMatch != nil || shazamMatcher.isMatching || shazamMatcher.lastError != nil)
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
            
            // 占位，保持左右对称
            Color.clear.frame(width: 44, height: 44)
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
        HStack(spacing: 12) {
            // Shazam 识别按钮
            Button(action: {
                if shazamMatcher.isMatching {
                    shazamMatcher.stopMatching()
                } else {
                    shazamMatcher.startMatching()
                }
            }) {
                ZStack {
                    if shazamMatcher.isMatching {
                        // 识别中 - 渐变旋转动画
                        Circle()
                            .stroke(
                                AngularGradient(
                                    colors: [NeonColors.cyan, NeonColors.magenta, NeonColors.cyan],
                                    center: .center
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 36, height: 36)
                            .rotationEffect(Angle(degrees: shazamMatcher.isMatching ? 360 : 0))
                            .animation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false), value: shazamMatcher.isMatching)
                        
                        Image(systemName: "shazam.logo.fill")
                            .font(.system(size: 18))
                            .foregroundColor(NeonColors.cyan)
                    } else {
                        // 正常状态
                        Image(systemName: "shazam.logo")
                            .font(.system(size: 22))
                            .foregroundColor(NeonColors.cyan)
                            .frame(width: 36, height: 36)
                    }
                }
            }
            
            // 收藏按钮
            if let station = playerManager.currentStation {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        favoritesManager.toggleFavorite(station)
                    }
                }) {
                    Image(systemName: favoritesManager.isFavorite(station) ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(favoritesManager.isFavorite(station) ? NeonColors.magenta : .white.opacity(0.6))
                        .frame(width: 36, height: 36)
                }
                .neonGlow(color: favoritesManager.isFavorite(station) ? NeonColors.magenta : .clear, radius: 6)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
            
            // 上一首
            Button(action: {
                playerManager.playPrevious()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
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
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            


            // 列表按钮
            Button(action: {
                showFavoritesList = true
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 36, height: 36)
            }
            .sheet(isPresented: $showFavoritesList) {
                FavoritesListView(onStationSelected: { station in
                    playerManager.play(station: station, in: FavoritesManager.shared.favoriteStations)
                    showFavoritesList = false
                })
            }
        }
        .padding(.horizontal, 20)
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
    
    // MARK: - Shazam 识别中指示器
    private var shazamMatchingIndicator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // 旋转的 Shazam 图标
                Image(systemName: "shazam.logo.fill")
                    .font(.system(size: 18))
                    .foregroundColor(NeonColors.cyan)
                    .rotationEffect(Angle(degrees: rotation))
                    .onAppear {
                        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                            rotation = 360
                        }
                    }
                
                Text("识别中...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(NeonColors.cyan)
            }
            
            // 取消按钮
            Button(action: {
                shazamMatcher.stopMatching()
            }) {
                Text("取消")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(NeonColors.cyan.opacity(0.4), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Shazam 识别失败提示卡片
    private var shazamErrorCard: some View {
        VStack(spacing: 12) {
            // 图标
            Image(systemName: "music.note.list")
                .font(.system(size: 32))
                .foregroundColor(NeonColors.magenta.opacity(0.8))
            
            // 提示文字
            VStack(spacing: 4) {
                Text("未能识别歌曲")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("可能是纯音乐、广告或音频质量不佳，也有可能没有收录入曲库")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            // 操作按钮
            HStack(spacing: 16) {
                // 再试一次
                Button(action: {
                    shazamMatcher.lastError = nil
                    shazamMatcher.startMatching()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                        Text("再试一次")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(NeonColors.cyan)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(NeonColors.cyan.opacity(0.6), lineWidth: 1)
                    )
                }
                
                // 关闭
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        shazamMatcher.lastError = nil
                    }
                }) {
                    Text("关闭")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            NeonColors.magenta.opacity(0.15),
                            NeonColors.darkBg.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [NeonColors.magenta.opacity(0.4), NeonColors.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeOut(duration: 0.2), value: shazamMatcher.lastError != nil)
    }
    
    // MARK: - Shazam 识别结果卡片
    private func shazamResultCard(match: SHMatchedMediaItem) -> some View {
        VStack(spacing: 10) {
            // 封面
            if let url = match.artworkURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(NeonColors.purple.opacity(0.3))
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: NeonColors.purple.opacity(0.5), radius: 6)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(NeonColors.purple.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
            
            // 歌曲信息（居中）
            VStack(spacing: 2) {
                Text(match.title ?? "未知歌曲")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                
                Text(match.artist ?? "未知歌手")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
            
            // 音乐平台按钮 - 紧凑图标模式
            HStack(spacing: 24) {
                // Apple Music
                if let appleMusicURL = match.appleMusicURL {
                    Link(destination: appleMusicURL) {
                        MusicIconView(imageName: "AppleMusicLogo", color: NeonColors.magenta, scale: 1.0)
                    }
                }
                
                // 网易云音乐
                Button(action: {
                    Task {
                        await openMusicApp(platform: "netease", title: match.title, artist: match.artist)
                    }
                }) {
                    ZStack {
                        MusicIconView(imageName: "NetEaseLogo", color: .red, scale: 1.2)
                        if loadingPlatform == "netease" {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                    }
                }
                
                // QQ音乐
                Button(action: {
                    Task {
                        await openMusicApp(platform: "qq", title: match.title, artist: match.artist)
                    }
                }) {
                    ZStack {
                        MusicIconView(imageName: "QQMusicLogo", color: .white, scale: 0.7, size: 38)
                        if loadingPlatform == "qq" {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .background(Color.white.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                }
                
                // 关闭按钮
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        shazamMatcher.lastMatch = nil
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            NeonColors.purple.opacity(0.25),
                            NeonColors.darkBg.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [NeonColors.purple.opacity(0.5), NeonColors.cyan.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeOut(duration: 0.2), value: shazamMatcher.lastMatch != nil)
    }
    
    // MARK: - 辅助方法
    private func startRotation() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
    
    private func openMusicApp(platform: String, title: String?, artist: String?) async {
        guard let title = title, let artist = artist else { return }
        guard loadingPlatform == nil else { return }
        
        loadingPlatform = platform
        
        // 1. 尝试获取 Song ID
        var songId: String? = nil
        if platform == "netease" {
            songId = await MusicPlatformService.shared.findNetEaseID(title: title, artist: artist)
        } else if platform == "qq" {
            songId = await MusicPlatformService.shared.findQQMusicID(title: title, artist: artist)
        }
        
        // 2. 构建 URL
        var finalURL: URL? = nil
        
        if let id = songId {
            // ID 直达模式
            if platform == "netease" {
                // 网易云单曲链接: orpheus://song/{id}
                finalURL = URL(string: "orpheus://song/\(id)")
            } else if platform == "qq" {
                // QQ音乐单曲链接
                let jsonStr = "{\"song\":[{\"type\":\"0\",\"songmid\":\"\(id)\"}],\"action\":\"play\"}"
                if let encodedJson = jsonStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    finalURL = URL(string: "qqmusic://qq.com/media/playSonglist?p=\(encodedJson)")
                }
            }
        }
        
        // 3. 降级到搜索模式 (如果没找到 ID)
        if finalURL == nil {
            if platform == "netease" {
                finalURL = getNetEaseSearchURL(title: title, artist: artist)
            } else if platform == "qq" {
                finalURL = getQQMusicSearchURL(title: title, artist: artist)
            }
        }
        
        // 4. 打开链接
        if let url = finalURL {
            await MainActor.run {
                UIApplication.shared.open(url)
            }
        }
        
        loadingPlatform = nil
    }
    
    private func getNetEaseSearchURL(title: String?, artist: String?) -> URL? {
        guard let query = getSmartQuery(title: title, artist: artist) else { return nil }
        // 网易云音乐搜索 Scheme
        // 尝试添加 &type=1 指明搜索单曲，期望能触发搜索
        return URL(string: "orpheus://search?keyword=\(query)&type=1")
    }
    
    private func getQQMusicSearchURL(title: String?, artist: String?) -> URL? {
        guard let query = getSmartQuery(title: title, artist: artist) else { return nil }
        // QQ音乐搜索 Scheme
        // 更新为 qqmusic://qq.com/ui/search?w=... 尝试修复跳转首页问题
        return URL(string: "qqmusic://qq.com/ui/search?w=\(query)")
    }
    
    // 生成更精准的搜索关键词
    private func getSmartQuery(title: String?, artist: String?) -> String? {
        let safeTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let safeArtist = artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        guard !safeTitle.isEmpty else { return nil }
        
        // 组合 歌名 + 歌手
        let rawQuery: String
        if !safeArtist.isEmpty {
            rawQuery = "\(safeTitle) \(safeArtist)"
        } else {
            rawQuery = safeTitle
        }
        
        return rawQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
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



// 统一的音乐图标组件
struct MusicIconView: View {
    let imageName: String
    let color: Color
    var scale: CGFloat = 1.0
    var size: CGFloat = 44.0 // 增加尺寸参数，默认 44
    
    var body: some View {
        ZStack {
            // 背景层
            color.opacity(color == .white ? 1.0 : 0.1) // 白色背景不透明，其他半透明
            
            // 图标层
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(scale)
        }
        .frame(width: size, height: size)   // 使用动态尺寸
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25)) // 圆角随尺寸等比缩放 (11/44 = 0.25)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.25)
                .stroke(color == .white ? Color.black.opacity(0.1) : Color.white.opacity(0.1), lineWidth: 1) // 白底时用深色边框，否则看不见
        )
        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2) // 统一阴影
    }
}
