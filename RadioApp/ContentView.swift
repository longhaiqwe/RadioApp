import SwiftUI

struct ContentView: View {
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @State private var showPlayer = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            HomeView()
            
            // MARK: - Mini Player Bar
            if playerManager.currentStation != nil {
                MiniPlayerBar(showPlayer: $showPlayer)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showPlayer) {
            PlayerView()
        }
    }
}

// MARK: - 霓虹风格 Mini Player
struct MiniPlayerBar: View {
    @Binding var showPlayer: Bool
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            showPlayer = true
        }) {
            HStack(spacing: 14) {
                // 封面
                ZStack {
                    if let station = playerManager.currentStation {
                        if let url = URL(string: station.favicon), !station.favicon.isEmpty {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    PlaceholderView(name: station.name, id: station.stationuuid)
                                }
                            }
                        } else {
                            PlaceholderView(name: station.name, id: station.stationuuid)
                        }
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            playerManager.isPlaying ? NeonColors.cyan.opacity(0.6) : .clear,
                            lineWidth: 1.5
                        )
                )
                .shadow(color: playerManager.isPlaying ? NeonColors.cyan.opacity(0.3) : .clear, radius: 6)
                
                // 电台信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(playerManager.currentStation?.name ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if playerManager.isPlaying {
                            // 迷你可视化
                            HStack(spacing: 2) {
                                ForEach(0..<4, id: \.self) { _ in
                                    MiniVisualizerBar()
                                }
                            }
                            .frame(width: 20, height: 12)
                        }
                        
                        Text(playerManager.isPlaying ? "正在播放" : "已暂停")
                            .font(.system(size: 12))
                            .foregroundColor(playerManager.isPlaying ? NeonColors.cyan : .white.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // 播放/暂停按钮
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        playerManager.togglePlayPause()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [NeonColors.magenta.opacity(0.8), NeonColors.purple.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: NeonColors.magenta.opacity(0.4), radius: 8)
                        
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: playerManager.isPlaying ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // 玻璃态背景
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial.opacity(0.8))
                    
                    RoundedRectangle(cornerRadius: 20)
                        .fill(NeonColors.darkBg.opacity(0.6))
                    
                    // 边框发光
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    NeonColors.cyan.opacity(0.4),
                                    NeonColors.purple.opacity(0.2),
                                    NeonColors.magenta.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: NeonColors.purple.opacity(0.3), radius: 20, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
    }
}

// MARK: - 迷你可视化条
struct MiniVisualizerBar: View {
    @State private var height: CGFloat = 4
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(NeonColors.cyan)
            .frame(width: 3, height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                    height = CGFloat.random(in: 4...12)
                }
            }
    }
}

// MARK: - 视觉效果模糊（保留兼容性）
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}
