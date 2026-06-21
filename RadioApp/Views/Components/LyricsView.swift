import SwiftUI

struct LyricsView: View {
    let lyrics: String
    @ObservedObject var matcher: ShazamMatcher
    
    @State private var lyricLines: [LyricLine] = []
    @State private var isUserScrolling = false
    @State private var scrollResumeItem: DispatchWorkItem?
    
    @State private var isAutoScrolling = false
    @State private var autoScrollResetTask: DispatchWorkItem?
    @State private var lastOffset: CGFloat = 0
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // 歌词滚动区域
            GeometryReader { geometry in
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    let currentTime = matcher.currentSongTime
                    
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 20) {
                                // 用于检测滚动位置变化的隐藏 View
                                GeometryReader { geom in
                                    let minY = geom.frame(in: .named("lyricsScrollView")).minY
                                    Color.clear
                                        .preference(key: ViewOffsetKey.self, value: minY)
                                }
                                .frame(height: 0)
                                
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
                        .coordinateSpace(name: "lyricsScrollView")
                        .onPreferenceChange(ViewOffsetKey.self) { offset in
                            handleOffsetChange(offset)
                        }
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { _ in
                                    isUserScrolling = true
                                    scrollResumeItem?.cancel()
                                    scrollResumeItem = nil
                                }
                                .onEnded { _ in
                                    scheduleScrollResume()
                                }
                        )
                        .onChange(of: context.date) { _, _ in
                            // Auto-scroll only if user is not interacting
                            if !isUserScrolling {
                                if let activeLine = lyricLines.last(where: { $0.time <= currentTime }) {
                                    isAutoScrolling = true
                                    autoScrollResetTask?.cancel()
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo(activeLine.id, anchor: .center)
                                    }
                                    let task = DispatchWorkItem {
                                        isAutoScrolling = false
                                    }
                                    autoScrollResetTask = task
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
                                }
                            }
                        }
                        .onAppear {
                            self.scrollProxy = proxy
                        }
                    }
                }
            }
            
            // 底部控制区域：调整按钮 + 免责声明
            VStack(spacing: 24) {
                // 歌词调整按钮组（横向排列）
                HStack(spacing: 24) {
                    // 上一段按钮
                    Button(action: {
                        matcher.jumpToPreviousSection(lyricLines: lyricLines)
                    }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "chevron.backward.2")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            Text("上一段")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    // 后退按钮 - 歌词显示更早（逆时针箭头）
                    Button(action: {
                        matcher.adjustLyricsBackward()
                    }) {
                        VStack(spacing: 6) {
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
                    
                    // 下一段按钮
                    Button(action: {
                        matcher.jumpToNextSection(lyricLines: lyricLines)
                    }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "chevron.forward.2")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            Text("下一段")
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
        .onChange(of: lyrics) { _, newLyrics in
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
    
    private func scheduleScrollResume() {
        scrollResumeItem?.cancel()
        let item = DispatchWorkItem {
            withAnimation {
                isUserScrolling = false
            }
            if let activeLine = lyricLines.last(where: { $0.time <= matcher.currentSongTime }) {
                isAutoScrolling = true
                autoScrollResetTask?.cancel()
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollProxy?.scrollTo(activeLine.id, anchor: .center)
                }
                let task = DispatchWorkItem {
                    isAutoScrolling = false
                }
                autoScrollResetTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
            }
        }
        scrollResumeItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: item)
    }
    
    private func handleOffsetChange(_ offset: CGFloat) {
        let delta = abs(offset - lastOffset)
        lastOffset = offset
        
        guard delta > 0.5 else { return }
        
        if isAutoScrolling {
            return
        }
        
        isUserScrolling = true
        scheduleScrollResume()
    }
}

struct ViewOffsetKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
