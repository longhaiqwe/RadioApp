import Foundation
import AVFoundation
import ShazamKit

/// 流采样器：下载音频流的一小段数据用于 ShazamKit 识别
class StreamSampler: NSObject, URLSessionDataDelegate {
    static let shared = StreamSampler()
    
    private var urlSession: URLSession?
    private var dataTask: URLSessionDataTask?
    private var receivedData = Data()
    private var completion: ((URL?) -> Void)?
    
    // 采样配置
    private let targetDuration: TimeInterval = 12.0  // 采样时长（秒）
    private let estimatedBitrate = 128 * 1024 / 8    // 128kbps 估算字节率
    private var targetBytes: Int { Int(targetDuration) * estimatedBitrate }
    
    private var tempFileURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("stream_sample.mp3")
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
        
        // 处理 URL
        guard let url = processStreamURL(urlString) else {
            print("StreamSampler: Invalid URL: \(urlString)")
            completion(nil)
            return
        }
        
        print("StreamSampler: 开始采集音频...")
        
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
            self?.finishSampling()
        }
    }
    
    /// 处理 URL，对于 HLS 需要特殊处理
    private func processStreamURL(_ urlString: String) -> URL? {
        guard let url = URL(string: urlString) else { return nil }
        
        // 如果是 m3u8，尝试直接使用（某些服务器支持直接流式下载）
        // 或者我们可以解析 m3u8 获取实际的音频段 URL
        // 这里先简单处理，直接使用原 URL
        return url
    }
    
    func cancel() {
        dataTask?.cancel()
        dataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        receivedData = Data()
    }
    
    private func finishSampling() {
        dataTask?.cancel()
        
        guard receivedData.count > 1000 else {
            print("StreamSampler: Not enough data received (\(receivedData.count) bytes)")
            completion?(nil)
            completion = nil
            return
        }
        
        // 保存到临时文件
        do {
            // 删除旧文件
            try? FileManager.default.removeItem(at: tempFileURL)
            
            try receivedData.write(to: tempFileURL)
            print("StreamSampler: 采集完成")
            
            completion?(tempFileURL)
        } catch {
            print("StreamSampler: Failed to save: \(error)")
            completion?(nil)
        }
        
        completion = nil
        receivedData = Data()
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        
        // 静默接收数据，不打印进度
        
        // 收集足够数据后完成
        if receivedData.count >= targetBytes {
            finishSampling()
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as NSError?, error.code != NSURLErrorCancelled {
            print("StreamSampler: Error - \(error.localizedDescription)")
        }
        
        // 即使有错误，如果有数据也尝试使用
        if receivedData.count > 1000 {
            finishSampling()
        } else if completion != nil {
            completion?(nil)
            completion = nil
        }
    }
}
