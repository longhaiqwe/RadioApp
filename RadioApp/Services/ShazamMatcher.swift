import Foundation
import Combine
import ShazamKit
import AVFoundation

struct CustomMatchResult {
    let title: String
    let artist: String
    let artworkURL: URL?
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
    
    // 计算属性：当前歌曲的预估进度
    var currentSongTime: TimeInterval {
        guard let matchDate = matchDate else { return 0 }
        let timeSinceMatch = Date().timeIntervalSince(matchDate)
        return matchOffset + timeSinceMatch
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
    
    private var session: SHSession?
    
    override init() {
        super.init()
        session = SHSession()
        session?.delegate = self
    }
    

    
    // MARK: - 主入口：开始识别
    
    /// 从当前播放的电台识别歌曲
    func startMatching() {
        guard !isMatching else { return }
        
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
            print("ShazamMatcher: Error - \(error.localizedDescription)")
        }
    }
    
    /// 停止识别
    func stopMatching() {
        StreamSampler.shared.cancel()
        isMatching = false
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
                
                print("\n=== 🎵 Shazam 识别成功 ===")
                print("歌曲: \(mediaItem.title ?? "未知")")
                print("歌手: \(mediaItem.artist ?? "未知")")
                print("进度偏移: \(String(format: "%.2f", self.matchOffset))s")
                print("===========================\n")
                
                // Fetch lyrics
                self.isFetchingLyrics = true
                Task {
                    let fetchedLyrics = await MusicPlatformService.shared.fetchLyrics(
                        title: mediaItem.title ?? "",
                        artist: mediaItem.artist ?? ""
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
                
                // 仅对 Pro 用户或有配额的用户显示
                if SubscriptionManager.shared.isPro && SubscriptionManager.shared.currentCredits > 0 {
                    self.isMatching = false
                    self.showAdvancedRecognitionPrompt = true
                    // 保持识别文件 URL，以备后续使用
                    return // 挂起，等待用户在 UI 上的操作
                }
            }
            
            self.isMatching = false
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
            return
        }
        
        self.showAdvancedRecognitionPrompt = false
        self.isMatching = true
        self.matchingProgress = "正在进行高级识别..."
        
        // 消耗 1 次配额
        SubscriptionManager.shared.consumeCredit()
        self.remainingCredits = SubscriptionManager.shared.currentCredits
        
        ACRCloudMatcher.shared.match(fileURL: fileURL) { [weak self] song, artist, offset in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isMatching = false
                self.matchingProgress = ""
                self.currentMatchingFileURL = nil
                
                if let song = song {
                    print("\n=== 🎵 ACRCloud 识别成功 ===")
                    print("歌曲: \(song)")
                    print("歌手: \(artist ?? "未知")")
                    print("Offset: \(String(format: "%.2f", offset ?? 0))s")
                    print("===========================\n")
                    
                    self.customMatchResult = CustomMatchResult(title: song, artist: artist ?? "未知", artworkURL: nil)
                    
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
                        // 用户反馈高级识别后歌词快了 3-4 句 (约 12s)
                        // 这可能是因为 ACRCloud 返回的时间戳定义不同（例如指向片段末尾）或者其他延迟
                        let mp3Correction: TimeInterval = -12.0
                        self.matchOffset = rawOffset + mp3Correction
                        print("ACRCloud: 应用 MP3 补偿 \(mp3Correction)s (高级识别特调)")
                    }
                    
                    // Fetch lyrics
                    self.isFetchingLyrics = true
                    Task {
                        let fetchedLyrics = await MusicPlatformService.shared.fetchLyrics(
                            title: song,
                            artist: artist ?? ""
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

class MusicPlatformService {
    static let shared = MusicPlatformService()
    
    // 匹配严格程度
    enum MatchStrictness {
        case strict     // 校歌名和歌手
        case titleOnly  // 仅校验歌名 (忽略歌手不匹配)
    }
    
    private init() {}
    
    // MARK: - QQ Music
    
    /// 搜索 QQ 音乐并获取 SongMID
    func findQQMusicID(title: String, artist: String, strictness: MatchStrictness = .strict) async -> String? {
        // QQ 音乐搜索 API (Mobile Client Endpoint)
        // https://c.y.qq.com/soso/fcgi-bin/client_search_cp?w={Query}&format=json
        
        // 简单的关键词组合
        let query = "\(title) \(artist)"
        print("MusicPlatformService: QQ Music 搜索 Query: \(query), Strictness: \(strictness)")
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?aggr=1&cr=1&flag_qc=0&p=1&n=1&w=\(encodedQuery)&format=json") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // 尝试解析 JSON
            // 结构: data -> song -> list -> [0] -> songmid
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataObj = json["data"] as? [String: Any],
               let songObj = dataObj["song"] as? [String: Any],
               let list = songObj["list"] as? [[String: Any]],
               let firstSong = list.first,
               let songmid = firstSong["songmid"] as? String {
                
                print("MusicPlatformService: QQ Music 找到 SongMID: \(songmid), Title: \(firstSong["songname"] ?? ""), Artist: \(firstSong["singer"] ?? "")")
                
                let resultTitle = firstSong["songname"] as? String ?? ""
                let singers = firstSong["singer"] as? [[String: Any]] ?? []
                let resultArtist = singers.map { $0["name"] as? String ?? "" }.joined(separator: " ")
                
                if isMatch(queryTitle: title, queryArtist: artist, resultTitle: resultTitle, resultArtist: resultArtist, strictness: strictness) {
                    print("MusicPlatformService: QQ Music 匹配成功")
                    return songmid
                } else {
                    print("QQ Music Match Failed: Query('\(title)', '\(artist)') vs Result('\(resultTitle)', '\(resultArtist)')")
                    return nil
                }
            } else {
                print("MusicPlatformService: QQ Music 搜索未找到结果或解析失败")
            }
        } catch {
            print("QQ Music Search Error: \(error)")
        }
        
        return nil
    }
    
    /// 字符串归一化处理：繁转简、去括号内容(可选)、去标点、去语气干扰
    /// - Parameter removeParenthesesContent: 是否移除括号及其内容。歌名通常移除(如"粤语版")，歌手名通常保留(如"陈墨一(三毛)")
    private func normalizeString(_ str: String, removeParenthesesContent: Bool = true) -> String {
        // 1. 繁体转简体
        let simplified = str.applyingTransform(StringTransform("Any-Hans"), reverse: false) ?? str
        
        // 2. 去除括号及其内容 (支持英文(), 中文（）, 方括号 [])
        // 例如: "喜欢你 (粤语版)" -> "喜欢你"
        var result = simplified
        if removeParenthesesContent {
            result = result.replacingOccurrences(of: "\\s*[\\(\\[（\\{][^\\)\\]）\\}]*[\\)\\]）\\}]", with: "", options: .regularExpression)
        }
        
        // 3. 转小写
        result = result.lowercased()
        
        // 4. 移除特定的干扰词 (如 "粤语", "国语", "版本" 等)
        let fillers = ["粤语", "国语", "版", "music", "video", "official"]
        for filler in fillers {
            result = result.replacingOccurrences(of: filler, with: "")
        }
        
        // 5. 移除所有标点符号和空格，保留字母数字和中文字符
        result = result.components(separatedBy: CharacterSet.punctuationCharacters.union(.symbols).union(.whitespacesAndNewlines))
            .joined()
        
        return result
    }
    
    /// 转拼音 helper
    private func toPinyin(_ str: String) -> String {
        // 1. 转拉丁文 (拼音)
        let mutableString = NSMutableString(string: str)
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        
        // 2. 去声调
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        
        // 3. 去空格并转小写
        return (mutableString as String).replacingOccurrences(of: " ", with: "").lowercased()
    }
    
    /// 将歌手字符串处理为 Token 集合，处理分隔符和中英文混合
    private func normalizeArtistTokens(_ text: String) -> Set<String> {
        // 1. 繁体转简体
        var processing = text.applyingTransform(StringTransform("Any-Hans"), reverse: false) ?? text
        
        // 2. 移除括号及其内容 (歌手名中的附加信息通常不影响核心匹配)
        processing = processing.replacingOccurrences(of: "\\s*[\\(\\[（\\{][^\\)\\]）\\}]*[\\)\\]）\\}]", with: "", options: .regularExpression)
        
        // 3. 替换常见分隔符为为空格
        // 包括 & / , + 、 以及 feat ft vs with 等连接词
        let separators = ["&", "/", ",", "+", "、", "feat.", "ft.", "vs.", "with", "_", "|"]
        for sep in separators {
            processing = processing.replacingOccurrences(of: sep, with: " ", options: .caseInsensitive)
        }
        
        // 4. 在中英文之间插入空格 (关键改进：解决 "伯爵Johnny" 连在一起无法匹配 "伯爵" 的问题)
        // 中文 followed by English/Number
        processing = processing.replacingOccurrences(of: "([\\u4e00-\\u9fa5])([a-zA-Z0-9])", with: "$1 $2", options: .regularExpression)
        // English/Number followed by Chinese
        processing = processing.replacingOccurrences(of: "([a-zA-Z0-9])([\\u4e00-\\u9fa5])", with: "$1 $2", options: .regularExpression)
        
        // 5. 转小写
        processing = processing.lowercased()
        
        // 6. 分割并过滤
        let tokens = processing.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) } // 去除残留标点
            .filter { !$0.isEmpty }
            
        return Set(tokens)
    }
    
    /// 增强的匹配校验
    private func isMatch(queryTitle: String, queryArtist: String, resultTitle: String, resultArtist: String, strictness: MatchStrictness) -> Bool {
        // 1. 歌名匹配
        // 保持原有的逻辑：移除括号内容，忽略标点和空格，进行包含判断
        let qTitle = normalizeString(queryTitle, removeParenthesesContent: true)
        let rTitle = normalizeString(resultTitle, removeParenthesesContent: true)
        
        // 标题匹配：只要包含即可 (且不能为空)
        var titleMatch = !qTitle.isEmpty && !rTitle.isEmpty && (qTitle.contains(rTitle) || rTitle.contains(qTitle))
        
        // 如果常规匹配失败，尝试拼音匹配 (解决繁简转换失效或异体字问题)
        if !titleMatch && !qTitle.isEmpty && !rTitle.isEmpty {
            let qPinyin = toPinyin(qTitle)
            let rPinyin = toPinyin(rTitle)
            if qPinyin.contains(rPinyin) || rPinyin.contains(qPinyin) {
                print("MusicPlatformService: 拼音匹配成功 - '\(qPinyin)' vs '\(rPinyin)'")
                titleMatch = true
            } else {
                print("MusicPlatformService: 标题匹配失败 - Text: '\(qTitle)' vs '\(rTitle)', Pinyin: '\(qPinyin)' vs '\(rPinyin)'")
            }
        }
        
        if !titleMatch { return false }
        
        //如果是 titleOnly 模式，直接返回 true
        if strictness == .titleOnly {
            return true
        }
        
        // 2. 歌手匹配 (增强版 Token Set 匹配)
        let qTokens = normalizeArtistTokens(queryArtist)
        let rTokens = normalizeArtistTokens(resultArtist)
        
        // 如果没有任何 Token (比如纯符号)，回退到原始字符串包含检查
        if qTokens.isEmpty || rTokens.isEmpty {
            let qSimple = normalizeString(queryArtist, removeParenthesesContent: false)
            let rSimple = normalizeString(resultArtist, removeParenthesesContent: false)
            return !qSimple.isEmpty && !rSimple.isEmpty && (qSimple.contains(rSimple) || rSimple.contains(qSimple))
        }
        
        // 只要一方是另一方的子集，即认为匹配
        // Case 1: 用户搜 "Linkin Park" (q), 结果 "Linkin Park & Jay-Z" (r). q is subset of r. -> Match
        // Case 2: 用户搜 "伯爵 & 唐伯虎" (q), 结果 "伯爵 Johnny/ 唐伯虎 Annie" (r). q is subset of r. -> Match
        // Case 3: 用户搜 "Artist A feat. B" (q), 结果 "Artist A" (r). r is subset of q. -> Match
        let match1 = qTokens.isSubset(of: rTokens)
        let match2 = rTokens.isSubset(of: qTokens)
        
        return match1 || match2
    }

    
    // MARK: - NetEase Cloud Music
    
    /// 搜索网易云音乐并获取 SongID
    func findNetEaseID(title: String, artist: String, strictness: MatchStrictness = .strict) async -> String? {
        // 网易云搜索 API (Legacy Endpoint)
        // http://music.163.com/api/search/get/web?s={Query}&type=1&offset=0&total=true&limit=1
        
        let query = "\(title) \(artist)"
        print("MusicPlatformService: NetEase 搜索 Query: \(query), Strictness: \(strictness)")
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://music.163.com/api/search/get/web?s=\(encodedQuery)&type=1&offset=0&total=true&limit=1") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // 伪装 Referer 和 User-Agent 以避免部分反爬限制
        request.setValue("http://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // 尝试解析 JSON
            // 结构: result -> songs -> [0] -> id
            // 注意：如果在海外 IP，此接口可能返回 "abroad":true 和加密 result，导致解析失败。
            // 但用户在中国环境下应该能正常获取 JSON。
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let songs = result["songs"] as? [[String: Any]],
               let firstSong = songs.first,
               let id = firstSong["id"] as? Int,
               let resultName = firstSong["name"] as? String {
                
                let singers = firstSong["artists"] as? [[String: Any]] ?? []
                let resultArtist = singers.map { $0["name"] as? String ?? "" }.joined(separator: " ")
                
                if isMatch(queryTitle: title, queryArtist: artist, resultTitle: resultName, resultArtist: resultArtist, strictness: strictness) {
                    print("MusicPlatformService: NetEase 找到 ID: \(id), Name: \(resultName) ✓ 匹配")
                    return String(id)
                } else {
                    print("MusicPlatformService: NetEase 搜索结果不匹配 - Query: '\(title)' vs Result: '\(resultName)', Artist: '\(resultArtist)' ✗")
                    return nil
                }
            } else {
                 print("MusicPlatformService: NetEase 搜索未找到结果或解析失败")
            }
        } catch {
            print("NetEase Search Error: \(error)")
        }
        
        return nil
    }
    // MARK: - Lyrics Fetching
    
    /// 获取歌词 (优先 QQ 音乐，失败则使用网易云)
    func fetchLyrics(title: String, artist: String) async -> String? {
        print("MusicPlatformService: 开始获取歌词 - Title: \(title), Artist: \(artist)")
        
        // 策略 1: 严格匹配 (QQ -> NetEase)
        print("MusicPlatformService: [阶段 1] 尝试严格匹配...")
        if let lyrics = await fetchQQLyrics(title: title, artist: artist, strictness: .strict) {
            print("MusicPlatformService: QQ 音乐 (Strict) 获取成功")
            return lyrics
        }
        if let lyrics = await fetchNetEaseLyrics(title: title, artist: artist, strictness: .strict) {
            print("MusicPlatformService: 网易云 (Strict) 获取成功")
            return lyrics
        }
        
        // 策略 2: 宽松匹配 (仅匹配歌名) (QQ -> NetEase)
        // 当数据库中的歌手名与搜索词差异过大时 (如 Cover vs Original，或者数据缺失)，启动兜底
        print("MusicPlatformService: [阶段 2] 严格匹配失败，尝试宽松匹配 (仅校验歌名)...")
        if let lyrics = await fetchQQLyrics(title: title, artist: artist, strictness: .titleOnly) {
            print("MusicPlatformService: QQ 音乐 (TitleOnly) 获取成功")
            return lyrics
        }
        if let lyrics = await fetchNetEaseLyrics(title: title, artist: artist, strictness: .titleOnly) {
            print("MusicPlatformService: 网易云 (TitleOnly) 获取成功")
            return lyrics
        }
        
        print("MusicPlatformService: 所有平台均未找到歌词")
        return nil
    }
    
    private func fetchQQLyrics(title: String, artist: String, strictness: MatchStrictness) async -> String? {
        guard let songmid = await findQQMusicID(title: title, artist: artist, strictness: strictness) else {
            return nil
        }
        
        // QQ 音乐歌词接口
        // https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid={songmid}&format=json&nobase64=1
        // 注意：QQ 音乐接口通常需要 Referer 和特定的 Header，且可能需要登录 cookie。
        // 这里尝试公开接口，如果失败则返回 nil
        
        let urlString = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=\(songmid)&format=json&nobase64=1"
        guard let url = URL(string: urlString) else { return nil }
        
        // print("MusicPlatformService: 请求 QQ 歌词 URL: \(urlString)")
        
        var request = URLRequest(url: url)
        request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // QQ 音乐有时返回 JSONP，需要处理 (不过这里加了 format=json)
            // 结构: lyric
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                 if let lyric = json["lyric"] as? String {
                    // 解码 HTML 实体 (如果有)
                    return lyric
                 } else {
                     print("MusicPlatformService: QQ 歌词 JSON 解析失败 or 无 lyric 字段. Response: \(json)")
                 }
            }
        } catch {
            print("QQ Music Lyrics Error: \(error)")
        }
        
        return nil
    }
    
    private func fetchNetEaseLyrics(title: String, artist: String, strictness: MatchStrictness) async -> String? {
        guard let id = await findNetEaseID(title: title, artist: artist, strictness: strictness) else {
            return nil
        }
        
        // 网易云歌词接口
        // http://music.163.com/api/song/lyric?id={id}&lv=1&kv=1&tv=-1
        let urlString = "http://music.163.com/api/song/lyric?id=\(id)&lv=1&kv=1&tv=-1"
        guard let url = URL(string: urlString) else { return nil }
        
        // print("MusicPlatformService: 请求网易云歌词 URL: \(urlString)")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let lrc = json["lrc"] as? [String: Any],
                   let lyric = lrc["lyric"] as? String {
                    return lyric
                } else {
                    print("MusicPlatformService: 网易云歌词 JSON 解析失败 or 无 lyric 字段. Response: \(json)")
                }
            }
        } catch {
            print("NetEase Lyrics Error: \(error)")
        }
        
        return nil
    }
}


