import Foundation
import Combine
import ShazamKit
import AVFoundation
import MusicKit

struct CustomMatchResult {
    let title: String
    let artist: String
    let album: String? // Added
    let artworkURL: URL?
    let releaseDate: Date? // 发行日期，用于时光机功能
}


@MainActor
class ShazamMatcher: NSObject, ObservableObject {
    static let shared = ShazamMatcher()
    
    // Published properties to update UI
    @Published var isMatching = false
    @Published var lastMatch: SHMatchedMediaItem?
    @Published var lastError: Error?
    @Published var matchingProgress: String = ""
    @Published var lyrics: String? //  New lyrics property
    @Published var isFetchingLyrics = false // 歌词加载状态
    
    // 歌词同步数据
    @Published var matchDate: Date? // 识别成功的时间点
    @Published var matchOffset: TimeInterval = 0 // 识别时歌曲的进度
    @Published var lyricsOffset: TimeInterval = 0 // 用户手动调整的歌词偏移量（正数=歌词慢，负数=歌词快）
    
    // 计算属性：当前歌曲的预估进度
    var currentSongTime: TimeInterval {
        guard let matchDate = matchDate else { return 0 }
        let timeSinceMatch = Date().timeIntervalSince(matchDate)
        return matchOffset + timeSinceMatch - lyricsOffset
    }
    
    /// 歌词后退 1 秒（显示更早的歌词）
    func adjustLyricsBackward() {
        lyricsOffset += 1.0
    }
    
    /// 歌词前进 1 秒（显示更晚的歌词）
    func adjustLyricsForward() {
        lyricsOffset -= 1.0
    }
    
    /// 重置歌词偏移量
    func resetLyricsOffset() {
        lyricsOffset = 0
    }
    
    // ACRCloud 集成
    @Published var showAdvancedRecognitionPrompt = false
    @Published var remainingCredits: Int = SubscriptionManager.shared.currentCredits
    
    // 自定义匹配结果 (用于 QQ 音乐等非 Shazam 源)
    @Published var customMatchResult: CustomMatchResult?
    
    // 内部记录当前正在匹配的文件
    var currentMatchingFileURL: URL?
    private var captureStartTime: Date? // 记录采集开始的时间
    private var captureEndTime: Date? // 记录采集完成的时间
    private var isHLSStream: Bool = false // 是否是 HLS 流
    private var hlsStreamOffset: TimeInterval = 0 // HLS 动态偏移量
    
    // 锁屏触发标志 (用于自动降级到 ACRCloud)
    var isLockScreenTriggered = false
    
    private var session: SHSession?
    
    override init() {
        super.init()
        session = SHSession()
        session?.delegate = self
    }
    

    
    // MARK: - 主入口：开始识别
    
    /// 从当前播放的电台识别歌曲
    /// - Parameter fromLockScreen: 是否来自锁屏触发
    func startMatching(fromLockScreen: Bool = false) {
        guard !isMatching else { return }
        
        self.isLockScreenTriggered = fromLockScreen
        
        // 立即清除之前的状态，确保 UI 正确响应
        lastError = nil
        lastMatch = nil
        customMatchResult = nil // Reset custom match
        customMatchResult = nil // Reset custom match
        lyrics = nil // Reset lyrics
        isFetchingLyrics = false
        matchDate = nil // Reset match date
        matchOffset = 0 // Reset offset
        
        // 获取当前播放的电台 URL
        guard let station = AudioPlayerManager.shared.currentStation,
              !station.urlResolved.isEmpty else {
            lastError = NSError(domain: "ShazamMatcher", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "没有正在播放的电台"])
            return
        }
        
        
        isMatching = true
        matchingProgress = "正在采集音频..."
        self.captureStartTime = Date() // 记录采集开始时间
        self.captureEndTime = nil // 重置
        
        // 确保 session 已初始化
        if session == nil {
            session = SHSession()
            session?.delegate = self
        }
        
        print("ShazamMatcher: 开始识别...")
        
