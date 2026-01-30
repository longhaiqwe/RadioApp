import Foundation
import Combine
import ShazamKit
import AVFoundation

struct CustomMatchResult {
    let title: String
    let artist: String
    let artworkURL: URL?
}


class ShazamMatcher: NSObject, ObservableObject {
    static let shared = ShazamMatcher()
    
    // Published properties to update UI
    @Published var isMatching = false
    @Published var lastMatch: SHMatchedMediaItem?
    @Published var lastError: Error?
    @Published var matchingProgress: String = ""
    @Published var lyrics: String? //  New lyrics property
    
    // 自定义匹配结果 (用于 QQ 音乐等非 Shazam 源)
    @Published var customMatchResult: CustomMatchResult?
    
    // 内部记录当前正在匹配的文件
    var currentMatchingFileURL: URL?
    
    private var session: SHSession?
    
    override init() {
        super.init()
        session = SHSession()
        session?.delegate = self
    }
    
    // MARK: - Retry Configuration
    private let maxAutoRetries = 2
    private var currentRetryAttempt = 0
    
    // MARK: - 主入口：开始识别
    
    /// 从当前播放的电台识别歌曲
    func startMatching() {
        guard !isMatching else { return }
        
        // 立即清除之前的状态，确保 UI 正确响应
        lastError = nil
        lastMatch = nil
        customMatchResult = nil // Reset custom match
        lyrics = nil // Reset lyrics
        currentRetryAttempt = 0 // 重置重试计数
        
        // 获取当前播放的电台 URL
        guard let station = AudioPlayerManager.shared.currentStation,
              !station.urlResolved.isEmpty else {
            lastError = NSError(domain: "ShazamMatcher", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "没有正在播放的电台"])
            return
        }
        
        // 1. 尝试直接使用直播流元数据 (ICY Metadata) - 速度最快
        if let streamTitle = AudioPlayerManager.shared.currentStreamTitle, !streamTitle.isEmpty {
            // 简单过滤：如果元数据包含电台名称，可能只是台标而不是歌名，继续尝试音频识别
            // 但是如果元数据很长或者包含 " - "，则可信度较高
            let isStationName = streamTitle.contains(station.name)
            let hasSeparator = streamTitle.contains(" - ")
            
            if !isStationName || hasSeparator {
                print("ShazamMatcher: 发现流元数据 '\(streamTitle)'，跳过采样直接使用。")
                processMetadataMatch(streamTitle)
                return
            }
        }
        
        isMatching = true
        matchingProgress = "正在采集音频..."
        
        // 确保 session 已初始化
        if session == nil {
            session = SHSession()
            session?.delegate = self
        }
        
        print("ShazamMatcher: 开始识别...")
        
