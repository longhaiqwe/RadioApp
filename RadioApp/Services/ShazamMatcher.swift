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
        
        print("ShazamMatcher: Starting stream sampling from \(station.urlResolved)")
        
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
                
                print("ShazamMatcher: Audio format: \(processingFormat)")
                
                // 读取音频数据
                let durationToRead: TimeInterval = 12.0
                let framesToRead = AVAudioFrameCount(processingFormat.sampleRate * durationToRead)
                
                guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: framesToRead) else {
                    throw NSError(domain: "ShazamMatcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建缓冲区"])
                }
                
                try audioFile.read(into: inputBuffer)
                
                print("ShazamMatcher: Read \(inputBuffer.frameLength) frames")
                
                // 转换为 Mono 44.1kHz
                let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)!
                var bufferToMatch = inputBuffer
                
                if processingFormat.sampleRate != targetFormat.sampleRate || processingFormat.channelCount != targetFormat.channelCount {
                    print("ShazamMatcher: Converting to Mono 44.1kHz...")
                    
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
                    print("ShazamMatcher: Converted to \(outputBuffer.frameLength) frames")
                }
                
                // 生成签名并匹配
                let generator = SHSignatureGenerator()
                try generator.append(bufferToMatch, at: nil)
                let signature = generator.signature()
                
                print("ShazamMatcher: Generated signature, matching...")
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
