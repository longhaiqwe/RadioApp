import SwiftUI

/// 时光机标签视图 - 显示歌曲发行年代信息
struct TimeMachineTagView: View {
    let releaseDate: Date
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 10))
            Text(timeDescription)
                .font(.system(size: 11))
        }
        .foregroundColor(NeonColors.cyan.opacity(0.8))
        .padding(.top, 2)
    }
    
    /// 生成时光穿越描述文案
    private var timeDescription: String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: releaseDate)
        let currentYear = calendar.component(.year, from: Date())
        let yearsAgo = currentYear - year
        
        if yearsAgo <= 0 {
            // 今年或未来的歌曲
            return "\(year) 年发行的新歌"
        } else if yearsAgo == 1 {
            // 去年的歌曲
            return "去年发行"
        } else {
            // 多年前的歌曲
            return "发行于 \(year) 年，已经 \(yearsAgo) 年了"
        }
    }
}

// MARK: - 预览
#Preview {
    VStack(spacing: 20) {
        // 新歌（今年）
        TimeMachineTagView(releaseDate: Date())
        
        // 去年的歌
        TimeMachineTagView(releaseDate: Calendar.current.date(byAdding: .year, value: -1, to: Date())!)
        
        // 5 年前
        TimeMachineTagView(releaseDate: Calendar.current.date(byAdding: .year, value: -5, to: Date())!)
        
        // 18 年前（经典歌曲）
        TimeMachineTagView(releaseDate: Calendar.current.date(byAdding: .year, value: -18, to: Date())!)
    }
    .padding()
    .background(NeonColors.darkBg)
}
