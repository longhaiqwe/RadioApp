import SwiftUI

struct PlaceholderView: View {
    let name: String
    let id: String
    
    // 霓虹风格渐变色板
    private let gradients = [
        [Color(hex: "00D9FF"), Color(hex: "8338EC")], // 青紫
        [Color(hex: "FF006E"), Color(hex: "8338EC")], // 品红紫
        [Color(hex: "00F5D4"), Color(hex: "00D9FF")], // 薄荷青
        [Color(hex: "FFD23F"), Color(hex: "FF006E")], // 金红
        [Color(hex: "7B2CBF"), Color(hex: "00D9FF")], // 电紫青
        [Color(hex: "FF5E78"), Color(hex: "8338EC")], // 暖粉紫
        [Color(hex: "00D9FF"), Color(hex: "00F5D4")], // 青薄荷
        [Color(hex: "8338EC"), Color(hex: "FF006E")], // 紫品红
        [Color(hex: "FF006E"), Color(hex: "FFD23F")], // 品红金
        [Color(hex: "7B2CBF"), Color(hex: "FF5E78")], // 电紫粉
    ]
    
    private var stationGradient: [Color] {
        var hasher = Hasher()
        hasher.combine(id)
        let hash = abs(hasher.finalize())
        let index = hash % gradients.count
        return gradients[index]
    }
    
    private var displayText: String {
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 渐变背景
                LinearGradient(
                    gradient: Gradient(colors: stationGradient),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // 噪点纹理
                NoiseTexture()
                    .opacity(0.08)
                
                // 装饰性元素
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: geometry.size.width * 0.6, height: geometry.size.width * 0.6)
                    .offset(x: geometry.size.width * 0.3, y: -geometry.size.height * 0.2)
                    .blur(radius: 20)
                
                // 电台名称
                Text(displayText)
                    .font(.system(size: geometry.size.width * 0.15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .minimumScaleFactor(0.4)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - 噪点纹理
struct NoiseTexture: View {
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for _ in 0..<Int(size.width * size.height / 80) {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let opacity = Double.random(in: 0.05...0.2)
                    
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
        }
    }
}

// MARK: - Hex Color 扩展（保留兼容性）
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
