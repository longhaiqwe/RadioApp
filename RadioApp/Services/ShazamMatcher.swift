import Foundation
import Combine
import ShazamKit
import AVFoundation

class ShazamMatcher: NSObject, ObservableObject {
    static let shared = ShazamMatcher()
    
    // Published properties to update UI
    @Published var isMatching = false
    @Published var lastMatch: SHMatchedMediaItem?
    @Published var lastError: Error?
    @Published var matchingProgress: String = ""
    
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
        
        // 获取当前播放的电台 URL
        guard let station = AudioPlayerManager.shared.currentStation,
              !station.urlResolved.isEmpty else {
            lastError = NSError(domain: "ShazamMatcher", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "没有正在播放的电台"])
            return
        }
        
        isMatching = true
        lastMatch = nil
        lastError = nil
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
                }
                self.matchFile(at: fileURL)
            } else {
                DispatchQueue.main.async {
                    self.isMatching = false
                    self.matchingProgress = ""
                    self.lastError = NSError(domain: "ShazamMatcher", code: -2,
                                           userInfo: [NSLocalizedDescriptionKey: "无法获取音频数据"])
                }
            }
        }
    }
    
    /// 停止识别
    func stopMatching() {
        StreamSampler.shared.cancel()
        isMatching = false
        matchingProgress = ""
        print("ShazamMatcher: Stopped matching")
    }
    
    // MARK: - 从 AudioTap 接收缓冲区（如果 AudioTap 可用）
    
    func match(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard isMatching else { return }
        // 如果 AudioTap 工作，直接使用流式识别
        session?.matchStreamingBuffer(buffer, at: time)
    }
    
    // MARK: - 文件匹配（公开方法，供测试使用）
    
    func match(fileURL: URL) {
        isMatching = true
        lastMatch = nil
        lastError = nil
        matchingProgress = "正在识别..."
        matchFile(at: fileURL)
    }
    
    // MARK: - 文件匹配（内部实现）
    
    private func matchFile(at url: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let audioFile = try AVAudioFile(forReading: url)
                let processingFormat = audioFile.processingFormat
                
                // 读取音频数据
                
                // 读取音频数据
                let durationToRead: TimeInterval = 12.0
                let framesToRead = AVAudioFrameCount(processingFormat.sampleRate * durationToRead)
                
                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: framesToRead) else {
                    throw NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建缓冲区"])
                }
                
                try audioFile.read(into: inputBuffer)
                
                // 转换为 Mono 44.1kHz
                
                // 转换为 Mono 44.1kHz
                let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)!
                var bufferToMatch = inputBuffer
                
                if processingFormat.sampleRate != targetFormat.sampleRate || processingFormat.channelCount != targetFormat.channelCount {
                    
                    guard let converter = AVAudioConverter(from: processingFormat, to: targetFormat) else {
                        throw NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建转换器"])
                    }
                    
                    let ratio = targetFormat.sampleRate / processingFormat.sampleRate
                    let outputFrameCapacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio)
                    
                    guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
                        throw NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建输出缓冲区"])
                    }
                    
                    var error: NSError? = nil
                    let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                        outStatus.pointee = .haveData
                        return inputBuffer
                    }
                    
                    converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
                    if let error = error { throw error }
                    
                    bufferToMatch = outputBuffer
                }
                
                // 生成签名并匹配
                let generator = SHSignatureGenerator()
                try generator.append(bufferToMatch, at: nil)
                let signature = generator.signature()
                self.session?.match(signature)
                
            } catch {
                DispatchQueue.main.async {
                    self.isMatching = false
                    self.matchingProgress = ""
                    self.lastError = error
                    print("ShazamMatcher: Error - \(error.localizedDescription)")
                }
            }
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
            }
        }
    }
    
    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        DispatchQueue.main.async {
            // 防止重复处理
            guard self.isMatching else { return }
            
            self.isMatching = false
            self.matchingProgress = ""
            
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
}
