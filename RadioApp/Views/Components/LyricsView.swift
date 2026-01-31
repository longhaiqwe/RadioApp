import SwiftUI

struct LyricsView: View {
    let lyrics: String
    @ObservedObject var matcher: ShazamMatcher
    
    @State private var lyricLines: [LyricLine] = []
    
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let currentTime = matcher.currentSongTime
                
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Top padding to push first line to center
                            Color.clear.frame(height: geometry.size.height / 2 - 20)
                            
                            ForEach(lyricLines) { line in
                                let isActive = isLineActive(line, currentTime: currentTime)
                                
                                Text(line.text)
                                    .font(.system(size: isActive ? 24 : 18, weight: isActive ? .bold : .regular))
                                    .foregroundColor(isActive ? .white : .white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                    .scaleEffect(isActive ? 1.1 : 1.0)
                                    .animation(.easeInOut, value: isActive)
                                    .id(line.id)
                                    .onTapGesture {
                                        // Optional: Seek capability could be added here if we controlled playback
                                    }
                            }
                            
                            // Bottom padding
                            Color.clear.frame(height: geometry.size.height / 3)
                            
                            // 歌词来源免责声明
                            Text("歌词来源于第三方平台，仅供参考")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.bottom, 20)
                            
                            Color.clear.frame(height: geometry.size.height / 6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: context.date) { _ in
                        // Auto-scroll
                        if let activeLine = lyricLines.last(where: { $0.time <= currentTime }) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(activeLine.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            self.lyricLines = LRCParser.parse(lrc: lyrics)
        }
        .onChange(of: lyrics) { newLyrics in
            self.lyricLines = LRCParser.parse(lrc: newLyrics)
        }
    }
    
    private func isLineActive(_ line: LyricLine, currentTime: TimeInterval) -> Bool {
        // A line is active if it's the current one being sung.
        // It remains active until the next line's time is reached.
        
        guard let index = lyricLines.firstIndex(of: line) else { return false }
        
        let startTime = line.time
        
        // End time is the start of the next line, or infinity if it's the last line
        let endTime: TimeInterval
        if index < lyricLines.count - 1 {
            endTime = lyricLines[index + 1].time
        } else {
            endTime = TimeInterval.greatestFiniteMagnitude
        }
        
        return currentTime >= startTime && currentTime < endTime
    }
}
