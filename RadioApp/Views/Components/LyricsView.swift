import SwiftUI

struct LyricsView: View {
    let lyrics: String
    @ObservedObject var matcher: ShazamMatcher
    
    @State private var lyricLines: [LyricLine] = []
    @State private var isUserScrolling = false
    @State private var scrollResumeItem: DispatchWorkItem?
    
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let currentTime = matcher.currentSongTime
                
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Top padding to push first line to center
                            Color.clear.frame(height: geometry.size.height / 2 - 20)
                            
                            ForEach(lyricLines) { line in
                                let isActive = isLineActive(line, currentTime: currentTime)
                                
                                Text(line.text)
                                    .font(.system(size: isActive ? 18 : 16, weight: isActive ? .bold : .regular))
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
                            
                            // 歌词来源免责声明 - Moved out
                            
                            Color.clear.frame(height: geometry.size.height / 6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { _ in
                                isUserScrolling = true
                                scrollResumeItem?.cancel()
                                scrollResumeItem = nil
                            }
                            .onEnded { _ in
                                let item = DispatchWorkItem {
                                    withAnimation {
                                        isUserScrolling = false
                                    }
                                }
                                scrollResumeItem = item
                                DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: item)
                            }
                    )
                    .onChange(of: context.date) { _ in
                        // Auto-scroll only if user is not interacting
                        if !isUserScrolling {
                            if let activeLine = lyricLines.last(where: { $0.time <= currentTime }) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(activeLine.id, anchor: .center)
                                }
                            }
                        }
                    }
                    }
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 0) {
                        // 渐变遮罩，让歌词淡出
                        LinearGradient(
                            colors: [.clear, Color.black.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                        
                        // 歌词调整按钮区域
                        HStack(spacing: 40) {
                            // 后退按钮 - 歌词显示更早
                            Button(action: {
                                matcher.adjustLyricsBackward()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 12))
                                    Text("0.5s")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(16)
                            }
                            
                            // 前进按钮 - 歌词显示更晚
                            Button(action: {
                                matcher.adjustLyricsForward()
                            }) {
                                HStack(spacing: 4) {
                                    Text("0.5s")
                                        .font(.system(size: 12, weight: .medium))
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(16)
                            }
                        }
                        .padding(.bottom, 8)
                        .background(Color.black.opacity(0.8))
                        
                        // 免责声明（带背景色）
                        Text("歌词来源于第三方平台，仅供参考")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.8))
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
