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
    private var completion: ((URL?, Bool, TimeInterval) -> Void)?
    private var isHLSStream_: Bool = false
    private var hlsSegmentOffset: TimeInterval = 0
    
    // 采样配置
    // 采样配置
    private let targetDuration: TimeInterval = 10.0  // 超时时长（秒）：网络差时的兜底等待时间
    private let successDuration: TimeInterval = 6.0  // 成功时长（秒）：只要数据量达到这个时长（约 96KB），就认为足够识别并立即停止
    private let estimatedBitrate = 128 * 1024 / 8    // 128kbps (约 16KB/s)
    
    // 目标字节数：基于“成功时长”计算
    // 逻辑：如果网速快，几秒钟下够了 96KB 就停；如果网速慢，最多等 10s 超时
    private var targetBytes: Int { Int(successDuration) * estimatedBitrate }
    
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
    /// - Parameters:
    ///   - urlString: 流 URL
    ///   - completion: (文件URL, 是否HLS, HLS偏移量秒数)
    func sampleStream(from urlString: String, completion: @escaping (URL?, Bool, TimeInterval) -> Void) {
        // 取消之前的任务
        cancel()
        
        self.completion = completion
        self.receivedData = Data()
        self.currentFileExtension = "mp3" // Reset to default
        self.isHLSStream_ = false
        self.hlsSegmentOffset = 0
        
        guard let url = URL(string: urlString) else {
            print("StreamSampler: Invalid URL: \(urlString)")
            completion(nil, false, 0)
            return
        }
        
        print("StreamSampler: 开始采集音频...")
        
        // 检测是否为 HLS 流
        if isHLSStream(urlString) {
            self.isHLSStream_ = true
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
            
            // 2. 解析 m3u8 获取片段 URL 和时长
            // 使用响应的 URL 作为基准（处理重定向情况）
            let playlistURL = response?.url ?? url
            let (segmentURLs, segmentDurations) = self.parseM3U8WithDurations(content: content, baseURL: playlistURL)
            
            if segmentURLs.isEmpty {
                print("StreamSampler: m3u8 中未找到媒体片段")
                self.callCompletion(nil)
                return
            }
            
            // 计算 HLS 偏移量
            // 假设：播放器通常落后于最新分片约 2 个片段（之前是 3 个，导致歌词偏快）
            // 我们下载的是列表末尾的最新片段 (前 3 个)
            // 偏移量 = 播放器落后的片段时长总和
            let playerLagSegments = 2  // 播放器落后的片段数
            let totalSegments = segmentURLs.count
            
            if totalSegments > playerLagSegments {
                // 计算播放器落后的时长 (最后 playerLagSegments 个片段的总时长)
                let lagDuration = segmentDurations.suffix(playerLagSegments).reduce(0, +)
                self.hlsSegmentOffset = lagDuration
                print("StreamSampler: HLS 偏移量计算: 播放器落后 \(playerLagSegments) 个片段, 约 \(String(format: "%.1f", lagDuration)) 秒")
            } else {
                // 片段太少，使用默认值
                self.hlsSegmentOffset = 10.0
                print("StreamSampler: HLS 片段较少，使用默认偏移量 10s")
            }
            
            print("StreamSampler: 找到 \(segmentURLs.count) 个片段，开始下载前 \(min(self.hlsSegmentsToDownload, segmentURLs.count)) 个...")
            
            // 检测片段文件类型 (默认 ts，如果是 aac/mp3 则使用对应后缀)
            let firstSegment = segmentURLs.first!
            let ext = firstSegment.pathExtension.lowercased()
            let fileExtension = (ext == "aac" || ext == "mp3") ? ext : "ts"
            
            print("StreamSampler: 识别片段类型为: \(fileExtension)")
            
            // 3. 下载片段并拼接
            self.downloadSegments(Array(segmentURLs.prefix(self.hlsSegmentsToDownload)), fileExtension: fileExtension)
        }.resume()
    }
    /// 解析 m3u8 播放列表，提取媒体片段 URL（旧版本，保持兼容）
    private func parseM3U8(content: String, baseURL: URL) -> [URL] {
        let (urls, _) = parseM3U8WithDurations(content: content, baseURL: baseURL)
        return urls
    }
    
    /// 解析 m3u8 播放列表，提取媒体片段 URL 和时长
    private func parseM3U8WithDurations(content: String, baseURL: URL) -> ([URL], [TimeInterval]) {
        var segmentURLs: [URL] = []
        var segmentDurations: [TimeInterval] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentDuration: TimeInterval = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 解析 EXTINF 获取时长
            if trimmed.hasPrefix("#EXTINF:") {
                // 格式: #EXTINF:6.0, 或 #EXTINF:6.006,title
                let durationPart = trimmed.dropFirst("#EXTINF:".count)
                if let commaIndex = durationPart.firstIndex(of: ",") {
                    let durationString = String(durationPart[..<commaIndex])
                    currentDuration = TimeInterval(durationString) ?? 0
                } else {
                    currentDuration = TimeInterval(durationPart) ?? 0
                }
                continue
            }
            
            // 跳过其他注释和空行
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                // 检查是否是嵌套的 m3u8（多码率）
                if trimmed.hasPrefix("#EXT-X-STREAM-INF") {
                    // 这是一个多码率播放列表，需要获取实际的媒体播放列表
                    continue
                }
                continue
            }
            
            // 构建完整 URL
            // 使用 URL(string: relativeTo:) 自动处理相对路径、绝对路径和 query 参数
            if let segmentURL = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL {
                // 检查是否是嵌套的 m3u8
                if segmentURL.pathExtension.lowercased() == "m3u8" || trimmed.hasSuffix(".m3u8") {
                    // 递归获取实际片段
                    print("StreamSampler: 发现嵌套 m3u8: \(segmentURL)")
                    return fetchNestedM3U8WithDurations(from: segmentURL)
                }
                
                segmentURLs.append(segmentURL)
                segmentDurations.append(currentDuration > 0 ? currentDuration : 6.0) // 默认 6 秒
                currentDuration = 0 // 重置
            }
        }
        
        return (segmentURLs, segmentDurations)
    }
    
    /// 获取嵌套的 m3u8 内容
    private func fetchNestedM3U8(from url: URL) -> [URL] {
        let (urls, _) = fetchNestedM3U8WithDurations(from: url)
        return urls
    }
    
    /// 获取嵌套的 m3u8 内容（带时长）
    private func fetchNestedM3U8WithDurations(from url: URL) -> ([URL], [TimeInterval]) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: ([URL], [TimeInterval]) = ([], [])
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        
        session.dataTask(with: url) { [weak self] data, response, _ in
            defer { semaphore.signal() }
            
            guard let self = self,
                  let data = data,
                  let content = String(data: data, encoding: .utf8) else {
                return
            }
            
            // 使用响应的 URL 作为基准
            let playlistURL = response?.url ?? url
            result = self.parseM3U8WithDurations(content: content, baseURL: playlistURL)
        }.resume()
        
        // 等待最多 10 秒
        _ = semaphore.wait(timeout: .now() + 10)
        return result
    }
    
    /// 下载片段（支持递归下载多个片段拼接）
    private func downloadSegments(_ urls: [URL], fileExtension: String) {
        downloadNextSegment(from: urls, accumulatedData: Data(), fileExtension: fileExtension)
    }
    
    private func downloadNextSegment(from urls: [URL], accumulatedData: Data, fileExtension: String) {
        // 如果已经收集了足够的数据（比如超过 10 秒的高音质数据量），或者没有更多片段了，就结束
        // 注意：TS 文件有头部开销，所以稍微多下载一点
        if accumulatedData.count >= targetBytes || urls.isEmpty {
            if accumulatedData.count > 1000 {
                saveAndComplete(data: accumulatedData, fileExtension: fileExtension)
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
                    self.saveAndComplete(data: accumulatedData, fileExtension: fileExtension)
                } else {
                    self.callCompletion(nil)
                }
                return
            }
            
            guard let data = data, data.count > 0 else {
                // 如果当前片段为空，尝试下一个
                self.downloadNextSegment(from: remainingURLs, accumulatedData: accumulatedData, fileExtension: fileExtension)
                return
            }
            
            print("StreamSampler: 片段下载成功 (\(data.count) bytes)")
            
            var newData = accumulatedData
            newData.append(data)
            
            // 递归下载下一个
            self.downloadNextSegment(from: remainingURLs, accumulatedData: newData, fileExtension: fileExtension)
            
        }.resume()
    }
    
    private func saveAndComplete(data: Data, fileExtension: String) {
        let fileName = "stream_sample.\(fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try? FileManager.default.removeItem(at: url)
            try data.write(to: url)
            print("StreamSampler: 采集完成 (Total: \(data.count) bytes, 文件: \(fileName))")
            callCompletion(url)
        } catch {
            print("StreamSampler: 保存文件失败 - \(error)")
            callCompletion(nil)
        }
    }
    
    // MARK: - 直接流处理（原有逻辑）
    
    /// 采样直接音频流
    private var timeoutWorkItem: DispatchWorkItem?
    
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
        
        // 设置超时 (使用 targetDuration 强制结束，防止低码率电台无限等待)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            print("StreamSampler: 达到直接流采样时间限制 (\(self.targetDuration)s)")
            self.finishDirectSampling()
        }
        
        self.timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + targetDuration, execute: workItem)
    }
    
    func cancel() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        dataTask?.cancel()
        dataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        receivedData = Data()
    }
    
    private func finishDirectSampling() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        dataTask?.cancel()
        
        guard receivedData.count > 1000 else {
            print("StreamSampler: Not enough data received (\(receivedData.count) bytes)")
            callCompletion(nil)
            return
        }
        
        var finalData = receivedData
        
        // 修复 AAC/ADTS 开始可能的残缺数据
        if currentFileExtension == "aac" {
            // 搜索 ADTS 同步字 (Sync Word): 0xFFF (12 bits)
            // 在字节流中通常表现为 0xFF 并且下一个字节高 4 位是 0xF
            if let syncIndex = findADTSSync(in: receivedData) {
                if syncIndex > 0 {
                    print("StreamSampler: 发现 AAC 同步字于 \(syncIndex)，跳过开头残缺数据")
                    finalData = receivedData.advanced(by: syncIndex)
                }
            } else {
                print("StreamSampler: 警告: 未在 AAC 流中找到同步字，文件可能损坏")
            }
        }
        
        // 保存到临时文件
        saveAndComplete(data: finalData, fileExtension: self.currentFileExtension)
        
        receivedData = Data()
    }
    
    /// 寻找 ADTS 同步字 (0xFF 0xFx)
    /// 增加更严格的校验：检查 Frame Length 并验证下一帧的 Sync Word
    private func findADTSSync(in data: Data) -> Int? {
        guard data.count > 10 else { return nil } // 至少需要一个头部 + 极少量数据
        
        let end = data.count - 1
        
        for i in 0..<end {
            // 1. 初步匹配 Sync Word (12 bits: 0xFFF)
            if data[i] == 0xFF && (data[i+1] & 0xF0) == 0xF0 {
                
                // 确保有足够数据读取头部 (至少 7 字节)
                if i + 7 > data.count {
                    continue
                }
                
                // 2. 解析 Frame Length
                // Frame Length 是 13 bits，从第 30 bit 开始
                // Byte 3 (后2位) + Byte 4 (全8位) + Byte 5 (前3位)
                let b3 = Int(data[i+3])
                let b4 = Int(data[i+4])
                let b5 = Int(data[i+5])
                
                let frameLength = ((b3 & 0x03) << 11) | (b4 << 3) | ((b5 & 0xE0) >> 5)
                
                if frameLength < 7 {
                    // Frame Length 甚至小于头部长度，肯定不对
                    continue
                }
                
                // 3. 验证下一帧的 Sync Word
                let nextIndex = i + frameLength
                
                // 只有当下一帧也在数据范围内时，才进行验证
                // 如果当前帧直接结束在数据包末尾，我们也认为它是合法的（因为无法验证下一帧了，但前面数据也没问题）
                // 但为了保险起见，我们优先寻找能验证下一帧的点。
                // 考虑到我们采集了 100KB 数据，帧很短，肯定能找到中间的帧。
                
                if nextIndex + 1 < data.count {
                    if data[nextIndex] == 0xFF && (data[nextIndex+1] & 0xF0) == 0xF0 {
                        // 验证通过！找到了真正的帧头
                        return i
                    } else {
                        // 下一帧位置不是 Sync Word，说明当前这个是误判
                        continue
                    }
                } else {
                    // 帧跨越了结尾，暂且认为是可能的（如果我们一直没找到经过验证的帧，最后没办法可能会用到这种，
                    // 但通常流数据中间肯定有完整帧）。这里由于我们想跳过开头垃圾数据，所以只接受“双重验证”成功的。
                    continue
                }
            }
        }
        
        return nil
    }
    
    /// 安全地调用完成回调
    private func callCompletion(_ url: URL?) {
        let isHLS = self.isHLSStream_
        let offset = self.hlsSegmentOffset
        DispatchQueue.main.async { [weak self] in
            self?.completion?(url, isHLS, offset)
            self?.completion = nil
        }
    }
    
    private var currentFileExtension: String = "mp3" // Default to mp3
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let mimeType = response.mimeType?.lowercased() {
             print("StreamSampler: 检测到流格式: \(mimeType)")
            
            // Map MIME types to extensions
            if mimeType == "audio/mpeg" {
                self.currentFileExtension = "mp3"
            } else if mimeType.contains("aac") { // audio/aac, audio/x-aac
                self.currentFileExtension = "aac"
            } else if mimeType == "audio/mp4" || mimeType == "audio/x-m4a" {
                self.currentFileExtension = "m4a"
            } else if mimeType.contains("ogg") {
                self.currentFileExtension = "ogg"
            } else if mimeType.contains("wav") {
                self.currentFileExtension = "wav"
            }
            
             print("StreamSampler: 将使用文件后缀: .\(self.currentFileExtension)")
        }
        
        completionHandler(.allow)
    }
    
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