        // 使用 StreamSampler 下载音频片段
        StreamSampler.shared.sampleStream(from: station.urlResolved) { [weak self] fileURL, isHLS, hlsOffset in
            guard let self = self else { return }
            
            if let fileURL = fileURL {
                DispatchQueue.main.async {
                    self.matchingProgress = "正在识别..."
                    self.captureEndTime = Date() // 记录采集完成时间
                    self.currentMatchingFileURL = fileURL // 保存 URL 供兜底使用
                    self.isHLSStream = isHLS
                    self.hlsStreamOffset = hlsOffset
                    self.matchFile(at: fileURL)
                }
            } else {
                self.handleFailure(error: NSError(domain: "ShazamMatcher", code: -2,
                                                userInfo: [NSLocalizedDescriptionKey: "无法获取音频数据"]))
            }
        }
    }
    
    

    
    /// 统一失败处理
    private func handleFailure(error: Error) {
        DispatchQueue.main.async {
            self.isMatching = false
            self.matchingProgress = ""
            self.lastError = error
            self.isLockScreenTriggered = false
            print("ShazamMatcher: Error - \(error.localizedDescription)")
        }
    }
    
    /// 停止识别
    func stopMatching() {
        StreamSampler.shared.cancel()
        isMatching = false
        isLockScreenTriggered = false
        matchingProgress = ""
    }
    
    // MARK: - 从 AudioTap 接收缓冲区（如果 AudioTap 可用）
    
    func match(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard isMatching else { return }
        // 如果 AudioTap 工作，直接使用流式识别
        session?.matchStreamingBuffer(buffer, at: time)
    }
    
    // MARK: - 文件匹配（公开方法，供测试使用）
    

    
    // MARK: - 文件匹配（内部实现）
    
    // MARK: - 文件匹配（内部实现）
    
    private func matchFile(at url: URL) {
        Task {
            do {
                // 尝试使用 AVAudioFile（支持 mp3, aac, m4a 等）
                // 如果是 TS 文件，先进行手动解包
                let buffer: AVAudioPCMBuffer
                
                if url.pathExtension.lowercased() == "ts" {
                    print("ShazamMatcher: 使用 TSUnpacker 手动解包 TS 文件...")
                    buffer = try self.readTSAudioWithUnpacker(from: url)
                } else {
                    do {
                        print("ShazamMatcher: 尝试使用 AVAudioFile 读取...")
                        buffer = try self.readAudioWithAudioFile(from: url)
                    } catch {
                        print("ShazamMatcher: AVAudioFile 读取失败 (\(error.localizedDescription))，切换到 AVAssetReader 兜底方案...")
                        buffer = try await self.readAudioWithAsset(from: url)
                    }
                }
                
                // 转换为 Mono 44.1kHz（ShazamKit 推荐格式）
                let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)!
                let bufferToMatch: AVAudioPCMBuffer
                
                if buffer.format.sampleRate != targetFormat.sampleRate || buffer.format.channelCount != targetFormat.channelCount {
                    bufferToMatch = try self.convertBuffer(buffer, to: targetFormat)
                } else {
                    bufferToMatch = buffer
                }
                
                print("ShazamMatcher: 音频准备完成，帧数: \(bufferToMatch.frameLength)")
                
                // 生成签名并匹配
                let generator = SHSignatureGenerator()
                try generator.append(bufferToMatch, at: nil)
                let signature = generator.signature()
                self.session?.match(signature)
                
            } catch {
                self.handleFailure(error: error)
            }
        }
    }
    
    // MARK: - 使用 AVAssetReader 读取 (兜底方案，抗干扰能力更强)
    
    private func readAudioWithAsset(from url: URL) async throws -> AVAudioPCMBuffer {
        let asset = AVURLAsset(url: url)
        
        // 尝试加载音频轨道
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else {
            throw NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "轨道加载失败或无音频轨"])
        }
        
        let reader = try AVAssetReader(asset: asset)
        
        // 输出格式：44.1kHz Float32 Mono (Shazam 喜欢的格式)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(output)
        
        guard reader.startReading() else {
            throw reader.error ?? NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "AssetReader 启动失败"])
        }
        
        var samples = Data()
        var format: AVAudioFormat?
        
        // 限制采样时长，防止内存溢出
        let maxSamples = 12 * 44100
        var totalSamples = 0
        
        while reader.status == .reading && totalSamples < maxSamples {
            if let sampleBuffer = output.copyNextSampleBuffer() {
                if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                    let length = CMBlockBufferGetDataLength(blockBuffer)
                    var data = [UInt8](repeating: 0, count: length)
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &data)
                    samples.append(contentsOf: data)
                    totalSamples += length / 4 // Float32 is 4 bytes
                }
            } else {
                break
            }
        }
        
        if reader.status == .failed {
            throw reader.error ?? NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "读取过程中出错"])
        }
        
        format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)
        let frameCount = AVAudioFrameCount(samples.count / 4)
        
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: frameCount) else {
            throw NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "Buffer 创建失败"])
        }
        
        samples.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: Float.self) {
                pcmBuffer.floatChannelData?.pointee.assign(from: baseAddress, count: Int(frameCount))
            }
        }
        pcmBuffer.frameLength = frameCount
        
        return pcmBuffer
    }
    
    // MARK: - 使用 AVAudioFile 读取（适用于 mp3, aac, m4a 等）
    
    private func readAudioWithAudioFile(from url: URL) throws -> AVAudioPCMBuffer {
        let audioFile = try AVAudioFile(forReading: url)
        let processingFormat = audioFile.processingFormat
        
        // Limit to 12 seconds to satisfy ShazamKit requirements and avoid Error 201
        let maxDuration: TimeInterval = 12.0
        let maxFrames = AVAudioFrameCount(processingFormat.sampleRate * maxDuration)
        let framesToRead = min(AVAudioFrameCount(audioFile.length), maxFrames)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: framesToRead) else {
            throw NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建缓冲区"])
        }
        
        try audioFile.read(into: buffer)
        print("ShazamMatcher: 读取音频文件完成，实际时长: \(Double(buffer.frameLength) / processingFormat.sampleRate)s")
        
        return buffer
    }
    
    // MARK: - 手动解包 TS 并读取
    
    private func readTSAudioWithUnpacker(from url: URL) throws -> AVAudioPCMBuffer {
        // 1. 读取 TS 数据
        let tsData = try Data(contentsOf: url)
        
        // 2. 解包 AAC
        let aacData = TSUnpacker.extractAudio(from: tsData)
        guard !aacData.isEmpty else {
            throw NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "TS 解包失败，无音频数据"])
        }
        
        // 3. 保存为临时 .aac 文件
        // 必须使用 .aac 后缀，AVAudioFile 才能识别 ADTS 格式
        let tempAACURL = FileManager.default.temporaryDirectory.appendingPathComponent("stream_sample_extracted.aac")
        try? FileManager.default.removeItem(at: tempAACURL)
        try aacData.write(to: tempAACURL)
        
        print("ShazamMatcher: 已保存解包 AAC 文件: \(aacData.count) bytes")
        
        // 4. 使用 AVAudioFile 读取 .aac
        return try readAudioWithAudioFile(from: tempAACURL)
    }
    
    // MARK: - 音频格式转换
    
    private func convertBuffer(_ inputBuffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard let converter = AVAudioConverter(from: inputBuffer.format, to: targetFormat) else {
            throw NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建转换器"])
        }
        
        let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            throw NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建输出缓冲区"])
        }
        
        let state = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
        state.initialize(to: false)
        defer { state.deallocate() }
        
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if state.pointee {
                outStatus.pointee = .endOfStream
                return nil
            }
            state.pointee = true
            outStatus.pointee = .haveData
            return inputBuffer
        }
        
        var error: NSError?
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            throw error
        }
        
        return outputBuffer
    }
    // MARK: - 重置状态
    
    /// 重置所有识别状态（通常在切歌时调用）
    func reset() {
        stopMatching()
        
        DispatchQueue.main.async {
            self.lastMatch = nil
            self.customMatchResult = nil
            self.lyrics = nil
            self.isFetchingLyrics = false
            self.matchDate = nil // Reset match date
            self.matchOffset = 0 // Reset offset
            self.lyricsOffset = 0 // Reset lyrics manual offset
            self.lastError = nil
            self.isMatching = false
            self.matchingProgress = ""
        }
    }
}

