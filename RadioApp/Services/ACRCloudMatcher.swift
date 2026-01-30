import Foundation
import Combine
import CryptoKit

/// ACRCloud 账号配置
struct ACRCloudConfiguration {
    // ⚠️ 请填入您的 ACRCloud 账号信息
    static let accessKey = "47a1866733bcb80494033c4621cd6878"
    static let accessSecret = "zGXzef5LTxDcFGv9lZK1KsIwOyZuh2iLWgp0jaz5"
    static let host = "identify-ap-southeast-1.acrcloud.com" // 根据您的项目修改区域
}

class ACRCloudMatcher: NSObject, ObservableObject {
    static let shared = ACRCloudMatcher()
    
    @Published var isMatching = false
    @Published var matchingProgress = ""
    
    private override init() {}
    
    /// 开始识别音频
    /// - Parameters:
    ///   - fileURL: 本地音频文件 URL (采样后的音频)
    ///   - completion: 成功返回 (歌曲名, 歌手名), 失败返回 (nil, nil)
    func match(fileURL: URL, completion: @escaping (String?, String?) -> Void) {
        // 1. 检查配置
        guard ACRCloudConfiguration.accessKey != "YOUR_ACCESS_KEY",
              ACRCloudConfiguration.accessSecret != "YOUR_ACCESS_SECRET" else {
            print("ACRCloudMatcher: 请先配置 AccessKey 和 AccessSecret")
            completion(nil, nil)
            return
        }
        
        // 2. 读取音频数据
        guard let audioData = try? Data(contentsOf: fileURL) else {
            print("ACRCloudMatcher: 无法读取音频文件")
            completion(nil, nil)
            return
        }
        
        DispatchQueue.main.async {
            self.isMatching = true
            self.matchingProgress = "正在通过 ACRCloud 识别..."
        }
        
        let endpoint = "https://\(ACRCloudConfiguration.host)/v1/identify"
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // 3. 生成签名
        let signature = generateSignature(
            accessKey: ACRCloudConfiguration.accessKey,
            accessSecret: ACRCloudConfiguration.accessSecret,
            timestamp: String(timestamp)
        )
        
        guard let signature = signature else {
            completion(nil, nil)
            return
        }
        
        // 4. 构建 Multipart 请求
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Form fields
        let fields: [String: String] = [
            "access_key": ACRCloudConfiguration.accessKey,
            "sample_bytes": String(audioData.count),
            "timestamp": String(timestamp),
            "signature": signature,
            "data_type": "audio",
            "signature_version": "1"
        ]
        
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"sample\"; filename=\"sample.mp3\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isMatching = false
                self.matchingProgress = ""
                
                if let error = error {
                    print("ACRCloudMatcher: 请求错误 - \(error.localizedDescription)")
                    completion(nil, nil)
                    return
                }
                
                guard let data = data else {
                    completion(nil, nil)
                    return
                }
                
                do {
                    // 解析响应
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("ACRCloudMatcher Response: \(json)")
                        
                        if let status = json["status"] as? [String: Any],
                           let code = status["code"] as? Int, code == 0 {
                            
                            if let metadata = json["metadata"] as? [String: Any],
                               let music = (metadata["music"] as? [[String: Any]])?.first {
                                
                                let title = music["title"] as? String
                                let artists = music["artists"] as? [[String: Any]]
                                let artistName = artists?.first?["name"] as? String
                                
                                completion(title, artistName)
                                return
                            }
                        } else {
                            let msg = (json["status"] as? [String: Any])?["msg"] as? String ?? "未知错误"
                            print("ACRCloudMatcher API Error: \(msg)")
                        }
                    }
                } catch {
                    print("ACRCloudMatcher: JSON 解析失败 - \(error.localizedDescription)")
                }
                
                completion(nil, nil)
            }
        }.resume()
    }
    
    // MARK: - 签名逻辑
    
    private func generateSignature(accessKey: String, accessSecret: String, timestamp: String) -> String? {
        let httpMethod = "POST"
        let httpUri = "/v1/identify"
        let signatureVersion = "1"
        let dataType = "audio"
        
        let stringToSign = "\(httpMethod)\n\(httpUri)\n\(accessKey)\n\(dataType)\n\(signatureVersion)\n\(timestamp)"
        
        let key = SymmetricKey(data: Data(accessSecret.utf8))
        let signature = HMAC<Insecure.SHA1>.authenticationCode(for: Data(stringToSign.utf8), using: key)
        
        return Data(signature).base64EncodedString()
    }
}
