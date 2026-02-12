import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - 分享卡片视图
/// 用于生成精美的歌曲分享卡片，支持渲染为图片后分享
struct ShareCardView: View {
    let title: String
    let artist: String
    let album: String?
    let artworkImage: UIImage?
    let stationName: String?
    let timestamp: Date
    let qrCodeURL: String
    
    // 装饰性波形条的随机高度（在初始化时生成，确保渲染一致）
    let waveformHeights: [CGFloat]
    
    init(title: String, artist: String, album: String? = nil, artworkImage: UIImage? = nil,
         stationName: String? = nil, timestamp: Date = Date(),
         qrCodeURL: String = "https://apps.apple.com/app/id6740043165") {
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkImage = artworkImage
        self.stationName = stationName
        self.timestamp = timestamp
        self.qrCodeURL = qrCodeURL
        // 预生成波形高度，避免渲染时随机导致不一致
        self.waveformHeights = (0..<32).map { _ in CGFloat.random(in: 8...40) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 上半部分：封面 + 歌曲信息
            VStack(spacing: 20) {
                Spacer().frame(height: 16)
                
                // 封面图
                artworkSection
                
                // 歌曲信息
                songInfoSection
                
                // 装饰性波形
                waveformDecoration
                
                // 元数据（电台 + 时间）
                metadataSection
            }
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 20)
            
            // 分割线
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.15), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
                .padding(.horizontal, 32)
            
            Spacer().frame(height: 16)
            
            // MARK: - 底部品牌区
            brandingSection
            
            Spacer().frame(height: 20)
        }
        .frame(width: 360)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "00D9FF").opacity(0.4),
                            Color(hex: "8338EC").opacity(0.3),
                            Color(hex: "FF006E").opacity(0.2),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }
    
    // MARK: - 封面区域
    private var artworkSection: some View {
        ZStack {
            // 发光背景
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "8338EC").opacity(0.4), .clear],
                        center: .center,
                        startRadius: 60,
                        endRadius: 160
                    )
                )
                .frame(width: 280, height: 280)
            
            // 封面图片
            if let artwork = artworkImage {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.1), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color(hex: "8338EC").opacity(0.6), radius: 30, x: 0, y: 15)
                    .shadow(color: Color(hex: "00D9FF").opacity(0.3), radius: 20, x: 0, y: 5)
            } else {
                // 无封面占位图
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "1A1A2E"), Color(hex: "151520")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(Color(hex: "00D9FF").opacity(0.5))
                        
                        // 小波形装饰
                        HStack(spacing: 3) {
                            ForEach(0..<8, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color(hex: "00D9FF").opacity(0.3))
                                    .frame(width: 3, height: CGFloat.random(in: 8...24))
                            }
                        }
                    }
                }
                .frame(width: 200, height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "00D9FF").opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color(hex: "8338EC").opacity(0.4), radius: 20, x: 0, y: 10)
            }
        }
    }
    
    // MARK: - 歌曲信息
    private var songInfoSection: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .shadow(color: Color(hex: "00D9FF").opacity(0.3), radius: 8)
            
            // 歌手 | 专辑
            let displayText: String = {
                if let album = album, !album.isEmpty {
                    return "\(artist)  ·  \(album)"
                }
                return artist
            }()
            
            Text(displayText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "00D9FF").opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
    }
    
    // MARK: - 装饰性波形
    private var waveformDecoration: some View {
        HStack(spacing: 3) {
            ForEach(0..<waveformHeights.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "00D9FF"),
                                Color(hex: "8338EC")
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: waveformHeights[index])
                    .shadow(color: Color(hex: "00D9FF").opacity(0.4), radius: 2)
            }
        }
        .frame(height: 44)
        .padding(.vertical, 4)
    }
    
    // MARK: - 元数据（电台 + 时间）
    private var metadataSection: some View {
        HStack(spacing: 16) {
            if let stationName = stationName, !stationName.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "radio.fill")
                        .font(.system(size: 12))
                    Text(stationName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                Text(formatDate(timestamp))
                    .font(.system(size: 13))
            }
            .foregroundColor(.white.opacity(0.4))
        }
    }
    
    // MARK: - 底部品牌区
    private var brandingSection: some View {
        HStack(spacing: 16) {
            // QR 码
            if let qrImage = ShareCardGenerator.generateQRCode(from: qrCodeURL) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("拾音FM")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("发现更多好音乐")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - 卡片背景
    private var cardBackground: some View {
        ZStack {
            // 基底
            Color(hex: "0A0A0F")
            
            // 紫色光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "8338EC").opacity(0.35), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .offset(x: -80, y: -120)
                .blur(radius: 40)
            
            // 青色光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "00D9FF").opacity(0.2), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 100, y: 200)
                .blur(radius: 35)
            
            // 品红光晕
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "FF006E").opacity(0.15), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: 60, y: -50)
                .blur(radius: 30)
            
            // 轻微噪点
            Canvas { context, size in
                for _ in 0..<Int(size.width * size.height / 80) {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.white.opacity(Double.random(in: 0.02...0.06)))
                    )
                }
            }
        }
    }
    
    // MARK: - 日期格式化
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: date)
    }
}
