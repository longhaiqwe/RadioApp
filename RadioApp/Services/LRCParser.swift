import Foundation

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

class LRCParser {
    static func parse(lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        
        let components = lrc.components(separatedBy: .newlines)
        
        // 分钟数可为1或2位，毫秒部分可选且可为1到3位，以兼容大部分非标准LRC歌词前缀
        let pattern = "\\[(\\d{1,2}):(\\d{2})(?:\\.(\\d{1,3}))?\\](.*)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        for line in components {
            let range = NSRange(location: 0, length: line.utf16.count)
            
            if let match = regex.firstMatch(in: line, options: [], range: range) {
                // 必须提取分钟和秒
                guard let minuteRange = Range(match.range(at: 1), in: line),
                      let secondRange = Range(match.range(at: 2), in: line) else {
                    continue
                }
                
                let minutes = Double(line[minuteRange]) ?? 0
                let seconds = Double(line[secondRange]) ?? 0
                
                // 提取可选的毫秒数
                var millis: Double = 0.0
                if match.range(at: 3).location != NSNotFound,
                   let millisRange = Range(match.range(at: 3), in: line) {
                    let millisStr = String(line[millisRange])
                    let millisVal = Double(millisStr) ?? 0.0
                    let divider = pow(10.0, Double(millisStr.count))
                    millis = millisVal / divider
                }
                
                // 提取歌词文本
                var text = ""
                if match.range(at: 4).location != NSNotFound,
                   let textRange = Range(match.range(at: 4), in: line) {
                    text = String(line[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                let totalTime = (minutes * 60) + seconds + millis
                
                if !text.isEmpty {
                    lines.append(LyricLine(time: totalTime, text: text))
                }
            }
        }
        
        return lines.sorted { $0.time < $1.time }
    }
}
