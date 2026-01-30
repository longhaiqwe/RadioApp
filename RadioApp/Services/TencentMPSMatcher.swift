
import Foundation
import CommonCrypto
import Combine


/// 腾讯云配置
struct TencentConfiguration {
    // ⚠️ 请填入您的腾讯云 API 密钥
    static let secretId = "YOUR_SECRET_ID"
    static let secretKey = "YOUR_SECRET_KEY"
    
    // ⚠️ 请填入您的 COS 存储桶信息
    static let cosBucket = "examplebucket-1250000000" // 格式: bucketname-appid
    static let cosRegion = "ap-guangzhou" // 例如: ap-guangzhou
    
    // 检查配置是否有效
    static var isValid: Bool {
        return secretId != "YOUR_SECRET_ID" && 
               secretKey != "YOUR_SECRET_KEY" && 
               cosBucket != "examplebucket-1250000000"
    }
}

/// 负责与腾讯云 MPS 交互的音乐识别服务
class TencentMPSMatcher: NSObject, ObservableObject {
    static let shared = TencentMPSMatcher()
    
    // 发布识别状态
    @Published var isMatching = false
    @Published var matchingProgress = ""
    
    private override init() {}
    
    /// 开始识别音频文件
    /// - Parameters:
    ///   - fileURL: 本地音频文件 URL (通常是 StreamSampler 采集的 .mp3 或 .aac)
    ///   - completion: 回调结果 (歌曲名, 歌手名)
    func match(fileURL: URL, completion: @escaping (String?, String?) -> Void) {
        // 1. 检查配置
        guard TencentConfiguration.isValid else {
            print("TencentMPSMatcher: 配置无效，请在 TencentConfiguration 中填入密钥")
            completion(nil, nil)
            return
        }
        
        isMatching = true
        matchingProgress = "正在上传音频到腾讯云..."
        
        // 2. 上传文件到 COS
        uploadToCOS(fileURL: fileURL) { [weak self] objectKey in
            guard let self = self, let objectKey = objectKey else {
                self?.isMatching = false
                completion(nil, nil)
                return
            }
            
            // 3. 提交 MPS 识别任务
            DispatchQueue.main.async {
                self.matchingProgress = "正在云端识别..."
            }
            
            self.submitMPSTask(objectKey: objectKey) { taskId in
                guard let taskId = taskId else {
                    self.isMatching = false
                    completion(nil, nil)
                    return
                }
                
                // 4. 轮询任务结果
                self.pollTaskStatus(taskId: taskId, completion: completion)
            }
        }
    }
    
    // MARK: - 步骤 1: 上传到 COS
    