        // 使用 StreamSampler 下载音频片段
        StreamSampler.shared.sampleStream(from: station.urlResolved) { [weak self] fileURL in
            guard let self = self else { return }
            
            if let fileURL = fileURL {
                DispatchQueue.main.async {
                    self.matchingProgress = "正在识别..."
                    self.currentMatchingFileURL = fileURL // 保存 URL 供兜底使用
                }
                self.matchFile(at: fileURL)
            } else {
                self.handleFailure(error: NSError(domain: "ShazamMatcher", code: -2,
                                                userInfo: [NSLocalizedDescriptionKey: "无法获取音频数据"]))
            }
        }
    }
    
    /// 处理元数据匹配
    private func processMetadataMatch(_ rawTitle: String) {
        // 尝试解析 "Artist - Title" 或 "Title - Artist"
        // 这是一个简单的启发式，不一定准确
        var title = rawTitle
        var artist = "未知"
        
        if rawTitle.contains(" - ") {
            let parts = rawTitle.components(separatedBy: " - ")
            if parts.count >= 2 {
                // 常见格式：Artist - Title
                artist = parts[0].trimmingCharacters(in: .whitespaces)
                title = parts[1].trimmingCharacters(in: .whitespaces)
            }
        } else if rawTitle.contains("-") {
             // 尝试无空格分隔
            let parts = rawTitle.components(separatedBy: "-")
            if parts.count >= 2 {
                artist = parts[0].trimmingCharacters(in: .whitespaces)
                title = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        
        print("ShazamMatcher: 解析元数据 -> Title: \(title), Artist: \(artist)")
        
        // 直接设置结果
        DispatchQueue.main.async {
            self.customMatchResult = CustomMatchResult(title: title, artist: artist, artworkURL: nil)
            
            // 尝试获取歌词和封面
            Task {
                let fetchedLyrics = await MusicPlatformService.shared.fetchLyrics(title: title, artist: artist)
                await MainActor.run {
                    self.lyrics = fetchedLyrics
                }
            }
            // 尝试获取 QQ 音乐封面 (可选，MusicPlatformService 需要扩展支持)
        }
    }
    
    /// 执行单次识别循环
    private func performMatchCycle(url: String) {
        let attemptSuffix = currentRetryAttempt > 0 ? " (尝试 \(currentRetryAttempt + 1)/\(maxAutoRetries + 1))" : ""
        
        DispatchQueue.main.async {
            self.matchingProgress = "正在采集音频...\(attemptSuffix)"
        }
        
        // 确保 session 已初始化
        if session == nil {
            session = SHSession()
            session?.delegate = self
        }
        
        print("ShazamMatcher: 开始识别... 第 \(currentRetryAttempt + 1) 次尝试")
        
        // 使用 StreamSampler 下载音频片段
        StreamSampler.shared.sampleStream(from: url) { [weak self] fileURL in
            guard let self = self else { return }
            
            if let fileURL = fileURL {
                DispatchQueue.main.async {
                    self.matchingProgress = "正在识别...\(attemptSuffix)"
                }
                self.matchFile(at: fileURL)
            } else {
                self.handleFailure(error: NSError(domain: "ShazamMatcher", code: -2,
                                                userInfo: [NSLocalizedDescriptionKey: "无法获取音频数据"]))
            }
        }
    }
    
    /// 统一失败处理（包含重试逻辑）
    private func handleFailure(error: Error) {
        // 如果还有重试机会，且不是用户主动取消（这里暂不处理取消，取消会直接 reset）
        if currentRetryAttempt < maxAutoRetries {
            currentRetryAttempt += 1
            print("ShazamMatcher: 识别失败，准备重试... (下次是第 \(currentRetryAttempt + 1) 次)")
            
            if let station = AudioPlayerManager.shared.currentStation {
                // 稍微延迟一下再重试，避免过于频繁
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.performMatchCycle(url: station.urlResolved)
                }
                return
            }
        }
        
        // 最终失败
        DispatchQueue.main.async {
            self.isMatching = false
            self.matchingProgress = ""
            self.lastError = error
            print("ShazamMatcher: Final Error - \(error.localizedDescription)")
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
                    print("ShazamMatcher: 使用 AVAudioFile 读取...")
                    buffer = try self.readAudioWithAudioFile(from: url)
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
        
        var error: NSError?
        var inputConsumed = false
        
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .endOfStream
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }
        
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
            
            if let mediaItem = match.mediaItems.first {
                self.lastMatch = mediaItem
                print("\n=== 🎵 Shazam 识别成功 ===")
                print("歌曲: \(mediaItem.title ?? "未知")")
                print("歌手: \(mediaItem.artist ?? "未知")")
                print("===========================\n")
                
                // Fetch lyrics
                Task {
                    let fetchedLyrics = await MusicPlatformService.shared.fetchLyrics(
                        title: mediaItem.title ?? "",
                        artist: mediaItem.artist ?? ""
                    )
                    await MainActor.run {
                        self.lyrics = fetchedLyrics
                    }
                }
            }
        }
    }
    
    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        DispatchQueue.main.async {
            // 防止重复处理
            guard self.isMatching else { return }

            // 检查是否配置了腾讯云，并且不是已经在跑腾讯云了
            if TencentConfiguration.isValid {
                print("ShazamMatcher: Shazam 识别失败，尝试使用腾讯云 QQ 音乐识别...")
                self.matchingProgress = "Shazam 未找到，尝试 QQ 音乐..."
                
                // 这里需要获取刚才识别的文件 URL
                // 由于 ShazamKit 的 session 回调不带 fileURL，我们需要从外部记录
                // 已经在 startMatching 保存到 currentMatchingFileURL
                if let fileURL = self.currentMatchingFileURL {
                    TencentMPSMatcher.shared.match(fileURL: fileURL) { [weak self] song, artist in
                        guard let self = self else { return }
                        
                        DispatchQueue.main.async {
                            self.isMatching = false
                            self.matchingProgress = ""
                            self.currentMatchingFileURL = nil
                            
                            if let song = song {
                                // 构造一个假的 SHMatchedMediaItem 用于显示
                                // 注意：SHMatchedMediaItem 是只读的，难以直接实例化
                                // 这里我们可能需要修改 lastMatch 的类型或者使用自定义对象
                                // 为了简单，我们先用一种 Hack 或者 UI 层兼容的方式
                                // 由于 Swift 类型限制，我们暂时无法创建 SHMatchedMediaItem
                                // 因此，建议 UI 层读取一个新的 published 属性 `customMatch`
                                
                                print("\n=== 🎵 QQ 音乐识别成功 ===")
                                print("歌曲: \(song)")
                                print("歌手: \(artist ?? "未知")")
                                print("===========================\n")
                                
                                // 这里为了演示，我们使用一个简单的 Struct 包装，
                                // 您需要在 UI 层(PlayerView)同时监听 lastMatch 和 customMatchResult
                                self.customMatchResult = CustomMatchResult(title: song, artist: artist ?? "未知", artworkURL: nil)
                                
                                // Fetch lyrics
                                Task {
                                    let fetchedLyrics = await MusicPlatformService.shared.fetchLyrics(
                                        title: song,
                                        artist: artist ?? ""
                                    )
                                    await MainActor.run {
                                        self.lyrics = fetchedLyrics
                                    }
                                }
                            } else {
                                self.lastError = NSError(domain: "ShazamMatcher", code: -3,
                                                       userInfo: [NSLocalizedDescriptionKey: "未找到匹配的歌曲 (Shazam & QQ Music)"])
                                print("ShazamMatcher: No match found")
                            }
                        }
                    }
                    return // 退出，等待腾讯云结果
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
}

class MusicPlatformService {
    static let shared = MusicPlatformService()
    
    private init() {}
    
    // MARK: - QQ Music
    
    /// 搜索 QQ 音乐并获取 SongMID
    func findQQMusicID(title: String, artist: String) async -> String? {
        // QQ 音乐搜索 API (Mobile Client Endpoint)
        // https://c.y.qq.com/soso/fcgi-bin/client_search_cp?w={Query}&format=json
        
        // 简单的关键词组合
        let query = "\(title) \(artist)"
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
                return songmid
            }
        } catch {
            print("QQ Music Search Error: \(error)")
        }
        
        return nil
    }
    
    // MARK: - NetEase Cloud Music
    
    /// 搜索网易云音乐并获取 SongID
    func findNetEaseID(title: String, artist: String) async -> String? {
        // 网易云搜索 API (Legacy Endpoint)
        // http://music.163.com/api/search/get/web?s={Query}&type=1&offset=0&total=true&limit=1
        
        let query = "\(title) \(artist)"
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
               let id = firstSong["id"] as? Int {
                return String(id)
            }
        } catch {
            print("NetEase Search Error: \(error)")
        }
        
        return nil
    }
    // MARK: - Lyrics Fetching
    
    /// 获取歌词 (优先 QQ 音乐，失败则使用网易云)
    func fetchLyrics(title: String, artist: String) async -> String? {
        // 1. 尝试 QQ 音乐
        if let qqLyrics = await fetchQQLyrics(title: title, artist: artist) {
            return qqLyrics
        }
        
        // 2. 尝试网易云音乐 (作为兜底)
        if let neLyrics = await fetchNetEaseLyrics(title: title, artist: artist) {
            return neLyrics
        }
        
        return nil
    }
    
    private func fetchQQLyrics(title: String, artist: String) async -> String? {
        guard let songmid = await findQQMusicID(title: title, artist: artist) else { return nil }
        
        // QQ 音乐歌词接口
        // https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid={songmid}&format=json&nobase64=1
        // 注意：QQ 音乐接口通常需要 Referer 和特定的 Header，且可能需要登录 cookie。
        // 这里尝试公开接口，如果失败则返回 nil
        
        guard let url = URL(string: "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=\(songmid)&format=json&nobase64=1") else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // QQ 音乐有时返回 JSONP，需要处理 (不过这里加了 format=json)
            // 结构: lyric
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let lyric = json["lyric"] as? String {
                // 解码 HTML 实体 (如果有)
                return lyric
            }
        } catch {
            print("QQ Music Lyrics Error: \(error)")
        }
        
        return nil
    }
    
    private func fetchNetEaseLyrics(title: String, artist: String) async -> String? {
        guard let id = await findNetEaseID(title: title, artist: artist) else { return nil }
        
        // 网易云歌词接口
        // http://music.163.com/api/song/lyric?id={id}&lv=1&kv=1&tv=-1
        guard let url = URL(string: "http://music.163.com/api/song/lyric?id=\(id)&lv=1&kv=1&tv=-1") else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let lrc = json["lrc"] as? [String: Any],
               let lyric = lrc["lyric"] as? String {
                return lyric
            }
        } catch {
            print("NetEase Lyrics Error: \(error)")
        }
        
        return nil
    }
}
