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
        
        for line in components {
            // Regex for [mm:ss.xx] or [mm:ss.xxx]
            // Example: [00:12.34]Hello world
            
            // Simple manual parsing to avoid complex regex if possible, but regex is safer for variations.
            // Using a standard regex for timestamp extraction.
            let pattern = "\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\](.*)"
            
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: line.utf16.count)
                
                if let match = regex.firstMatch(in: line, options: [], range: range) {
                    // Extract minutes, seconds, milliseconds/hundredths
                    if let minuteRange = Range(match.range(at: 1), in: line),
                       let secondRange = Range(match.range(at: 2), in: line),
                       let millisRange = Range(match.range(at: 3), in: line),
                       let textRange = Range(match.range(at: 4), in: line) { // Group 4 is text
                        
                        let minutes = Double(line[minuteRange]) ?? 0
                        let seconds = Double(line[secondRange]) ?? 0
                        let millisStr = String(line[millisRange])
                        
                        // Handle 2 or 3 digit milliseconds
                        let millisDivider = (millisStr.count == 3) ? 1000.0 : 100.0
                        let millis = (Double(millisStr) ?? 0) / millisDivider
                        
                        let totalTime = (minutes * 60) + seconds + millis
                        let text = String(line[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // 过滤掉空行，只保留有歌词内容的行
                        if !text.isEmpty {
                            lines.append(LyricLine(time: totalTime, text: text))
                        }
                    }
                }
            } catch {
                print("LRC Parsing Error: \(error)")
            }
        }
        
        return lines.sorted { $0.time < $1.time }
    }
}