    private func uploadToCOS(fileURL: URL, completion: @escaping (String?) -> Void) {
        // 生成唯一对象 Key
        let objectKey = "radio_app/audio_samples/\(UUID().uuidString).\(fileURL.pathExtension)"
        let host = "\(TencentConfiguration.cosBucket).cos.\(TencentConfiguration.cosRegion).myqcloud.com"
        let urlString = "https://\(host)/\(objectKey)"
        
        guard let url = URL(string: urlString),
              let audioData = try? Data(contentsOf: fileURL) else {
            print("TencentMPSMatcher: 文件读取失败")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = audioData
        
        // 生成 COS 签名 (简化版 PutObject 签名)
        // 注意：生产环境建议使用后端生成临时密钥，这里仅演示本地签名
        let authHeader = TencentCloudSigner.makeCOSSignature(
            secretId: TencentConfiguration.secretId,
            secretKey: TencentConfiguration.secretKey,
            httpMethod: "put",
            uri: "/" + objectKey,
            headers: [:],
            params: [:]
        )
        
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        // request.setValue(host, forHTTPHeaderField: "Host") // URLSession 会自动处理
        
        print("TencentMPSMatcher: 开始上传 \(audioData.count) 字节...")
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("TencentMPSMatcher: Upload Error - \(error)")
                completion(nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                print("TencentMPSMatcher: Upload Success")
                completion(objectKey)
            } else {
                print("TencentMPSMatcher: Upload Failed - Status \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                completion(nil)
            }
        }.resume()
    }
    
    // MARK: - 步骤 2: 提交识别任务
    
    private func submitMPSTask(objectKey: String, completion: @escaping (String?) -> Void) {
        // 构建请求参数
        // API: ProcessMedia
        // 文档: https://cloud.tencent.com/document/product/862/37578
        
        let endpoint = "mps.tencentcloudapi.com"
        let action = "ProcessMedia"
        let version = "2019-06-12"
        let region = TencentConfiguration.cosRegion
        let timestamp = Int(Date().timeIntervalSince1970)
        let nonce = Int.random(in: 10000...99999)
        
        // 构建 InputInfo (指向刚才上传的 COS 文件)
        let inputInfo: [String: Any] = [
            "Type": "COS",
            "CosInputInfo": [
                "Bucket": TencentConfiguration.cosBucket,
                "Region": TencentConfiguration.cosRegion,
                "Object": objectKey
            ]
        ]
        
        // 构建 AiAnalysisTask (音乐识别 parameter definition = 20 或根据控制台配置)
        // 注意：这里假设模板 ID 10 为默认的 AI 分析模板，如果不确定，需要去控制台创建一个包含“音乐识别”的模板
        // 或者使用 ExtendedParameter 直接指定
        // 音乐识别 tag 标签通常是 "Music"
        // 为简化演示，这里假设有一个 ID 为 10 的模板开启了内容分析
        // 实际开发中建议创建一个专门的模板
        
        let aiAnalysisTask: [String: Any] = [
            "Definition": 10 // ⚠️ 请在 MP 控制台确认包含音乐识别的模板 ID
        ]
        
        let params: [String: Any] = [
            "Action": action,
            "Version": version,
            "Region": region,
            "Timestamp": timestamp,
            "Nonce": nonce,
            "InputInfo": inputInfo,
            "AiAnalysisTask": aiAnalysisTask,
            "OutputDir": "radio_app/output/" // 输出目录
        ]
        
        // 发送 POST 请求
        requestTencentAPI(endpoint: endpoint, params: params) { json in
            guard let json = json,
                  let response = json["Response"] as? [String: Any],
                  let taskId = response["TaskId"] as? String else { // 注意：有些接口返回 TaskId 是 Int，文档说是 String
                print("TencentMPSMatcher: 提交任务失败或解析错误")
                if let json = json { print(json) }
                completion(nil)
                return
            }
            
            print("TencentMPSMatcher: 任务提交成功, TaskId: \(taskId)")
            completion(taskId)
        }
    }
    
    // MARK: - 步骤 3: 轮询结果
    
    private func pollTaskStatus(taskId: String, completion: @escaping (String?, String?) -> Void) {
        let endpoint = "mps.tencentcloudapi.com"
        let action = "DescribeTaskDetail"
        let version = "2019-06-12"
        let region = TencentConfiguration.cosRegion
        let timestamp = Int(Date().timeIntervalSince1970)
        let nonce = Int.random(in: 10000...99999)
        
        let params: [String: Any] = [
            "Action": action,
            "Version": version,
            "Region": region,
            "Timestamp": timestamp,
            "Nonce": nonce,
            "TaskId": taskId
        ]
        
        // 递归轮询函数
        func check() {
            // 延迟 2 秒再查
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self = self else { return }
                
                // 检查是否已取消（例如切歌了）
                if !self.isMatching { return }
                
                self.requestTencentAPI(endpoint: endpoint, params: params) { json in
                    guard let json = json,
                          let response = json["Response"] as? [String: Any] else {
                        completion(nil, nil)
                        return
                    }
                    
                    let status = response["Status"] as? String ?? ""
                    let taskType = response["TaskType"] as? String ?? ""
                    
                    print("TencentMPSMatcher: Task Status: \(status)")
                    
                    if status == "FINISH" {
                        self.isMatching = false
                        // 解析结果
                        if let analysisResult = response["AiAnalysisResultSet"] as? [[String: Any]],
                           let firstResult = analysisResult.first,
                           let tagTask = firstResult["TagTask"] as? [String: Any],
                           let output = tagTask["Output"] as? [String: Any],
                           let tagSet = output["TagSet"] as? [[String: Any]] {
                            
                            // 查找音乐相关的标签
                            // 腾讯云返回的结构比较复杂，通常在 Tag 或 SpecialInfo 中
                            // 示例: {"Tag": "繁星", "Confidence": 99, "SpecialInfo": "{\"song_name\":\"繁星\",\"singer_name\":\"袁娅维\"}"}
                            
                            for tag in tagSet {
                                if let specialInfoStr = tag["SpecialInfo"] as? String,
                                   let data = specialInfoStr.data(using: .utf8),
                                   let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let songName = info["song_name"] as? String {
                                    
                                    let singerName = info["singer_name"] as? String
                                    print("TencentMPSMatcher: 识别成功 - \(songName) - \(singerName ?? "")")
                                    completion(songName, singerName)
                                    return
                                }
                            }
                        }
                        
                        print("TencentMPSMatcher: 任务完成但未找到音乐信息")
                        completion(nil, nil)
                        
                    } else if status == "Processing" || status == "WAITING" {
                        // 继续轮询
                        check()
                    } else {
                        // 失败
                        print("TencentMPSMatcher: 任务失败")
                        self.isMatching = false
                        completion(nil, nil)
                    }
                }
            }
        }
        
        check()
    }
    
    // MARK: - 通用 API 请求 (TC3-HMAC-SHA256)
    
