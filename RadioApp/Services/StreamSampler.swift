import Foundation
import AVFoundation
import ShazamKit

/// 流采样器：下载音频流的一小段数据用于 ShazamKit 识别
/// 支持直接流（MP3/AAC）和 HLS 流（.m3u8）
class StreamSampler: NSObject, URLSessionDataDelegate {
    static let shared = StreamSampler()
    
    private var urlSession: URLSession?
    private var dataTask: URLSessionDataTask?
    private var receivedData = Data()
    private var completion: ((URL?) -> Void)?
    
    // 采样配置
    private let targetDuration: TimeInterval = 8.0  // 采样时长（秒）
    private let estimatedBitrate = 128 * 1024 / 8    // 128kbps 估算字节率
    private var targetBytes: Int { Int(targetDuration) * estimatedBitrate }
    
    // HLS 配置
    private let hlsSegmentsToDownload = 3  // 下载几个 ts 片段
    
    private var tempFileURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("stream_sample.mp3")
    }
    
    private var tempTSFileURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("stream_sample.ts")
    }
    
    override init() {
        super.init()
    }
    
    /// 从流 URL 采样一段音频
    func sampleStream(from urlString: String, completion: @escaping (URL?) -> Void) {
        // 取消之前的任务
        cancel()
        
        self.completion = completion
        self.receivedData = Data()
        
        guard let url = URL(string: urlString) else {
            print("StreamSampler: Invalid URL: \(urlString)")
            completion(nil)
            return
        }
        
        print("StreamSampler: 开始采集音频...")
        
        // 检测是否为 HLS 流
        if isHLSStream(urlString) {
            print("StreamSampler: 检测到 HLS 流，开始解析 m3u8...")
            sampleHLSStream(from: url)
        } else {
            print("StreamSampler: 直接流，使用标准下载...")
            sampleDirectStream(from: url)
        }
    }
    
    // MARK: - HLS 流检测
    
    /// 检测是否为 HLS 流
    private func isHLSStream(_ urlString: String) -> Bool {
        let lowercased = urlString.lowercased()
        return lowercased.contains(".m3u8") || lowercased.contains("m3u8")
    }
    
    // MARK: - HLS 流处理
    
    /// 采样 HLS 流
    private func sampleHLSStream(from url: URL) {
        // 1. 下载 m3u8 播放列表
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: config)
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("StreamSampler: 下载 m3u8 失败 - \(error.localizedDescription)")
                self.callCompletion(nil)
                return
            }
            
            guard let data = data, let content = String(data: data, encoding: .utf8) else {
                print("StreamSampler: 无法解析 m3u8 内容")
                self.callCompletion(nil)
                return
            }
            
            print("StreamSampler: m3u8 内容获取成功，开始解析...")
            
            // 2. 解析 m3u8 获取片段 URL
            let segmentURLs = self.parseM3U8(content: content, baseURL: url)
            
            if segmentURLs.isEmpty {
                print("StreamSampler: m3u8 中未找到媒体片段")
                self.callCompletion(nil)
                return
            }
            
            print("StreamSampler: 找到 \(segmentURLs.count) 个片段，开始下载前 \(min(self.hlsSegmentsToDownload, segmentURLs.count)) 个...")
            
            // 3. 下载片段并拼接
            self.downloadSegments(Array(segmentURLs.prefix(self.hlsSegmentsToDownload)))
        }.resume()
    }
    
    /// 解析 m3u8 播放列表，提取媒体片段 URL
    private func parseM3U8(content: String, baseURL: URL) -> [URL] {
        var segmentURLs: [URL] = []
        let lines = content.components(separatedBy: .newlines)
        
        // 获取基础 URL（去掉文件名）
        let baseURLString = baseURL.deletingLastPathComponent().absoluteString
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 跳过注释和空行
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                // 检查是否是嵌套的 m3u8（多码率）
                if trimmed.hasPrefix("#EXT-X-STREAM-INF") {
                    // 这是一个多码率播放列表，需要获取实际的媒体播放列表
                    // 暂时跳过，后续处理下一行
                    continue
                }
                continue
            }
            
            // 构建完整 URL
            var segmentURL: URL?
            
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                // 绝对 URL
                segmentURL = URL(string: trimmed)
            } else if trimmed.hasPrefix("/") {
                // 从根路径开始
                if let scheme = baseURL.scheme, let host = baseURL.host {
                    let port = baseURL.port.map { ":\($0)" } ?? ""
                    segmentURL = URL(string: "\(scheme)://\(host)\(port)\(trimmed)")
                }
            } else {
                // 相对路径
                segmentURL = URL(string: baseURLString + trimmed)
            }
            
            if let url = segmentURL {
                // 检查是否是嵌套的 m3u8
                if url.pathExtension.lowercased() == "m3u8" {
                    // 递归获取实际片段（简化处理：只取第一个嵌套列表）
                    print("StreamSampler: 发现嵌套 m3u8: \(url)")
                    return fetchNestedM3U8(from: url)
                }
                
                segmentURLs.append(url)
            }
        }
        
        return segmentURLs
    }
    
    /// 获取嵌套的 m3u8 内容
    private func fetchNestedM3U8(from url: URL) -> [URL] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [URL] = []
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        
        session.dataTask(with: url) { [weak self] data, _, _ in
            defer { semaphore.signal() }
            
            guard let self = self,
                  let data = data,
                  let content = String(data: data, encoding: .utf8) else {
                return
            }
            
            result = self.parseM3U8(content: content, baseURL: url)
        }.resume()
        
        // 等待最多 10 秒
        _ = semaphore.wait(timeout: .now() + 10)
        return result
    }
    
    /// 下载片段（仅下载第一个成功的片段，避免拼接导致文件损坏）
    private func downloadSegments(_ urls: [URL]) {
        guard let firstURL = urls.first else {
            callCompletion(nil)
            return
        }
        
        // 只下载第一个片段，通常时长 5-10 秒，足够 Shazam 识别
        print("StreamSampler: 正在下载第一个片段: \(firstURL)")
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: config)
        
        session.dataTask(with: firstURL) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let error = error {
                print("StreamSampler: 下载片段失败 - \(error.localizedDescription)")
                self.callCompletion(nil)
                return
            }
            
            guard let data = data, data.count > 1000 else {
                print("StreamSampler: 片段数据为空或太小")
                self.callCompletion(nil)
                return
            }
            
            // 保存单个片段
            do {
                try? FileManager.default.removeItem(at: self.tempTSFileURL)
                try data.write(to: self.tempTSFileURL)
                print("StreamSampler: HLS 片段下载完成 (\(data.count) bytes)")
                self.callCompletion(self.tempTSFileURL)
            } catch {
                print("StreamSampler: 保存 HLS 数据失败 - \(error)")
                self.callCompletion(nil)
            }
        }.resume()
    }
    
    // MARK: - 直接流处理（原有逻辑）
    
    /// 采样直接音频流
    private func sampleDirectStream(from url: URL) {
        // 创建 session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        var request = URLRequest(url: url)
        request.setValue("audio/*", forHTTPHeaderField: "Accept")
        
        dataTask = urlSession?.dataTask(with: request)
        dataTask?.resume()
        
        // 设置超时
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.finishDirectSampling()
        }
    }
    
    func cancel() {
        dataTask?.cancel()
        dataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        receivedData = Data()
    }
    
    private func finishDirectSampling() {
        dataTask?.cancel()
        
        guard receivedData.count > 1000 else {
            print("StreamSampler: Not enough data received (\(receivedData.count) bytes)")
            callCompletion(nil)
            return
        }
        
        // 保存到临时文件
        do {
            try? FileManager.default.removeItem(at: tempFileURL)
            try receivedData.write(to: tempFileURL)
            print("StreamSampler: 采集完成 (\(receivedData.count) bytes)")
            callCompletion(tempFileURL)
        } catch {
            print("StreamSampler: Failed to save: \(error)")
            callCompletion(nil)
        }
        
        receivedData = Data()
    }
    
    /// 安全地调用完成回调
    private func callCompletion(_ url: URL?) {
        DispatchQueue.main.async { [weak self] in
            self?.completion?(url)
            self?.completion = nil
        }
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        
        // 收集足够数据后完成
        if receivedData.count >= targetBytes {
            finishDirectSampling()
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as NSError?, error.code != NSURLErrorCancelled {
            print("StreamSampler: Error - \(error.localizedDescription)")
        }
        
        // 即使有错误，如果有数据也尝试使用
        if receivedData.count > 1000 {
            finishDirectSampling()
        } else if completion != nil {
            callCompletion(nil)
        }
    }
}
