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
    ///   - completion: 成功返回 (歌曲名, 歌手名, 播放进度秒数), 失败返回 (nil, nil, nil)
    func match(fileURL: URL, completion: @escaping (String?, String?, TimeInterval?) -> Void) {
        // 1. 检查配置
        guard ACRCloudConfiguration.accessKey != "YOUR_ACCESS_KEY",
              ACRCloudConfiguration.accessSecret != "YOUR_ACCESS_SECRET" else {
            print("ACRCloudMatcher: 请先配置 AccessKey 和 AccessSecret")
            completion(nil, nil, nil)
            return
        }
        
        // 2. 读取音频数据
        guard let audioData = try? Data(contentsOf: fileURL) else {
            print("ACRCloudMatcher: 无法读取音频文件")
            completion(nil, nil, nil)
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
            completion(nil, nil, nil)
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
                    completion(nil, nil, nil)
                    return
                }
                
                guard let data = data else {
                    completion(nil, nil, nil)
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
                                
                                // 优先从 langs 字段获取简体中文标题
                                var title: String? = nil
                                if let langs = music["langs"] as? [[String: Any]] {
                                    // 查找 zh-Hans (简体中文)
                                    if let zhHans = langs.first(where: { ($0["code"] as? String) == "zh-Hans" }),
                                       let name = zhHans["name"] as? String, !name.isEmpty {
                                        title = name
                                    }
                                    // 如果没有简体，尝试繁体
                                    else if let zhHant = langs.first(where: { ($0["code"] as? String) == "zh-Hant" }),
                                            let name = zhHant["name"] as? String, !name.isEmpty {
                                        title = name
                                    }
                                }
                                // 兜底使用默认标题
                                if title == nil {
                                    title = music["title"] as? String
                                }
                                
                                // 优先从 artists.langs 获取简体中文艺术家名
                                var artistName: String? = nil
                                if let artists = music["artists"] as? [[String: Any]],
                                   let firstArtist = artists.first {
                                    // 尝试从 langs 获取中文名
                                    if let artistLangs = firstArtist["langs"] as? [[String: Any]] {
                                        if let zhHans = artistLangs.first(where: { ($0["code"] as? String) == "zh-Hans" }),
                                           let name = zhHans["name"] as? String, !name.isEmpty {
                                            artistName = name
                                        } else if let zhHant = artistLangs.first(where: { ($0["code"] as? String) == "zh-Hant" }),
                                                  let name = zhHant["name"] as? String, !name.isEmpty {
                                            artistName = name
                                        }
                                    }
                                    // 兜底使用默认 name
                                    if artistName == nil {
                                        artistName = firstArtist["name"] as? String
                                    }
                                }
                                
                                // 提取播放进度 (毫秒)
                                var offset: TimeInterval?
                                if let playOffsetMs = music["play_offset_ms"] as? Int {
                                    offset = TimeInterval(playOffsetMs) / 1000.0
                                }
                                
                                print("ACRCloudMatcher: 解析结果 - 歌曲: \(title ?? "未知"), 歌手: \(artistName ?? "未知")")
                                completion(title, artistName, offset)
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
                
                completion(nil, nil, nil)
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