    private func requestTencentAPI(endpoint: String, params: [String: Any], completion: @escaping ([String: Any]?) -> Void) {
        guard let url = URL(string: "https://\(endpoint)") else { completion(nil); return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.addValue(endpoint, forHTTPHeaderField: "Host")
        
        // 序列化 Body
        guard let httpBody = try? JSONSerialization.data(withJSONObject: params, options: []) else {
            completion(nil)
            return
        }
        request.httpBody = httpBody
        let payload = String(data: httpBody, encoding: .utf8) ?? ""
        
        // 签名
        let signatureHeaders = TencentCloudSigner.makeAPISignature(
            secretId: TencentConfiguration.secretId,
            secretKey: TencentConfiguration.secretKey,
            endpoint: endpoint,
            action: params["Action"] as? String ?? "",
            region: params["Region"] as? String ?? "",
            timestamp: params["Timestamp"] as! Int,
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
}

/// 腾讯云签名工具类
/// 参考: https://cloud.tencent.com/document/api/213/30654
class TencentCloudSigner {
    
    static func makeAPISignature(secretId: String, secretKey: String, endpoint: String, action: String, region: String, timestamp: Int, payload: String) -> [String: String] {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = dateFormatter.string(from: date)
        
        let service = "mps" // 媒体处理服务
        
        // 1. CanonicalRequest
        let canonicalRequest = """
        POST
        /
        
        content-type:application/json; charset=utf-8
        host:\(endpoint)
        
        content-type;host
        \(payload.sha256())
        """
        
        // 2. StringToSign
        let algorithm = "TC3-HMAC-SHA256"
        let credentialScope = "\(dateString)/\(service)/tc3_request"
        let stringToSign = """
        \(algorithm)
        \(timestamp)
        \(credentialScope)
        \(canonicalRequest.sha256())
        """
        
        // 3. Calculation
        let kDate = hmac(string: dateString, key: "TC3" + secretKey)
        let kService = hmac(string: service, key: kDate)
        let kSigning = hmac(string: "tc3_request", key: kService)
        let signatureData = hmac(string: stringToSign, key: kSigning)
        let signature = signatureData.map { String(format: "%02x", $0) }.joined()
        
        // Header
        let authorization = "\(algorithm) Credential=\(secretId)/\(credentialScope), SignedHeaders=content-type;host, Signature=\(signature)"
        
        return [
            "Authorization": authorization,
            "X-TC-Action": action,
            "X-TC-Version": "2019-06-12",
            "X-TC-Timestamp": String(timestamp),
            "X-TC-Region": region
        ]
    }
    
    // 简化版 COS 签名 (Q-Sign-Algorithm)
    // 仅用于演示，生产环境请使用官方 SDK
    static func makeCOSSignature(secretId: String, secretKey: String, httpMethod: String, uri: String, headers: [String: String], params: [String: String]) -> String {
        // 时间范围
        let now = Int(Date().timeIntervalSince1970)
        let end = now + 600
        let keyTime = "\(now);\(end)"
        
        let signKey = hmac(string: keyTime, key: secretKey).map { String(format: "%02x", $0) }.joined()
        
        let formatStr = """
        \(httpMethod.lowercased())
        \(uri)
        
        
        
        """
        
        let stringToSign = "sha1\n\(keyTime)\n\(formatStr.sha1())"
        
        let signature = hmac(string: stringToSign, key: signKey, algorithm: CCHmacAlgorithm(kCCHmacAlgSHA1)).map { String(format: "%02x", $0) }.joined()
        
        return "q-sign-algorithm=sha1&q-ak=\(secretId)&q-sign-time=\(keyTime)&q-key-time=\(keyTime)&q-header-list=&q-url-param-list=&q-signature=\(signature)"
    }
    
    // MARK: - Crypto Helpers
    
    private static func hmac(string: String, key: String, algorithm: CCHmacAlgorithm = CCHmacAlgorithm(kCCHmacAlgSHA256)) -> Data {
        let keyData = key.data(using: .utf8)!
        let stringData = string.data(using: .utf8)!
        
        var result = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH)) // Default SHA256 length, adjust if needed
        if algorithm == CCHmacAlgorithm(kCCHmacAlgSHA1) {
             result = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        }
        
        stringData.withUnsafeBytes { strBytes in
            keyData.withUnsafeBytes { keyBytes in
                if algorithm == CCHmacAlgorithm(kCCHmacAlgSHA1) {
                    CCHmac(algorithm, keyBytes.baseAddress, keyData.count, strBytes.baseAddress, stringData.count, &result)
                } else {
                    CCHmac(algorithm, keyBytes.baseAddress, keyData.count, strBytes.baseAddress, stringData.count, &result)
                }
            }
        }
        return Data(result)
    }
    
    private static func hmac(string: String, key: Data) -> Data {
        let stringData = string.data(using: .utf8)!
        var result = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        stringData.withUnsafeBytes { strBytes in
            key.withUnsafeBytes { keyBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), keyBytes.baseAddress, key.count, strBytes.baseAddress, stringData.count, &result)
            }
        }
        return Data(result)
    }
}

extension String {
    func sha256() -> String {
        let data = self.data(using: .utf8)!
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    func sha1() -> String {
        let data = self.data(using: .utf8)!
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
