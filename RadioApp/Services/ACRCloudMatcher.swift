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
                               let musicList = metadata["music"] as? [[String: Any]], !musicList.isEmpty {
                                
                                // 辅助函数：检查字符串是否包含中文
                                func containsChinese(_ str: String) -> Bool {
                                    return str.unicodeScalars.contains { scalar in
                                        return (scalar.value >= 0x4E00 && scalar.value <= 0x9FFF) ||
                                               (scalar.value >= 0x3400 && scalar.value <= 0x4DBF)
                                    }
                                }
                                
                                // 辅助函数：从 langs 数组中获取中文名
                                func getChineseFromLangs(_ langs: [[String: Any]]?) -> String? {
                                    guard let langs = langs else { return nil }
                                    // 优先简体中文
                                    if let zhHans = langs.first(where: { ($0["code"] as? String)?.lowercased() == "zh-hans" }),
                                       let name = zhHans["name"] as? String, !name.isEmpty {
                                        return name
                                    }
                                    // 其次繁体中文
                                    if let zhHant = langs.first(where: { ($0["code"] as? String)?.lowercased() == "zh-hant" }),
                                       let name = zhHant["name"] as? String, !name.isEmpty {
                                        return name
                                    }
                                    return nil
                                }
                                
                                // 辅助函数：从单条 music 记录中提取标题和歌手
                                func extractMeta(from music: [String: Any]) -> (title: String, artist: String, offset: TimeInterval?) {
                                    // 提取标题
                                    let defaultTitle = music["title"] as? String ?? ""
                                    var title: String
                                    if containsChinese(defaultTitle) {
                                        title = defaultTitle
                                    } else if let chineseTitle = getChineseFromLangs(music["langs"] as? [[String: Any]]) {
                                        title = chineseTitle
                                    } else {
                                        title = defaultTitle
                                    }
                                    
                                    // 提取歌手
                                    var artist = ""
                                    if let artists = music["artists"] as? [[String: Any]], let firstArtist = artists.first {
                                        let defaultArtist = firstArtist["name"] as? String ?? ""
                                        if containsChinese(defaultArtist) {
                                            artist = defaultArtist
                                        } else if let chineseArtist = getChineseFromLangs(firstArtist["langs"] as? [[String: Any]]) {
                                            artist = chineseArtist
                                        } else {
                                            artist = defaultArtist
                                        }
                                    }
                                    
                                    // 提取播放进度
                                    var offset: TimeInterval? = nil
                                    if let playOffsetMs = music["play_offset_ms"] as? Int {
                                        offset = TimeInterval(playOffsetMs) / 1000.0
                                    }
                                    
                                    return (title, artist, offset)
                                }
                                
                                // 辅助函数：检查歌手是否有效（排除合辑等无意义歌手）
                                func isValidArtist(_ artist: String) -> Bool {
                                    let invalidArtists = ["various artists", "群星", "原声带", "soundtrack", "ost"]
                                    let lowerArtist = artist.lowercased()
                                    return !invalidArtists.contains(where: { lowerArtist.contains($0) })
                                }
                                
                                // 辅助函数：检查是否包含简体中文（非繁体）
                                func isSimplifiedChinese(_ str: String) -> Bool {
                                    guard containsChinese(str) else { return false }
                                    // 转换为简体后与原字符串比较，相同则为简体
                                    let simplified = str.applyingTransform(StringTransform("Any-Hans"), reverse: false) ?? str
                                    return simplified == str
                                }
                                
                                // 遍历所有记录，按优先级选择
                                // 优先级: 简体中文+有效歌手 > 繁体中文+有效歌手 > 简体中文 > 繁体中文 > 兜底第一条
                                var selectedTitle: String = ""
                                var selectedArtist: String = ""
                                var selectedOffset: TimeInterval? = nil
                                
                                // 第一遍：寻找简体中文标题 + 有效歌手
                                for music in musicList {
                                    let meta = extractMeta(from: music)
                                    if isSimplifiedChinese(meta.title) && isValidArtist(meta.artist) {
                                        selectedTitle = meta.title
                                        selectedArtist = meta.artist
                                        selectedOffset = meta.offset
                                        print("ACRCloudMatcher: 找到简体中文标题+有效歌手 - 歌曲: \(selectedTitle), 歌手: \(selectedArtist)")
                                        break
                                    }
                                }
                                
                                // 第二遍：寻找繁体中文标题 + 有效歌手
                                if selectedTitle.isEmpty {
                                    for music in musicList {
                                        let meta = extractMeta(from: music)
                                        if containsChinese(meta.title) && isValidArtist(meta.artist) {
                                            selectedTitle = meta.title
                                            selectedArtist = meta.artist
                                            selectedOffset = meta.offset
                                            print("ACRCloudMatcher: 找到繁体中文标题+有效歌手 - 歌曲: \(selectedTitle), 歌手: \(selectedArtist)")
                                            break
                                        }
                                    }
                                }
                                
                                // 第三遍：寻找简体中文标题（放宽歌手条件）
                                if selectedTitle.isEmpty {
                                    for music in musicList {
                                        let meta = extractMeta(from: music)
                                        if isSimplifiedChinese(meta.title) {
                                            selectedTitle = meta.title
                                            selectedArtist = meta.artist
                                            selectedOffset = meta.offset
                                            print("ACRCloudMatcher: 找到简体中文标题 - 歌曲: \(selectedTitle), 歌手: \(selectedArtist)")
                                            break
                                        }
                                    }
                                }
                                
                                // 第四遍：寻找繁体中文标题
                                if selectedTitle.isEmpty {
                                    for music in musicList {
                                        let meta = extractMeta(from: music)
                                        if containsChinese(meta.title) {
                                            selectedTitle = meta.title
                                            selectedArtist = meta.artist
                                            selectedOffset = meta.offset
                                            print("ACRCloudMatcher: 找到繁体中文标题 - 歌曲: \(selectedTitle), 歌手: \(selectedArtist)")
                                            break
                                        }
                                    }
                                }
                                
                                // 最后兜底：使用第一条
                                if selectedTitle.isEmpty {
                                    let meta = extractMeta(from: musicList[0])
                                    selectedTitle = meta.title
                                    selectedArtist = meta.artist
                                    selectedOffset = meta.offset
                                    print("ACRCloudMatcher: 未找到中文标题，使用第一条记录 - 歌曲: \(selectedTitle), 歌手: \(selectedArtist)")
                                }
                                
                                print("ACRCloudMatcher: 初步解析结果 - 歌曲: \(selectedTitle), 歌手: \(selectedArtist)")
                                
                                // 转为可变变量处理
                                var finalTitle = selectedTitle
                                var finalArtist = selectedArtist
                                let offset = selectedOffset
                                
                                // 启动 Task 进行中文元数据修正
                                Task {
                                    // 1. 中文转换：先繁体转简体
                                    finalTitle = MusicPlatformService.shared.toSimplifiedChinese(finalTitle)
                                    finalArtist = MusicPlatformService.shared.toSimplifiedChinese(finalArtist)
                                    
                                    // 2. 清理标题 (移除 Live/Demo 等)
                                    finalTitle = MusicPlatformService.shared.cleanTitle(finalTitle)
                                    
                                    // 3. 检查是否需要拼音转中文
                                    // 只要标题或歌手名是拼音/罗马化，就尝试搜索
                                    let needsChineseConversion = MusicPlatformService.shared.isPinyinOrRomanized(finalTitle) ||
                                                                 MusicPlatformService.shared.isPinyinOrRomanized(finalArtist)
                                    
                                    if needsChineseConversion {
                                        print("ACRCloudMatcher: 检测到拼音/英文格式，尝试获取中文元数据...")
                                        if let chineseMeta = await MusicPlatformService.shared.fetchChineseMetadata(title: finalTitle, artist: finalArtist) {
                                            finalTitle = chineseMeta.title
                                            finalArtist = chineseMeta.artist
                                            print("ACRCloudMatcher: 成功转换为中文 - 歌曲: \(finalTitle), 歌手: \(finalArtist)")
                                        } else {
                                            print("ACRCloudMatcher: 无法获取中文元数据，保持原值")
                                        }
                                    }
                                    
                                    // 4. 返回最终结果
                                    DispatchQueue.main.async {
                                        print("ACRCloudMatcher: 最终返回 - 歌曲: \(finalTitle), 歌手: \(finalArtist)")
                                        completion(finalTitle, finalArtist, offset)
                                    }
                                }
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
