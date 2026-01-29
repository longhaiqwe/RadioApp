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
    private let targetDuration: TimeInterval = 15.0  // 采样时长（秒）- 确保足够捕捉歌曲特征
    private let estimatedBitrate = 320 * 1024 / 8    // 320kbps (约 40KB/s) - 按高音质估算，确保高音质电台也能下够时长
    private var targetBytes: Int { Int(targetDuration) * estimatedBitrate }
    
    // HLS 配置
    private let hlsSegmentsToDownload = 3  // 下载几个 ts 片段（如果单个片段太短，需要多下几个）
    
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
    
    /// 下载片段（支持递归下载多个片段拼接）
    private func downloadSegments(_ urls: [URL]) {
        downloadNextSegment(from: urls, accumulatedData: Data())
    }
    
    private func downloadNextSegment(from urls: [URL], accumulatedData: Data) {
        // 如果已经收集了足够的数据（比如超过 10 秒的高音质数据量），或者没有更多片段了，就结束
        // 注意：TS 文件有头部开销，所以稍微多下载一点
        if accumulatedData.count >= targetBytes || urls.isEmpty {
            if accumulatedData.count > 1000 {
                saveAndComplete(data: accumulatedData, isTS: true)
            } else {
                print("StreamSampler: 数据不足以识别")
                callCompletion(nil)
            }
            return
        }
        
        let currentURL = urls[0]
        let remainingURLs = Array(urls.dropFirst())
        
        print("StreamSampler: 正在下载片段: \(currentURL.lastPathComponent)")
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        
        session.dataTask(with: currentURL) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let error = error {
                print("StreamSampler: 片段下载失败 - \(error.localizedDescription)")
                // 如果已经有数据了，就尝试使用已有的
                if accumulatedData.count > 10000 {
                    self.saveAndComplete(data: accumulatedData, isTS: true)
                } else {
                    self.callCompletion(nil)
                }
                return
            }
            
            guard let data = data, data.count > 0 else {
                // 如果当前片段为空，尝试下一个
                self.downloadNextSegment(from: remainingURLs, accumulatedData: accumulatedData)
                return
            }
            
            print("StreamSampler: 片段下载成功 (\(data.count) bytes)")
            
            var newData = accumulatedData
            newData.append(data)
            
            // 递归下载下一个
            self.downloadNextSegment(from: remainingURLs, accumulatedData: newData)
            
        }.resume()
    }
    
    private func saveAndComplete(data: Data, isTS: Bool) {
        let url = isTS ? tempTSFileURL : tempFileURL
        do {
            try? FileManager.default.removeItem(at: url)
            try data.write(to: url)
            print("StreamSampler: 采集完成 (Total: \(data.count) bytes)")
            callCompletion(url)
        } catch {
            print("StreamSampler: 保存文件失败 - \(error)")
            callCompletion(nil)
        }
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
        
        // 设置超时 (12秒强制结束，防止低码率电台无限等待)
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            print("StreamSampler: 达到直接流采样时间限制 (12s)")
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
        saveAndComplete(data: receivedData, isTS: false)
        
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
