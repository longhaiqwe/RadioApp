import SwiftUI

// MARK: - 霓虹色彩系统
struct NeonColors {
    // 主要霓虹色
    static let cyan = Color(hex: "00D9FF")
    static let magenta = Color(hex: "FF006E")
    static let purple = Color(hex: "8338EC")
    static let electric = Color(hex: "7B2CBF")
    
    // 辅助色
    static let warmPink = Color(hex: "FF5E78")
    static let mint = Color(hex: "00F5D4")
    static let gold = Color(hex: "FFD23F")
    
    // 背景色
    static let darkBg = Color(hex: "0A0A0F")
    static let cardBg = Color(hex: "151520")
    static let surfaceBg = Color(hex: "1A1A2E")
    
    // 渐变
    static let primaryGradient = LinearGradient(
        colors: [cyan, purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [magenta, purple],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let backgroundGradient = LinearGradient(
        colors: [darkBg, surfaceBg, Color(hex: "16213E")],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - 玻璃态效果
struct GlassmorphicBackground: View {
    var cornerRadius: CGFloat = 20
    var glowColor: Color = NeonColors.cyan
    var showBorder: Bool = true
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial.opacity(0.5))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(NeonColors.cardBg.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [glowColor.opacity(0.6), glowColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: showBorder ? 1 : 0
                    )
            )
    }
}

// MARK: - 发光效果修饰符
struct NeonGlow: ViewModifier {
    var color: Color
    var radius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.8), radius: radius / 2, x: 0, y: 0)
            .shadow(color: color.opacity(0.5), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.3), radius: radius * 1.5, x: 0, y: 0)
    }
}

extension View {
    func neonGlow(color: Color = NeonColors.cyan, radius: CGFloat = 10) -> some View {
        self.modifier(NeonGlow(color: color, radius: radius))
    }
}

// MARK: - 动态背景
struct AnimatedMeshBackground: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        Canvas { context, size in
            // 深色基底
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(NeonColors.darkBg)
            )
        }
        .overlay(
            // 动态渐变层
            ZStack {
                // 紫色光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NeonColors.purple.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                    .frame(width: 600, height: 600)
                    .offset(x: -100, y: -200)
                    .blur(radius: 60)
                
                // 青色光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NeonColors.cyan.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 250
                        )
                    )
                    .frame(width: 500, height: 500)
                    .offset(x: 150, y: 300)
                    .blur(radius: 50)
                
                // 品红色光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NeonColors.magenta.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: 50 + sin(phase) * 20, y: -100 + cos(phase) * 15)
                    .blur(radius: 40)
            }
        )
        .overlay(
            // 噪点纹理
            NoiseOverlay()
                .opacity(0.03)
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - 噪点纹理
struct NoiseOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for _ in 0..<Int(size.width * size.height / 50) {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let opacity = Double.random(in: 0.1...0.3)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
    }
}

// MARK: - 霓虹按钮样式
struct NeonButtonStyle: ButtonStyle {
    var glowColor: Color = NeonColors.magenta
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .neonGlow(color: glowColor, radius: configuration.isPressed ? 15 : 10)
    }
}

// MARK: - 播放按钮
struct PlayButton: View {
    let isPlaying: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 外圈发光
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NeonColors.magenta.opacity(0.6), NeonColors.purple.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                
                // 主按钮
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [NeonColors.magenta, NeonColors.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: NeonColors.magenta.opacity(0.8), radius: 15, x: 0, y: 5)
                
                // 图标
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: isPlaying ? 0 : 2)
            }
        }
        .buttonStyle(NeonButtonStyle(glowColor: NeonColors.magenta))
    }
}

// MARK: - 音量滑块
struct NeonSlider: View {
    @Binding var value: CGFloat
    var range: ClosedRange<CGFloat> = 0...1
    var trackColor: Color = NeonColors.cyan
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let handleX = width * percentage
            
            ZStack(alignment: .leading) {
                // 背景轨道
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)
                
                // 填充轨道
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [trackColor, trackColor.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: handleX, height: 4)
                    .shadow(color: trackColor.opacity(0.6), radius: 4)
                
                // 滑块
                Circle()
                    .fill(trackColor)
                    .frame(width: 16, height: 16)
                    .shadow(color: trackColor.opacity(0.8), radius: 6)
                    .offset(x: handleX - 8)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let newValue = range.lowerBound + (gesture.location.x / width) * (range.upperBound - range.lowerBound)
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
            )
        }
        .frame(height: 20)
    }
}

// MARK: - 增强版可视化
struct EnhancedVisualizerView: View {
    let isPlaying: Bool
    @State private var heights: [CGFloat] = Array(repeating: 5, count: 30)
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<30, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [NeonColors.cyan, NeonColors.purple],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: heights[index])
                    .shadow(color: NeonColors.cyan.opacity(0.5), radius: 2)
            }
        }
        .onAppear {
            if isPlaying {
                startAnimation()
            }
        }
        .onChange(of: isPlaying) { _, newValue in
            if newValue {
                startAnimation()
            }
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if !isPlaying {
                timer.invalidate()
                return
            }
            withAnimation(.easeInOut(duration: 0.1)) {
                for i in 0..<heights.count {
                    heights[i] = CGFloat.random(in: 5...35)
                }
            }
        }
    }
}

// MARK: - 玻璃态卡片
struct GlassCard<Content: View>: View {
    let content: Content
    var glowColor: Color = NeonColors.cyan
    var cornerRadius: CGFloat = 16
    
    init(glowColor: Color = NeonColors.cyan, cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.glowColor = glowColor
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        content
            .background(
                GlassmorphicBackground(cornerRadius: cornerRadius, glowColor: glowColor)
            )
    }
}

// MARK: - 脉冲动画（正在播放指示器）
struct PulsingView: View {
    @State private var isPulsing = false
    var color: Color = NeonColors.cyan
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 2)
                .scaleEffect(isPulsing ? 1.3 : 1)
                .opacity(isPulsing ? 0 : 1)
            
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .frame(width: 20, height: 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}
