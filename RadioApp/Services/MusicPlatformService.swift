import Foundation
import Combine
import CryptoKit
import os

private enum MusicSearchPlatform: String {
    case qqMusic = "QQMusic"
    case netEase = "NetEase"
}

private struct MusicSearchCandidate: Hashable {
    let platform: MusicSearchPlatform
    let id: String
    let title: String
    let artist: String
    let album: String?
    let artworkURL: String?
    let releaseDate: Date?
}

struct LyricResolvedSong {
    let title: String
    let artist: String
    let album: String?
    let lyrics: String
    let matchedSnippet: String
    let confidenceScore: Double
    let estimatedSongOffsetAtClipStart: TimeInterval?
    let source: String
    let originalIndex: Int
    let matchedSnippetsCount: Int
    let artworkURL: String?
    let releaseDate: Date?
}

class MusicPlatformService {
    static let shared = MusicPlatformService()
    private let logger = Logger(subsystem: "com.longhai.radioapp", category: "MusicPlatformService")
    
    // 匹配严格程度
    enum MatchStrictness {
        case strict     // 校验歌名和歌手
        case titleOnly  // 仅校验歌名 (忽略歌手不匹配)
        case fuzzy      // 模糊匹配 (歌名包含关系)
    }
    
    private init() {}

    private func makeQQSearchRequest(keyword: String, limit: Int, page: Int = 1) -> URLRequest? {
        guard let url = URL(string: "https://u.y.qq.com/cgi-bin/musicu.fcg") else {
            return nil
        }

        let payload: [String: Any] = [
            "comm": [
                "ct": 19,
                "cv": 1859,
                "uin": "0",
                "format": "json"
            ],
            "req_1": [
                "module": "music.search.SearchCgiService",
                "method": "DoSearchForQQMusicDesktop",
                "param": [
                    "query": keyword,
                    "search_type": 0,
                    "page_num": page,
                    "num_per_page": limit,
                    "grp": 1
                ]
            ]
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 10
        request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        return request
    }

    private func parseQQSearchCandidate(from song: [String: Any]) -> MusicSearchCandidate? {
        guard let id = (song["mid"] as? String) ?? (song["songmid"] as? String) else {
            return nil
        }

        let title = ((song["title"] as? String) ?? (song["songname"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let singers = song["singer"] as? [[String: Any]] ?? []
        let artist = singers
            .compactMap { ($0["name"] as? String) ?? ($0["title"] as? String) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let albumObject = song["album"] as? [String: Any]
        let album = ((albumObject?["name"] as? String) ?? (albumObject?["title"] as? String) ?? (song["albumname"] as? String))?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var artworkURL: String? = nil
        if let albummid = albumObject?["mid"] as? String, !albummid.isEmpty {
            artworkURL = "https://y.gtimg.cn/music/photo_new/T002R300x300M000\(albummid).jpg?max_age=2592000"
        }

        var releaseDate: Date? = nil
        if let timePublic = song["time_public"] as? String, !timePublic.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: timePublic) {
                releaseDate = date
            } else {
                formatter.dateFormat = "yyyy"
                releaseDate = formatter.date(from: timePublic)
            }
        }

        return MusicSearchCandidate(
            platform: .qqMusic,
            id: id,
            title: title,
            artist: artist,
            album: album,
            artworkURL: artworkURL,
            releaseDate: releaseDate
        )
    }

    private func searchQQSongs(keyword: String, limit: Int, page: Int = 1) async -> [MusicSearchCandidate] {
        guard let request = makeQQSearchRequest(keyword: keyword, limit: limit, page: page) else {
            logger.error("QQ 搜索请求构造失败")
            return []
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                logger.error("QQ 搜索失败 - HTTP \(httpResponse.statusCode)")
                return []
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let requestObject = (json["req_1"] as? [String: Any]) ?? (json["req"] as? [String: Any]),
                  let requestCode = requestObject["code"] as? Int,
                  requestCode == 0,
                  let requestData = requestObject["data"] as? [String: Any],
                  let body = requestData["body"] as? [String: Any],
                  let songObject = body["song"] as? [String: Any],
                  let list = songObject["list"] as? [[String: Any]] else {
                logger.error("QQ 搜索返回结构异常")
                return []
            }

            return list.compactMap(parseQQSearchCandidate)
        } catch {
            logger.error("QQ 搜索失败 - \(error.localizedDescription)")
            return []
        }
    }

    private func searchNetEaseSongs(keyword: String, limit: Int) async -> [MusicSearchCandidate] {
        guard let request = NetEaseSearchResolver.makeSearchRequest(keyword: keyword, limit: limit) else {
            logger.error("网易云搜索请求构造失败")
            return []
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                logger.error("网易云搜索失败 - HTTP \(httpResponse.statusCode)")
                return []
            }

            return try NetEaseSearchResolver.parseSongs(from: data).map { song in
                MusicSearchCandidate(
                    platform: .netEase,
                    id: song.id,
                    title: song.title,
                    artist: song.artist,
                    album: song.album,
                    artworkURL: song.artworkURL,
                    releaseDate: song.releaseDate
                )
            }
        } catch {
            logger.error("网易云搜索失败 - \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - 主入口
    
    /// 从 QQ 音乐/网易云音乐获取中文元数据
    /// - Parameters:
    ///   - title: 原始歌曲名 (可能是拼音)
    ///   - artist: 原始艺术家名 (可能是罗马化)
    /// - Returns: 搜索到的中文 (歌曲名, 艺术家名)，失败返回 nil
    func fetchChineseMetadata(title: String, artist: String) async -> (title: String, artist: String)? {
        logger.info("开始转换中文元数据 - Title: \(title, privacy: .public), Artist: \(artist, privacy: .public)")
        
        // 0. 判断是否通过歌手反查 (针对长拼音标题)
        // 如果标题很长且是拼音，直接搜标题容易失败。优先尝试搜歌手。
        if isPinyinOrRomanized(title) {
            logger.info("检测到拼音标题，尝试通过歌手反查...")
            if let result = await fetchChineseMetadataByArtistSearch(title: title, artist: artist) {
                return result
            }
        }
        
        // 阶段 1: 尝试 QQ 音乐 (常规关键词搜索)
        if let result = await fetchChineseMetadataFromQQ(title: title, artist: artist) {
            return result
        }
        
        // 阶段 2: QQ 音乐失败，尝试网易云音乐
        logger.info("QQ 音乐常规搜索失败，尝试网易云...")
        if let result = await fetchChineseMetadataFromNetEase(title: title, artist: artist) {
            return result
        }
        
        logger.info("所有平台均未获取到中文元数据")
        return nil
    }
    
    // MARK: - 歌手反查策略 (针对拼音标题)
    
    /// 通过搜索歌手，遍历其热门歌曲，进行拼音模糊匹配
    private func fetchChineseMetadataByArtistSearch(title: String, artist: String) async -> (title: String, artist: String)? {
        // 1. 确保有有效的歌手名 (如果是拼音歌手名，搜索效果可能不好，但也只能试)
        // 理想情况下 ACRCloud 对于知名歌手会返回 "Peng Jia Li" 或 "Angela Pang"
        // 我们可以只用 artist 搜索
        
        // 清理歌手名 (去括号等)
        let cleanArtist = normalizeString(artist, removeParenthesesContent: true) // "pang jia li"
        
        // 构造 QQ 音乐搜索 URL (只搜歌手 w=Artist, n=30 获取前30首)
        let query = cleanArtist
        logger.info("[歌手反查] 搜索 Query: \(query, privacy: .public)")

        let songs = await searchQQSongs(keyword: query, limit: 30)
        guard !songs.isEmpty else {
            return nil
        }

        logger.info("[歌手反查] 找到 \(songs.count) 首歌曲，开始本地拼音比对...")

        // 目标拼音 (归一化: 去空格，转小写)
        let targetPinyin = normalizePinyin(title)
        logger.debug("[歌手反查] Target Pinyin: \(targetPinyin, privacy: .public)")

        for song in songs {
            let resultTitle = song.title
            let resultArtist = song.artist

            if resultTitle.isEmpty { continue }

            let resultPinyin = normalizePinyin(toPinyin(resultTitle))

            if isPinyinSimilar(targetPinyin, resultPinyin) {
                logger.info("[歌手反查] 匹配成功!\n   - 原拼音: \(targetPinyin, privacy: .public)\n   - 本地转: \(resultPinyin, privacy: .public)\n   - 中文名: \(resultTitle, privacy: .public)")
                return (resultTitle, resultArtist)
            }
        }

        logger.info("[歌手反查] 未找到匹配歌曲")
        return nil
    }
    
    // MARK: - 拼音辅助工具
    
    /// 将拼音归一化 (去空格，去标点，转小写)
    private func normalizePinyin(_ pinyin: String) -> String {
        return pinyin.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
    
    /// 判断两个拼音是否足够相似
    private func isPinyinSimilar(_ p1: String, _ p2: String) -> Bool {
        // 1. 完全相等
        if p1 == p2 { return true }
        
        let longer = p1.count > p2.count ? p1 : p2
        let shorter = p1.count > p2.count ? p2 : p1
        
        // 2. 包含关系 (如果长度差异不大，或者是精准包含)
        if longer.contains(shorter) {
             // 如果短串足够长（例如 > 10 个字符），即使比例低也可以接受
             // 例如 "shibushizheyangdeyewan" (22) 在 "shibushizheyangdeyewannicaihui..." (50) 中
             // 此时比例 < 0.5，但是绝对长度足够长，应当匹配
             if shorter.count > 10 || Double(shorter.count) / Double(longer.count) > 0.5 {
                 return true
             }
        }
        
        // 3. 模糊前缀匹配 (针对截断标题且有拼音差异的情况)
        // 例如 "shibushizhiyangdeyewan" (zhi vs zhe)
        // 提取长串的前缀（长度等于短串），计算编辑距离
        if shorter.count > 5 {
            let prefix = String(longer.prefix(shorter.count))
            let distance = levenshtein(shorter, prefix)
            // 允许 20% 的差异
            if Double(distance) / Double(shorter.count) < 0.2 {
                logger.info("[Pinyin] Fuzzy Prefix Match: \(shorter, privacy: .public) ~= \(prefix, privacy: .public) (Full: \(longer, privacy: .public))")
                return true
            }
        }
        
        // 4. 编辑距离 (仅当长度接近时)
        if abs(p1.count - p2.count) < 5 {
            let distance = levenshtein(p1, p2)
            let maxLen = Double(max(p1.count, p2.count))
            // 允许 20% 的差异 (考虑到 zhi/zhe, di/de 这种差异)
            if Double(distance) / maxLen < 0.2 {
                return true
            }
        }
        
        return false
    }
    
    /// Levenshtein 编辑距离算法 (简化版)
    private func levenshtein(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1)
        let s2 = Array(s2)
        let (m, n) = (s1.count, s2.count)
        
        // 优化：如果差异太大，直接返回大值
        if abs(m - n) > 10 { return 100 }
        
        var d = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { d[i][0] = i }
        for j in 0...n { d[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1[i - 1] == s2[j - 1] ? 0 : 1
                d[i][j] = min(
                    d[i - 1][j] + 1,      // deletion
                    d[i][j - 1] + 1,      // insertion
                    d[i - 1][j - 1] + cost // substitution
                )
            }
        }
        
        return d[m][n]
    }

    
    // MARK: - 基础功能 (保留原有逻辑)
    
    /// 检查是否为衍生版本 (伴奏、DJ、Remix 等)
    private func isDerivative(_ title: String) -> Bool {
        let keywords = ["伴奏", "Instrumental", "Inst.", "Off Vocal", "DJ", "Remix", "Club Mix"]
        for keyword in keywords {
            if title.localizedCaseInsensitiveContains(keyword) {
                return true
            }
        }
        return false
    }

    /// 检查是否是 Live / 现场 / 综艺节目版本（用于非 Live 原唱提权）
    private func isLiveOrShow(_ title: String) -> Bool {
        let keywords = ["Live", "现场", "综艺", "歌手", "第", "季", "期", "会现场"]
        for keyword in keywords {
            if title.localizedCaseInsensitiveContains(keyword) {
                return true
            }
        }
        return false
    }
    
    /// 繁体转简体
    func toSimplifiedChinese(_ text: String) -> String {
        let mutableString = NSMutableString(string: text)
        CFStringTransform(mutableString, nil, "Hant-Hans" as CFString, false)
        return mutableString as String
    }
    
    /// 检测是否为拼音或罗马化格式 (只含 ASCII 字符)
    func isPinyinOrRomanized(_ text: String) -> Bool {
        // 如果字符串为空，返回 false
        guard !text.isEmpty else { return false }
        
        // 检查是否只包含 ASCII 字符 (英文字母、数字、空格、标点)
        let isAllASCII = text.unicodeScalars.allSatisfy { $0.isASCII }
        
        // 如果全是 ASCII 且长度 > 2，认为是拼音/罗马化
        return isAllASCII && text.count > 2
    }
    
    /// 清理标题：移除 (Live)、(Demo)、(Remix) 等后缀
    func cleanTitle(_ title: String) -> String {
        let patterns = [
            "\\s*[\\(\\[（]\\s*(Live|LIVE|现场|演唱会)\\s*[\\)\\]）]",
            "\\s*[\\(\\[（]\\s*(Demo|DEMO|试听|小样)\\s*[\\)\\]）]",
            "\\s*[\\(\\[（]\\s*(Remix|REMIX|混音)\\s*[\\)\\]）]",
            "\\s*[\\(\\[（]\\s*(Cover|COVER|翻唱)\\s*[\\)\\]）]",
            "\\s*[\\(\\[（]\\s*(Instrumental|伴奏)\\s*[\\)\\]）]",
            "\\s*-\\s*(Live|LIVE|现场版?)\\s*$"
        ]
        
        var result = title
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    /// 清理专辑名：移除 " - Single", " - EP" 等后缀
    func cleanAlbum(_ album: String) -> String {
        let patterns = [
            "\\s*-\\s*(Single|EP)\\s*$",            // " - Single", " - EP"
            "\\s*[\\(\\[（]\\s*(Single|EP)\\s*[\\)\\]）]" // " (Single)", " (EP)"
        ]
        
        var result = album
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    /// 转拼音 helper
    private func toPinyin(_ str: String) -> String {
        // 1. 转拉丁文 (拼音)
        let mutableString = NSMutableString(string: str)
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        
        // 2. 去声调
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        
        // 3. 去空格并转小写
        return (mutableString as String).replacingOccurrences(of: " ", with: "").lowercased()
    }
    
    // MARK: - QQ Music 常规搜索
    
    /// 从 QQ 音乐获取中文元数据
    private func fetchChineseMetadataFromQQ(title: String, artist: String) async -> (title: String, artist: String)? {
        let query = "\(title) \(artist)"

        let songs = await searchQQSongs(keyword: query, limit: 5)
        guard !songs.isEmpty else {
            return nil
        }

        func findBestMatch(allowDerivative: Bool) -> (title: String, artist: String)? {
            for (index, song) in songs.enumerated() {
                let resultTitle = song.title
                if resultTitle.isEmpty { continue }

                if !allowDerivative && isDerivative(resultTitle) { continue }

                let resultArtist = song.artist

                if !isPinyinOrRomanized(resultTitle) {
                    let queryTitlePinyin = normalizePinyin(toPinyin(title))
                    let resultTitlePinyin = normalizePinyin(toPinyin(resultTitle))

                    guard isPinyinSimilar(queryTitlePinyin, resultTitlePinyin) else { continue }

                    if !isPinyinOrRomanized(artist) {
                        let queryArtistNormalized = normalizeString(artist, removeParenthesesContent: false)
                        let resultArtistNormalized = normalizeString(resultArtist, removeParenthesesContent: false)

                        let artistMatch = queryArtistNormalized.contains(resultArtistNormalized) ||
                                          resultArtistNormalized.contains(queryArtistNormalized)

                        guard artistMatch else { continue }
                    }

                    print("MusicPlatformService: QQ 音乐成功获取中文元数据 (Idx: \(index))")
                    return (resultTitle, resultArtist)
                }
            }
            return nil
        }

        if let match = findBestMatch(allowDerivative: false) { return match }
        if let match = findBestMatch(allowDerivative: true) { return match }

        return nil
    }
    
    // MARK: - NetEase Cloud Music 常规搜索
    
    private func fetchChineseMetadataFromNetEase(title: String, artist: String) async -> (title: String, artist: String)? {
        let query = "\(title) \(artist)"

        let songs = await searchNetEaseSongs(keyword: query, limit: 5)
        guard !songs.isEmpty else {
            return nil
        }

        func findBestMatch(allowDerivative: Bool) -> (title: String, artist: String)? {
            for (index, song) in songs.enumerated() {
                let resultTitle = song.title
                if resultTitle.isEmpty { continue }

                if !allowDerivative && isDerivative(resultTitle) { continue }

                let resultArtist = song.artist

                if !isPinyinOrRomanized(resultTitle) {
                     let queryTitlePinyin = normalizePinyin(toPinyin(title))
                     let resultTitlePinyin = normalizePinyin(toPinyin(resultTitle))

                     guard isPinyinSimilar(queryTitlePinyin, resultTitlePinyin) else { return nil }

                    if !isPinyinOrRomanized(artist) {
                        let queryArtistNormalized = normalizeString(artist, removeParenthesesContent: false)
                        let resultArtistNormalized = normalizeString(resultArtist, removeParenthesesContent: false)

                        let artistMatch = queryArtistNormalized.contains(resultArtistNormalized) ||
                                          resultArtistNormalized.contains(queryArtistNormalized)

                        guard artistMatch else { continue }
                    }

                    print("MusicPlatformService: 网易云成功获取中文元数据 (Idx: \(index))")
                    return (resultTitle, resultArtist)
                }
            }
            return nil
        }

        if let match = findBestMatch(allowDerivative: false) { return match }
        if let match = findBestMatch(allowDerivative: true) { return match }
        return nil
    }
    
    // MARK: - String Helpers
    
    private func normalizeString(_ str: String, removeParenthesesContent: Bool = true) -> String {
        var result = str.applyingTransform(StringTransform("Any-Hans"), reverse: false) ?? str
        
        let specialMappings: [Character: Character] = [
            "妳": "你", "祂": "他", "牠": "它", "著": "着"
        ]
        result = String(result.map { specialMappings[$0] ?? $0 })
        
        if removeParenthesesContent {
            result = result.replacingOccurrences(of: "\\s*[\\(\\[（\\{][^\\)\\]）\\}]*[\\)\\]）\\}]", with: "", options: .regularExpression)
        }
        
        result = result.lowercased()
        
        let fillers = ["粤语", "国语", "版", "music", "video", "official"]
        for filler in fillers {
            result = result.replacingOccurrences(of: filler, with: "")
        }
        
        // 移除标点
        result = result.components(separatedBy: CharacterSet.punctuationCharacters.union(.symbols).union(.whitespacesAndNewlines))
            .joined()
        
        return result
    }
    
    // MARK: - Lyrics & iTunes (Existing)
    
    func fetchLyrics(title: String, artist: String) async -> String? {
        // [Existing implementation...]
        // 为了缩减篇幅，这里暂时只写出结构，实际部署时需要完整搬运或者简化
        // 既然我们正在重写整个类，这里需要完整实现 fetchLyrics 的逻辑
        // (Copied from previous ShazamMatcher.swift implementation)
        
        print("MusicPlatformService: 开始获取歌词 - Title: \(title), Artist: \(artist)")
        
        // 阶段 1: 严格匹配
        if let lyrics = await fetchQQLyrics(title: title, artist: artist, strictness: .strict) { return lyrics }
        if let lyrics = await fetchNetEaseLyrics(title: title, artist: artist, strictness: .strict) { return lyrics }
        
        // 阶段 2: 宽松匹配 (Title Only)
        if let lyrics = await fetchQQLyrics(title: title, artist: artist, strictness: .titleOnly) { return lyrics }
        if let lyrics = await fetchNetEaseLyrics(title: title, artist: artist, strictness: .titleOnly) { return lyrics }
        
        // 阶段 3: Fuzzy
        if let lyrics = await fetchQQLyrics(title: title, artist: artist, strictness: .fuzzy) { return lyrics }
        if let lyrics = await fetchNetEaseLyrics(title: title, artist: artist, strictness: .fuzzy) { return lyrics }
        
        return nil
    }

    func resolveSongFromLyricSnippets(_ snippets: [LyricSnippet]) async -> LyricResolvedSong? {
        let songs = await resolveSongsFromLyricSnippets(snippets)
        return songs.first
    }

    func resolveSongsFromLyricSnippets(_ snippets: [LyricSnippet], currentStreamTitle: String? = nil) async -> [LyricResolvedSong] {
        let usableSnippets = snippets.filter { normalizedLyricSearchText($0.text).count >= 6 }
        guard !usableSnippets.isEmpty else { return [] }

        var candidates: [MusicSearchCandidate] = []
        var seenQueries = Set<String>()

        for snippet in usableSnippets.prefix(3) {
            let query = compactLyricQuery(snippet.text)
            let normalizedQuery = normalizedLyricSearchText(query)
            guard seenQueries.insert(normalizedQuery).inserted else { continue }

            candidates.append(contentsOf: await searchQQSongCandidates(keyword: query, limit: 6))
            candidates.append(contentsOf: await searchNetEaseSongCandidates(keyword: query, limit: 6))
        }

        var uniqueCandidates: [MusicSearchCandidate] = []
        var seenCandidateKeys = Set<String>()

        for candidate in candidates {
            let key = "\(normalizeString(candidate.title))::\(normalizeString(candidate.artist, removeParenthesesContent: false))"
            guard seenCandidateKeys.insert(key).inserted else { continue }
            uniqueCandidates.append(candidate)
        }

        var matchedSongs: [LyricResolvedSong] = []

        for (index, candidate) in uniqueCandidates.prefix(12).enumerated() {
            guard let lyrics = await fetchLyrics(for: candidate) else { continue }
            let (score, matchedSnippet, matchCount) = bestSnippetMatchScore(in: lyrics, snippets: usableSnippets)
            guard let matchedSnippet, score >= 0.55 else { continue }

            var finalTitle = cleanTitle(toSimplifiedChinese(candidate.title))
            var finalArtist = toSimplifiedChinese(candidate.artist)
            let finalAlbum = cleanAlbum(toSimplifiedChinese(candidate.album ?? ""))

            if isPinyinOrRomanized(finalTitle),
               let chineseMeta = await fetchChineseMetadata(title: finalTitle, artist: finalArtist) {
                finalTitle = chineseMeta.title
                finalArtist = chineseMeta.artist
            }

            let song = LyricResolvedSong(
                title: finalTitle,
                artist: finalArtist,
                album: finalAlbum.isEmpty ? nil : finalAlbum,
                lyrics: lyrics,
                matchedSnippet: matchedSnippet.text,
                confidenceScore: score,
                estimatedSongOffsetAtClipStart: estimateSongOffsetAtClipStart(
                    lyrics: lyrics,
                    matchedSnippet: matchedSnippet
                ),
                source: candidate.platform == .qqMusic ? "qq" : "netease",
                originalIndex: index,
                matchedSnippetsCount: matchCount,
                artworkURL: candidate.artworkURL,
                releaseDate: candidate.releaseDate
            )
            matchedSongs.append(song)
        }

        let sortedSongs = matchedSongs.sorted { lhs, rhs in
            // 1. 优先根据匹配到的不同歌词片段数量排序
            if lhs.matchedSnippetsCount != rhs.matchedSnippetsCount {
                return lhs.matchedSnippetsCount > rhs.matchedSnippetsCount
            }
            
            // 2. 数量一样时，优先选择非 Live/非现场/非综艺的版本（录音室原版优先）
            let lhsIsLive = self.isLiveOrShow(lhs.title)
            let rhsIsLive = self.isLiveOrShow(rhs.title)
            if lhsIsLive != rhsIsLive {
                return !lhsIsLive && rhsIsLive
            }
            
            // 3. 数量和 Live 状态一样时，如果置信度非常接近 (相差在 0.02 以内)
            if abs(lhs.confidenceScore - rhs.confidenceScore) < 0.02 {
                if let currentStreamTitle = currentStreamTitle {
                    let lhsMetaScore = self.scoreCandidateAgainstMetadata(title: lhs.title, artist: lhs.artist, streamTitle: currentStreamTitle)
                    let rhsMetaScore = self.scoreCandidateAgainstMetadata(title: rhs.title, artist: rhs.artist, streamTitle: currentStreamTitle)
                    if lhsMetaScore != rhsMetaScore {
                        return lhsMetaScore > rhsMetaScore
                    }
                }
                // 优先选择原始搜索更靠前的候选 (更可能是流行度高/原唱版本)
                return lhs.originalIndex < rhs.originalIndex
            }
            return lhs.confidenceScore > rhs.confidenceScore
        }
        var finalSongs: [LyricResolvedSong] = []
        var seenKeys = Set<String>()
        
        for song in sortedSongs {
            let nTitle = song.title.lowercased().replacingOccurrences(of: "[^\\p{Han}\\p{Latin}\\p{Nd}]", with: "", options: .regularExpression)
            let nArtist = song.artist.lowercased().replacingOccurrences(of: "[^\\p{Han}\\p{Latin}\\p{Nd}]", with: "", options: .regularExpression)
            
            // 使用渲染副标题来去重，如果展示副标题（专辑名，若无则歌名）相同，则进行合并
            let displaySubtitle = song.album ?? song.title
            let nSubtitle = displaySubtitle.lowercased().replacingOccurrences(of: "[^\\p{Han}\\p{Latin}\\p{Nd}]", with: "", options: .regularExpression)
            
            let key = "\(nTitle)::\(nArtist)::\(nSubtitle)"
            if !seenKeys.contains(key) {
                seenKeys.insert(key)
                finalSongs.append(song)
            }
        }
        
        return finalSongs
    }
    
    private func scoreCandidateAgainstMetadata(title: String, artist: String, streamTitle: String?) -> Double {
        guard let streamTitle = streamTitle, !streamTitle.isEmpty else { return 0 }
        
        let cleanedStream = streamTitle.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        
        var streamArtist = ""
        var streamTitlePart = cleanedStream
        
        let separators = [" - ", " — ", " – ", " ~ "]
        for sep in separators {
            if let range = cleanedStream.range(of: sep) {
                streamArtist = String(cleanedStream[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                streamTitlePart = String(cleanedStream[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        if streamArtist.isEmpty {
            let parts = cleanedStream.components(separatedBy: "-")
            if parts.count >= 2 {
                streamArtist = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                streamTitlePart = parts[1...].joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        let normStreamTitle = normalizeSongTextForCompare(streamTitlePart)
        let normStreamArtist = normalizeSongTextForCompare(streamArtist)
        let normCandidateTitle = normalizeSongTextForCompare(title)
        let normCandidateArtist = normalizeSongTextForCompare(artist)
        
        let titleScore = scoreTextMatch(normCandidateTitle, normStreamTitle) * 0.6
        let artistScore = scoreTextMatch(normCandidateArtist, normStreamArtist) * 0.4
        
        return min(titleScore + artistScore, 1.0)
    }
    
    private func normalizeSongTextForCompare(_ text: String) -> String {
        let simplified = toSimplifiedChinese(text).lowercased()
        let withoutParentheses = simplified.replacingOccurrences(of: "[（\\(].*?[）\\)]", with: "", options: .regularExpression)
        let cleaned = withoutParentheses.replacingOccurrences(of: "[^\\p{Han}\\p{Latin}\\p{Nd}]", with: "", options: .regularExpression)
        return cleaned
    }
    
    private func scoreTextMatch(_ candidateText: String, _ metadataText: String) -> Double {
        if candidateText.isEmpty || metadataText.isEmpty { return 0 }
        if candidateText == metadataText { return 1.0 }
        if candidateText.contains(metadataText) || metadataText.contains(candidateText) {
            return Double(min(candidateText.count, metadataText.count)) / Double(max(candidateText.count, metadataText.count))
        }
        return 0
    }
    
    // QQ Music ID Search (Refactored for public use if needed, or private)
    func findQQMusicIDs(title: String, artist: String, strictness: MatchStrictness = .fuzzy) async -> [String] {
        let query = "\(title) \(artist)"
        let candidates = await searchQQSongs(keyword: query, limit: 5)

        return candidates.compactMap { song in
            if isMatch(
                queryTitle: title,
                queryArtist: artist,
                resultTitle: song.title,
                resultArtist: song.artist,
                strictness: strictness
            ) {
                return song.id
            }
            return nil
        }
    }
    
    // NetEase ID Search
    func findNetEaseIDs(title: String, artist: String, strictness: MatchStrictness = .fuzzy) async -> [String] {
        let query = "\(title) \(artist)"
        let candidates = await searchNetEaseSongs(keyword: query, limit: 5)
        let matchedCandidates = candidates.filter { song in
            isMatch(
                queryTitle: title,
                queryArtist: artist,
                resultTitle: song.title,
                resultArtist: song.artist,
                strictness: strictness
            )
        }

        let rankedCandidates = matchedCandidates.sorted { lhs, rhs in
            let lhsScore = NetEaseSearchResolver.matchPriority(
                queryTitle: title,
                queryArtist: artist,
                songTitle: lhs.title,
                songArtist: lhs.artist,
                songAlbum: lhs.album
            )
            let rhsScore = NetEaseSearchResolver.matchPriority(
                queryTitle: title,
                queryArtist: artist,
                songTitle: rhs.title,
                songArtist: rhs.artist,
                songAlbum: rhs.album
            )

            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }

            return lhs.id < rhs.id
        }

        return rankedCandidates.map(\.id)
    }
    
    // Lyrics Fetchers
    private func fetchQQLyrics(title: String, artist: String, strictness: MatchStrictness) async -> String? {
        let songmids = await findQQMusicIDs(title: title, artist: artist, strictness: strictness)
        for songmid in songmids {
            if let lyric = await fetchQQLyrics(songmid: songmid) {
                return lyric
            }
        }
        return nil
    }
    
    private func fetchNetEaseLyrics(title: String, artist: String, strictness: MatchStrictness) async -> String? {
        let ids = await findNetEaseIDs(title: title, artist: artist, strictness: strictness)
        for id in ids {
            if let lyric = await fetchNetEaseLyrics(id: id) {
                return lyric
            }
        }
        return nil
    }

    /// iTunes Release Date
    func fetchReleaseDateFromiTunes(appleMusicID: String) async -> Date? {
        let urlString = "https://itunes.apple.com/lookup?id=\(appleMusicID)&country=CN"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let firstResult = results.first,
               let releaseDateStr = firstResult["releaseDate"] as? String {
                
                let formatter = ISO8601DateFormatter()
                return formatter.date(from: releaseDateStr)
            }
        } catch {}
        return nil
    }
    
    // MARK: - Matching Logic Helper (from broken out class)
    
    private func isMatch(queryTitle: String, queryArtist: String, resultTitle: String, resultArtist: String, strictness: MatchStrictness) -> Bool {
        // 1. Title Match
        let qTitle = normalizeString(queryTitle, removeParenthesesContent: true)
        let rTitle = normalizeString(resultTitle, removeParenthesesContent: true)
        
        var titleMatch = false
        
        if strictness == .fuzzy {
            // Fuzzy: contain check or pinyin contain
            if !qTitle.isEmpty && !rTitle.isEmpty && (qTitle.contains(rTitle) || rTitle.contains(qTitle)) {
                titleMatch = true
            } else {
                let qPinyin = normalizePinyin(toPinyin(qTitle))
                let rPinyin = normalizePinyin(toPinyin(rTitle))
                if isPinyinSimilar(qPinyin, rPinyin) {
                    titleMatch = true
                }
            }
        } else {
            // Strict/TitleOnly: exact match or pinyin exact match
            if qTitle == rTitle {
                titleMatch = true
            } else {
                 let qPinyin = normalizePinyin(toPinyin(qTitle))
                 let rPinyin = normalizePinyin(toPinyin(rTitle))
                 if qPinyin == rPinyin {
                     titleMatch = true
                 }
            }
        }
        
        if !titleMatch { return false }
        if strictness == .titleOnly { return true }
        
        // 2. Artist Match
        // Use simple containment for now to keep it concise, or copy full token logic if imperative
        // copying simple token logic:
        let qArtist = normalizeString(queryArtist, removeParenthesesContent: false)
        let rArtist = normalizeString(resultArtist, removeParenthesesContent: false)
        
        return qArtist.contains(rArtist) || rArtist.contains(qArtist)
    }

    private func fetchLyrics(for candidate: MusicSearchCandidate) async -> String? {
        switch candidate.platform {
        case .qqMusic:
            return await fetchQQLyrics(songmid: candidate.id)
        case .netEase:
            return await fetchNetEaseLyrics(id: candidate.id)
        }
    }

    private func fetchQQLyrics(songmid: String) async -> String? {
        let urlString = "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=\(songmid)&format=json&nobase64=1"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let lyric = json["lyric"] as? String, !lyric.isEmpty {
                return lyric
            }
        } catch {
            logger.error("QQ 歌词拉取失败 - \(error.localizedDescription)")
        }

        return nil
    }

    private func fetchNetEaseLyrics(id: String) async -> String? {
        let urlString = "http://music.163.com/api/song/lyric?id=\(id)&lv=1&kv=1&tv=-1"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("http://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let lrc = json["lrc"] as? [String: Any],
               let lyric = lrc["lyric"] as? String, !lyric.isEmpty {
                return lyric
            }
        } catch {
            logger.error("网易云歌词拉取失败 - \(error.localizedDescription)")
        }

        return nil
    }

    private func searchQQSongCandidates(keyword: String, limit: Int) async -> [MusicSearchCandidate] {
        let candidates = await searchQQSongs(keyword: keyword, limit: limit)
        return candidates.filter { !isDerivative($0.title) }
    }

    private func searchNetEaseSongCandidates(keyword: String, limit: Int) async -> [MusicSearchCandidate] {
        let candidates = await searchNetEaseSongs(keyword: keyword, limit: limit)
        return candidates.filter { !isDerivative($0.title) }
    }

    private struct LyricWindow {
        let time: TimeInterval
        let text: String
    }

    private func buildLyricWindows(lines: [LyricLine]) -> [LyricWindow] {
        var windows = [LyricWindow]()
        for (index, line) in lines.enumerated() {
            windows.append(LyricWindow(time: line.time, text: line.text))
            
            if index + 1 < lines.count {
                let nextLine = lines[index + 1]
                windows.append(LyricWindow(time: line.time, text: line.text + nextLine.text))
                
                if index + 2 < lines.count {
                    let thirdLine = lines[index + 2]
                    windows.append(LyricWindow(time: line.time, text: line.text + nextLine.text + thirdLine.text))
                }
            }
        }
        return windows
    }

    private func bigramDiceScore(lhs: String, rhs: String) -> Double {
        let lhsBigrams = makeBigrams(lhs)
        let rhsBigrams = makeBigrams(rhs)
        if lhsBigrams.isEmpty || rhsBigrams.isEmpty { return 0 }

        var rhsCounts = [String: Int]()
        for bigram in rhsBigrams {
            rhsCounts[bigram] = (rhsCounts[bigram] ?? 0) + 1
        }

        var overlap = 0
        for bigram in lhsBigrams {
            if let count = rhsCounts[bigram], count > 0 {
                overlap += 1
                rhsCounts[bigram] = count - 1
            }
        }

        let dice = Double(2 * overlap) / Double(lhsBigrams.count + rhsBigrams.count)
        let overlapRatio = Double(overlap) / Double(min(lhsBigrams.count, rhsBigrams.count))
        
        return max(dice, overlapRatio * 0.85)
    }

    private func makeBigrams(_ text: String) -> [String] {
        if text.count < 2 { return [] }
        let chars = Array(text)
        var bigrams = [String]()
        for index in 0..<(chars.count - 1) {
            bigrams.append(String(chars[index...index+1]))
        }
        return bigrams
    }

    private func bestSnippetMatchScore(in lyrics: String, snippets: [LyricSnippet]) -> (score: Double, matchedSnippet: LyricSnippet?, matchCount: Int) {
        let lines = LRCParser.parse(lrc: lyrics)
        guard !lines.isEmpty else { return (0, nil, 0) }

        let windows = buildLyricWindows(lines: lines)
        var bestScore = 0.0
        var bestSnippet: LyricSnippet?
        var matchCount = 0

        for snippet in snippets {
            let normalizedSnippet = normalizedLyricSearchText(snippet.text)
            guard normalizedSnippet.count >= 6 else { continue }

            var bestScoreForThisSnippet = 0.0
            for window in windows {
                let normalizedWindow = normalizedLyricSearchText(window.text)
                guard normalizedWindow.count >= 4 else { continue }

                let score: Double
                if normalizedWindow.contains(normalizedSnippet) || normalizedSnippet.contains(normalizedWindow) {
                    score = Double(min(normalizedWindow.count, normalizedSnippet.count)) / Double(max(normalizedWindow.count, normalizedSnippet.count))
                } else {
                    score = bigramDiceScore(lhs: normalizedSnippet, rhs: normalizedWindow)
                }

                if score > bestScoreForThisSnippet {
                    bestScoreForThisSnippet = score
                }
            }

            let weightedScore = bestScoreForThisSnippet * (0.85 + (snippet.confidenceScore * 0.15))
            
            if bestScoreForThisSnippet >= 0.55 {
                matchCount += 1
            }

            let bestSnippetHasTiming = bestSnippet?.start != nil
            let snippetHasTiming = snippet.start != nil

            if weightedScore > bestScore + 0.0001 ||
                (abs(weightedScore - bestScore) <= 0.0001 && snippetHasTiming && !bestSnippetHasTiming) {
                bestScore = weightedScore
                bestSnippet = snippet
            }
        }

        return (bestScore, bestSnippet, matchCount)
    }

    private func estimateSongOffsetAtClipStart(lyrics: String, matchedSnippet: LyricSnippet) -> TimeInterval? {
        guard let snippetStart = matchedSnippet.start else { return nil }

        let lines = LRCParser.parse(lrc: lyrics)
        guard !lines.isEmpty else { return nil }

        let normalizedSnippet = normalizedLyricSearchText(matchedSnippet.text)
        guard !normalizedSnippet.isEmpty else { return nil }

        let windows = buildLyricWindows(lines: lines)
        var bestWindow: LyricWindow? = nil
        var maxScore: Double = -1.0

        for window in windows {
            let normalizedWindow = normalizedLyricSearchText(window.text)
            guard !normalizedWindow.isEmpty else { continue }

            let score: Double
            if normalizedWindow.contains(normalizedSnippet) || normalizedSnippet.contains(normalizedWindow) {
                score = Double(min(normalizedWindow.count, normalizedSnippet.count)) / Double(max(normalizedWindow.count, normalizedSnippet.count))
            } else {
                score = bigramDiceScore(lhs: normalizedSnippet, rhs: normalizedWindow)
            }

            if score > maxScore {
                maxScore = score
                bestWindow = window
            }
        }

        if let bestWindow = bestWindow, maxScore >= 0.55 {
            return max(0, bestWindow.time - snippetStart)
        }

        return nil
    }

    private func compactLyricQuery(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !collapsed.isEmpty else { return text }

        let words = collapsed.split(separator: " ")
        if words.count > 8 {
            return words.prefix(8).joined(separator: " ")
        }

        if words.count <= 1 && collapsed.count > 18 {
            return String(collapsed.prefix(18))
        }

        return collapsed
    }

    private func normalizedLyricSearchText(_ text: String) -> String {
        let simplified = toSimplifiedChinese(text)
        let withoutTimestamps = simplified.replacingOccurrences(
            of: "\\[[^\\]]+\\]",
            with: " ",
            options: .regularExpression
        )

        return withoutTimestamps
            .lowercased()
            .replacingOccurrences(of: "[^\\p{Han}\\p{Latin}\\p{Nd}]", with: "", options: .regularExpression)
    }
}