// MARK: - SHSessionDelegate
extension ShazamMatcher: SHSessionDelegate {
    
    func session(_ session: SHSession, didFind match: SHMatch) {
        DispatchQueue.main.async {
            // 防止重复处理
            guard self.isMatching else { return }
            
            self.isMatching = false
            self.matchingProgress = ""
            
            // 优先选择非 Live / Demo 版本
            // 遍历所有匹配结果，寻找标题中不包含 "Live" 或 "Demo" 的项
            let validMatch = match.mediaItems.first { item in
                let title = item.title ?? ""
                return !title.localizedCaseInsensitiveContains("Live") && 
                       !title.localizedCaseInsensitiveContains("Demo")
            } ?? match.mediaItems.first
            
            if let mediaItem = validMatch {
                self.lastMatch = mediaItem
                
                // 记录匹配时间点和偏移量
                // 使用采集开始时间作为基准
                self.matchDate = self.captureStartTime ?? Date()
                
                let rawOffset = mediaItem.predictedCurrentMatchOffset
                
                if self.isHLSStream {
                    // HLS 特有逻辑：需要加上动态片段偏移量
                    self.matchOffset = rawOffset + self.hlsStreamOffset
                    print("Shazam HLS: 应用偏移 +\(String(format: "%.1f", self.hlsStreamOffset))s")
                } else {
                    // MP3 逻辑：用户反馈快了 1s，将之前的 +0.5s 调整为 -0.5s
                    let shazamCorrection: TimeInterval = -0.5
                    self.matchOffset = rawOffset + shazamCorrection
                }
                
                let originalTitle = mediaItem.title ?? ""
                let originalArtist = mediaItem.artist ?? ""
                
                // 尝试提取 album
                var albumTitle: String? = nil
                if let songs = mediaItem.songs.first {
                    albumTitle = songs.albumTitle
                }
                
                // 详细打印 Shazam 匹配结果 (类似 ACRCloud)
                print("\nShazamMatcher Response:")
                print("  - title: \(mediaItem.title ?? "nil")")
                print("  - artist: \(mediaItem.artist ?? "nil")")
                print("  - album: \(albumTitle ?? "nil")")
                print("  - subtitle: \(mediaItem.subtitle ?? "nil")")
                print("  - appleMusicID: \(mediaItem.appleMusicID ?? "nil")")
                print("  - artworkURL: \(mediaItem.artworkURL?.absoluteString ?? "nil")")
                print("  - appleMusicURL: \(mediaItem.appleMusicURL?.absoluteString ?? "nil")")
                print("  - webURL: \(mediaItem.webURL?.absoluteString ?? "nil")")
                print("  - predictedCurrentMatchOffset: \(rawOffset)s")
                print("  - matchCount: \(match.mediaItems.count)")
                
                // 尝试访问 releaseDate (可能需要 iOS 15.0+)
                var releaseDateFromShazam: Date? = nil
                if #available(iOS 15.0, *) {
                    if let releaseDate = mediaItem[SHMediaItemProperty(rawValue: "releaseDate")] as? Date {
                        print("  - releaseDate: \(releaseDate)")
                        releaseDateFromShazam = releaseDate
                    } else {
                        print("  - releaseDate: nil or not available")
                    }
                }
                
                print("\n=== 🎵 Shazam 识别成功 ===")
                print("原始歌曲: \(originalTitle)")
                print("原始歌手: \(originalArtist)")
                print("进度偏移: \(String(format: "%.2f", self.matchOffset))s")
                print("===========================\n")
                
                // 中文转换：先繁体转简体，再清理 Live/Demo 后缀
                var finalTitle = MusicPlatformService.shared.toSimplifiedChinese(originalTitle)
                finalTitle = MusicPlatformService.shared.cleanTitle(finalTitle)
                var finalArtist = MusicPlatformService.shared.toSimplifiedChinese(originalArtist)
                let finalAlbum = MusicPlatformService.shared.toSimplifiedChinese(albumTitle ?? "")
                
                // 检查是否需要拼音转中文
                let needsChineseConversion = MusicPlatformService.shared.isPinyinOrRomanized(finalTitle)
                
                if needsChineseConversion {
                    print("Shazam: 检测到拼音格式，尝试获取中文元数据...")
                }
                
                // Fetch lyrics (同时可能需要中文转换)
                self.isFetchingLyrics = true
                Task {
                    // 0. 尝试获取缺失的发行日期 (如果 Shazam 没给)
                    var finalReleaseDate = releaseDateFromShazam
                    if finalReleaseDate == nil, let appleMusicID = mediaItem.appleMusicID {
                        print("Shazam: 发行日期缺失，尝试通过 iTunes API 获取 (ID: \(appleMusicID))...")
                        if let iTunesDate = await MusicPlatformService.shared.fetchReleaseDateFromiTunes(appleMusicID: appleMusicID) {
                            finalReleaseDate = iTunesDate
                        }
                    }
                    
                    // 如果需要中文转换，先获取中文元数据
                    if needsChineseConversion {
                        if let chineseMeta = await MusicPlatformService.shared.fetchChineseMetadata(title: finalTitle, artist: finalArtist) {
                            finalTitle = chineseMeta.title
                            finalArtist = chineseMeta.artist
                            print("Shazam: 成功转换为中文 - 歌曲: \(finalTitle), 歌手: \(finalArtist)")
                            
                            // 使用 customMatchResult 存储中文结果，覆盖 lastMatch 的显示
                            await MainActor.run {
                                self.customMatchResult = CustomMatchResult(title: finalTitle, artist: finalArtist, album: finalAlbum, artworkURL: mediaItem.artworkURL, releaseDate: finalReleaseDate)
                            }
                        } else {
                            print("Shazam: 无法获取中文元数据，使用原始数据")
                        }
                    } else if finalTitle != originalTitle || finalArtist != originalArtist || (albumTitle != nil && finalAlbum != albumTitle) {
                        // 繁简转换发生了变化，也需要更新 customMatchResult
                        await MainActor.run {
                            self.customMatchResult = CustomMatchResult(title: finalTitle, artist: finalArtist, album: finalAlbum, artworkURL: mediaItem.artworkURL, releaseDate: finalReleaseDate)
                        }
                    }
                    
                    // 确保 customMatchResult 始终被设置 (即使没有转换)
                    await MainActor.run {
                        if self.customMatchResult == nil || (self.customMatchResult?.releaseDate == nil && finalReleaseDate != nil) {
                            self.customMatchResult = CustomMatchResult(title: finalTitle, artist: finalArtist, album: finalAlbum, artworkURL: mediaItem.artworkURL, releaseDate: finalReleaseDate)
                        }
                        
                        // [NEW] 保存到历史记录
                        let currentStationName = AudioPlayerManager.shared.currentStation?.name ?? "未知电台"
                        HistoryManager.shared.addSong(
                            title: finalTitle,
                            artist: finalArtist,
                            album: finalAlbum,
                            artworkURL: mediaItem.artworkURL,
                            appleMusicID: mediaItem.appleMusicID,
                            stationName: currentStationName,
                            source: "Shazam"
                        )
                    }
                    
                    // 获取歌词
                    let fetchedLyrics = await MusicPlatformService.shared.fetchLyrics(
                        title: finalTitle,
                        artist: finalArtist
                    )
                    await MainActor.run {
                        self.lyrics = fetchedLyrics
                        self.isFetchingLyrics = false
                    }
                }
            }
        }
    }
    
    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        DispatchQueue.main.async {
            // 防止重复处理
            guard self.isMatching else { return }

            // 检查是否配置了 ACRCloud
            if ACRCloudConfiguration.accessKey != "YOUR_ACCESS_KEY" {
                print("ShazamMatcher: Shazam 识别失败，准备显示高级识别提示...")
                
                // 仅对 Pro 用户或有配额的用户显示/自动执行
                if SubscriptionManager.shared.isPro && SubscriptionManager.shared.currentCredits > 0 {
                    
                    if self.isLockScreenTriggered {
                        // 锁屏模式下，直接自动尝试 ACRCloud
                        print("ShazamMatcher: 锁屏模式，自动切换到 ACRCloud 高级识别...")
                        self.startAdvancedMatching()
                        return
                    } else {
                        // 在应用内，显示提示
                        self.isMatching = false
                        self.showAdvancedRecognitionPrompt = true
                        // 保持识别文件 URL，以备后续使用
                        return // 挂起，等待用户在 UI 上的操作
                    }
                }
            }
            
            self.isMatching = false
            self.isLockScreenTriggered = false
            self.matchingProgress = ""
            self.currentMatchingFileURL = nil
            
            if let error = error {
                self.lastError = error
                print("ShazamMatcher: Error - \(error.localizedDescription)")
            } else {
                self.lastError = NSError(domain: "ShazamMatcher", code: -3,
                                        userInfo: [NSLocalizedDescriptionKey: "未找到匹配的歌曲"])
                print("ShazamMatcher: No match found")
            }
        }
    }
    
    // MARK: - 触发高级识别
    
    func startAdvancedMatching() {
        guard let fileURL = self.currentMatchingFileURL, 
              SubscriptionManager.shared.currentCredits > 0 else {
            self.showAdvancedRecognitionPrompt = false
            self.isLockScreenTriggered = false
            return
        }
        
        self.showAdvancedRecognitionPrompt = false
        self.isMatching = true
        self.matchingProgress = "正在进行高级识别..."
        
        // Reset previous match results to update UI to matching state
        self.lastMatch = nil
        self.customMatchResult = nil
        
        // 消耗 1 次配额
        SubscriptionManager.shared.consumeCredit()
        self.remainingCredits = SubscriptionManager.shared.currentCredits
        
        ACRCloudMatcher.shared.match(fileURL: fileURL) { [weak self] song, artist, album, offset, releaseDate in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isMatching = false
                self.matchingProgress = ""
                self.currentMatchingFileURL = nil
                
                if let song = song {
                    print("\n=== 🎵 ACRCloud 识别成功 ===")
                    print("原始歌曲: \(song)")
                    print("原始歌手: \(artist ?? "未知")")
                    print("原始专辑: \(album ?? "未知")")
                    print("Offset: \(String(format: "%.2f", offset ?? 0))s")
                    print("===========================\n")
                    
                    // 中文转换：先繁体转简体，再清理 Live/Demo 后缀
                    var finalTitle = MusicPlatformService.shared.toSimplifiedChinese(song)
                    finalTitle = MusicPlatformService.shared.cleanTitle(finalTitle)
                    var finalArtist = MusicPlatformService.shared.toSimplifiedChinese(artist ?? "未知")
                    let finalAlbum = MusicPlatformService.shared.toSimplifiedChinese(album ?? "")
                    
                    // 检查是否需要拼音转中文
                    let needsChineseConversion = MusicPlatformService.shared.isPinyinOrRomanized(finalTitle)
                    
                    if needsChineseConversion {
                        print("ACRCloud: 检测到拼音格式，尝试获取中文元数据...")
                    }
                    
                    // 对于 ACRCloud，同样使用开始采集时间作为基准
                    self.matchDate = self.captureStartTime ?? Date()
                    let rawOffset = offset ?? 0
                    
                    // 根据流类型应用不同的偏移量校正
                    if self.isHLSStream {
                        // HLS 流：加上动态偏移
                        self.matchOffset = rawOffset + self.hlsStreamOffset
                        print("ACRCloud: 应用 HLS 偏移量 +\(String(format: "%.1f", self.hlsStreamOffset))s")
                    } else {
                        // MP3 直播流 (ACRCloud 特有逻辑)
                        let mp3Correction: TimeInterval = -12.0
                        self.matchOffset = rawOffset + mp3Correction
                        print("ACRCloud: 应用 MP3 补偿 \(mp3Correction)s (高级识别特调)")
                    }
                    
                    // Fetch lyrics (同时可能需要中文转换)
                    self.isFetchingLyrics = true
                    Task {
                        // 如果需要中文转换，先获取中文元数据
                        if needsChineseConversion {
                            if let chineseMeta = await MusicPlatformService.shared.fetchChineseMetadata(title: finalTitle, artist: finalArtist) {
                                finalTitle = chineseMeta.title
                                finalArtist = chineseMeta.artist
                                print("ACRCloud: 成功转换为中文 - 歌曲: \(finalTitle), 歌手: \(finalArtist)")
                                
                                // 更新 UI 显示为中文
                                await MainActor.run {
                                    self.customMatchResult = CustomMatchResult(title: finalTitle, artist: finalArtist, album: finalAlbum, artworkURL: nil, releaseDate: releaseDate)
                                }
                            } else {
                                print("ACRCloud: 无法获取中文元数据，使用原始数据")
                            }
                        }
                        
                        // 先设置初始结果（如果还没设置）
                        await MainActor.run {
                            if self.customMatchResult == nil {
                                self.customMatchResult = CustomMatchResult(title: finalTitle, artist: finalArtist, album: finalAlbum, artworkURL: nil, releaseDate: releaseDate)
                            }
                            
                            // [NEW] 保存到历史记录
                            let currentStationName = AudioPlayerManager.shared.currentStation?.name ?? "未知电台"
                            HistoryManager.shared.addSong(
                                title: finalTitle,
                                artist: finalArtist,
                                album: finalAlbum,
                                artworkURL: nil, // ACRCloud 通常没有高质量封面 URL, 暂时留空或后续优化
                                stationName: currentStationName,
                                source: "ACRCloud"
                            )
                        }
                        
                        // 获取歌词
                        let fetchedLyrics = await MusicPlatformService.shared.fetchLyrics(
                            title: finalTitle,
                            artist: finalArtist
                        )
                        await MainActor.run {
                            self.lyrics = fetchedLyrics
                            self.isFetchingLyrics = false
                        }
                    }
                } else {
                    self.lastError = NSError(domain: "ShazamMatcher", code: -4,
                                           userInfo: [NSLocalizedDescriptionKey: "高级识别也未找到匹配歌曲"])
                    print("ShazamMatcher: ACRCloud no match found")
                }
            }
        }
    }
}




