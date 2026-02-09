import SwiftUI

struct LyricsView: View {
    let lyrics: String
    @ObservedObject var matcher: ShazamMatcher
    
    @State private var lyricLines: [LyricLine] = []
    @State private var isUserScrolling = false
    @State private var scrollResumeItem: DispatchWorkItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // 歌词滚动区域
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
                                
                                // Bottom padding to allow scrolling last line to center
                                Color.clear.frame(height: geometry.size.height / 2)
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
            }
            
            // 底部控制区域：调整按钮 + 免责声明
            VStack(spacing: 24) {
                // 歌词调整按钮组（横向排列）
                HStack(spacing: 40) {
                    // 后退按钮 - 歌词显示更早（逆时针箭头）
                    Button(action: {
                        matcher.adjustLyricsBackward()
                    }) {
                        VStack(spacing: 1) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "gobackward.minus")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            Text("-1s")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // 恢复按钮 - 重置偏移量
                    Button(action: {
                        matcher.resetLyricsOffset()
                    }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            Text("重置")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // 前进按钮 - 歌词显示更晚（顺时针箭头）
                    Button(action: {
                        matcher.adjustLyricsForward()
                    }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "goforward.plus")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            Text("+1s")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.top, 4)
                
                // 免责声明
                Text("歌词来源于QQ音乐/网易云音乐，仅供参考")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 2)
            }
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.2)) // 轻微背景区分
            .edgesIgnoringSafeArea(.bottom)
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
