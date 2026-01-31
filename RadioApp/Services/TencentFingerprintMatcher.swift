
import Foundation
import CommonCrypto
import Combine

/// 腾讯云音频指纹识别 (听歌识曲) 服务
/// 使用 AME (Audio Music Engineering) 接口：RecognizeAudio
/// 计费更低 (~0.05元/次)，响应更快 (同步返回)
class TencentFingerprintMatcher: NSObject, ObservableObject {
    static let shared = TencentFingerprintMatcher()
    
    @Published var isMatching = false
    @Published var matchingProgress = ""
    
    private override init() {}
    
    /// 开始识别音频
    /// - Parameters:
    ///   - fileURL: 本地音频文件 URL
    ///   - completion: 成功返回 (歌曲名, 歌手名)，失败返回 (nil, nil)
    func match(fileURL: URL, completion: @escaping (String?, String?) -> Void) {
        // 1. 检查配置
        guard TencentConfiguration.secretId != "YOUR_SECRET_ID",
              TencentConfiguration.secretKey != "YOUR_SECRET_KEY" else {
            print("TencentFingerprintMatcher: 请先在 TencentConfiguration (或本文件) 中配置 SecretId 和 SecretKey")
            completion(nil, nil)
            return
        }
        
        // 2. 读取音频文件并转为 Base64
        guard let audioData = try? Data(contentsOf: fileURL) else {
            print("TencentFingerprintMatcher: 无法读取音频文件")
            completion(nil, nil)
            return
        }
        
        // AME RecognizeAudio 限制音频大小通常为 5MB 以内 (Base64 后)
        // 15秒的 MP3 通常在 500KB 左右，完全没问题
        let base64Audio = audioData.base64EncodedString()
        
        DispatchQueue.main.async {
            self.isMatching = true
            self.matchingProgress = "正在通过 QQ 音乐库识别..."
        }
        
        // 3. 构建请求
        // 域名: ame.tencentcloudapi.com
        // 接口: RecognizeAudio
        // 版本: 2019-09-16
        
        let endpoint = "ame.tencentcloudapi.com"
        let action = "RecognizeAudio"
        let version = "2019-09-16"
        let region = "ap-guangzhou" // AME 通常支持全地域
        let timestamp = Int(Date().timeIntervalSince1970)
        
        let params: [String: Any] = [
            "AudioData": base64Audio
        ]
        
        requestTencentAPI(endpoint: endpoint, action: action, version: version, region: region, params: params, timestamp: timestamp) { [weak self] json in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isMatching = false
                self.matchingProgress = ""
                
                guard let json = json,
                      let response = json["Response"] as? [String: Any] else {
                    completion(nil, nil)
                    return
                }
                
                // 检查错误
                if let errorInfo = response["Error"] as? [String: Any] {
                    print("TencentFingerprintMatcher: API 报错 - \(errorInfo["Message"] ?? "未知错误")")
                    completion(nil, nil)
                    return
                }
                
                // 解析结果
                // 注意：AME RecognizeAudio 返回的是 MusicItem 列表
                if let musicItems = response["MusicItems"] as? [[String: Any]],
                   let bestMatch = musicItems.first {
                    
                    let songName = bestMatch["MusicName"] as? String
                    let singerName = bestMatch["SingerName"] as? String
                    
                    print("TencentFingerprintMatcher: 识别成功! -> \(songName ?? "") - \(singerName ?? "")")
                    completion(songName, singerName)
                } else {
                    print("TencentFingerprintMatcher: 未匹配到任何歌曲")
                    completion(nil, nil)
                }
            }
        }
    }
    
    private func requestTencentAPI(endpoint: String, action: String, version: String, region: String, params: [String: Any], timestamp: Int, completion: @escaping ([String: Any]?) -> Void) {
        guard let url = URL(string: "https://\(endpoint)") else { completion(nil); return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue(endpoint, forHTTPHeaderField: "Host")
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: params, options: []) else {
            completion(nil)
            return
        }
        request.httpBody = httpBody
        let payload = String(data: httpBody, encoding: .utf8) ?? ""
        
        // 使用共通的签名逻辑 (这里临时冗余，后续可提取)
        let signatureHeaders = makeSignatureV3(
            secretId: TencentConfiguration.secretId,
            secretKey: TencentConfiguration.secretKey,
            endpoint: endpoint,
            service: "ame",
            action: action,
            version: version,
            region: region,
            timestamp: timestamp,
            payload: payload
        )
        
        for (key, value) in signatureHeaders {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            completion(json)
        }.resume()
    }
    
    // MARK: - API v3 签名逻辑 (TC3-HMAC-SHA256)
    
    private func makeSignatureV3(secretId: String, secretKey: String, endpoint: String, service: String, action: String, version: String, region: String, timestamp: Int, payload: String) -> [String: String] {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = dateFormatter.string(from: date)
        
        // 1. CanonicalRequest
        let hashedPayload = payload.sha256()
        let canonicalRequest = """
        POST
        /
        
        content-type:application/json; charset=utf-8
        host:\(endpoint)
        
        content-type;host
        \(hashedPayload)
        """
        
        // 2. StringToSign
        let algorithm = "TC3-HMAC-SHA256"
        let credentialScope = "\(dateString)/\(service)/tc3_request"
        let hashedCanonicalRequest = canonicalRequest.sha256()
        let stringToSign = """
        \(algorithm)
        \(timestamp)
        \(credentialScope)
        \(hashedCanonicalRequest)
        """
        
        // 3. Calculation
        func hmac256(string: String, key: Data) -> Data {
            var result = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            string.data(using: .utf8)!.withUnsafeBytes { strBytes in
                key.withUnsafeBytes { keyBytes in
                    CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, key.count, strBytes.baseAddress, string.data(using: .utf8)!.count, &result)
                }
            }
            return Data(result)
        }
        
        let kDate = hmac256(string: dateString, key: ("TC3" + secretKey).data(using: .utf8)!)
        let kService = hmac256(string: service, key: kDate)
        let kSigning = hmac256(string: "tc3_request", key: kService)
        let signatureData = hmac256(string: stringToSign, key: kSigning)
        let signature = signatureData.map { String(format: "%02x", $0) }.joined()
        
        let authorization = "\(algorithm) Credential=\(secretId)/\(credentialScope), SignedHeaders=content-type;host, Signature=\(signature)"
        
        return [
            "Authorization": authorization,
            "X-TC-Action": action,
            "X-TC-Version": version,
            "X-TC-Timestamp": String(timestamp),
            "X-TC-Region": region
        ]
    }
}

