import Foundation

struct StationFilter: Encodable {
    var name: String?
    var nameExact: Bool?
    var country: String?
    var countryCode: String?
    var state: String?
    var language: String?
    var tag: String?
    var tagExact: Bool?
    var bitrateMin: Int?
    var order: String? // "clickcount", "votes", "name", "random"
    var reverse: Bool?
    var limit: Int = 20
    var offset: Int = 0
    var hideBroken: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case name, country, state, language, tag, order, reverse, limit, offset
        case nameExact = "name_exact"
        case countryCode = "countrycode"
        case tagExact = "tag_exact"
        case bitrateMin = "bitrate_min"
        case hideBroken = "hidebroken"
    }
}

class RadioService {
    static let shared = RadioService()
    
    // Default mirrors (fallback)
    private let defaultMirrors = [
        "https://de1.api.radio-browser.info/json",
        "https://fr1.api.radio-browser.info/json",
        "https://at1.api.radio-browser.info/json",
        "https://nl1.api.radio-browser.info/json",
        "https://all.api.radio-browser.info/json",
        // Fallback for strict TLS environments (like China sometimes):
        "http://all.api.radio-browser.info/json"
    ]
    
    // Cache key for persisting the best server across launches
    private let kBestServerKey = "radio_best_server_url"
    
    // App Store compliance filtering is now handled by StationBlockManager (Local + Online)
    
    // The current active base URL — initialized from cache or default, updated in background
    private var activeBaseURL: String
    
    private init() {
        // 1. 优先从缓存读取上次的最优服务器，实现"秒开"
        if let cached = UserDefaults.standard.string(forKey: kBestServerKey), !cached.isEmpty {
            self.activeBaseURL = cached
        } else {
            self.activeBaseURL = "https://de1.api.radio-browser.info/json"
        }
        
        // 2. 后台静默更新最优服务器，不阻塞任何请求
        Task {
            await resolveBestServer()
        }
    }
    
    /// Finds the fastest working server
    func resolveBestServer() async {

        
        // We will race the mirrors with a simple "stats" or "config" HEAD request
        let resolvedURL: String? = await withTaskGroup(of: String?.self) { group in
            for mirror in defaultMirrors {
                group.addTask {
                    guard let url = URL(string: "\(mirror)/config") else { return nil }
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 5.0 // Increased slightly for connectivity issues
                    
                    do {
                        let (_, response) = try await URLSession.shared.data(for: request)
                        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                            return mirror
                        }
                    } catch {
                        // ignore error
                    }
                    return nil
                }
            }
            
            // Return the first one that completes successfully
            for await result in group {
                if let validMirror = result {
                    return validMirror
                }
            }
            return nil
        }
        
        if let best = resolvedURL {
            self.activeBaseURL = best
            // 缓存最优服务器，下次冷启动直接使用
            UserDefaults.standard.set(best, forKey: kBestServerKey)
        }
    }
    
    // ensureServer is no longer needed — we use an optimistic strategy:
    // init() loads the cached/default server immediately, background task updates it.
    
    // MARK: - Core API Methods
    
    /// Advanced search using the generic /search endpoint
    func advancedSearch(filter: StationFilter) async throws -> [Station] {
        // 乐观策略：直接使用当前 activeBaseURL，不等待服务器解析
        
        guard let url = URL(string: "\(activeBaseURL)/stations/search") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("iOS-Radio-App/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0 // 10秒超时避免无限等待
        
        request.httpBody = try JSONEncoder().encode(filter)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let stations = try JSONDecoder().decode([Station].self, from: data)
        return self.filterBlockedStations(stations)
    }
    
    /// Fetch top stations (prioritizing Music, excluding News)
    func fetchTopStations(limit: Int = 20) async throws -> [Station] {
        // We utilize advanced search to fetch more candidates first
        var filter = StationFilter()
        filter.countryCode = "CN"
        filter.order = "clickcount"
        filter.reverse = true
        filter.limit = 100 // Fetch more to filter client-side
        
        let stations = try await advancedSearch(filter: filter)
        
        // Filter logic:
        // 1. MUST have one of "musicTags" in tags OR tags is empty (sometimes pure music stations have no tags, risky? let's require tags for safety)
        // 2. Apply global blocklist (already done in advancedSearch)
        
        let musicTags = ["music", "pop", "hits", "rock", "jazz", "classical", "音乐", "流行", "top40", "dance", "rnb", "lofi"]
        
        let filtered = stations.filter { station in
            let tags = station.tags.lowercased()
            // let name = station.name.lowercased()
            
            // Positive Selection: Must contain at least one music tag
            for tag in musicTags {
                if tags.contains(tag) { return true }
            }
            
            return false // Reject if no music tag matches
        }
        
        // Sort: Music stations first? Or just rely on clickcount?
        // Let's just return the top N from the safe list
        return Array(filtered.prefix(limit))
    }
    
    /// Fetch a random station (Surprise Me)
    /// Logic: Search for "music" in "CN" with "random" order, limit to a pool to avoid duplicates.
    func fetchRandomStation(excluding excludedId: String? = nil) async throws -> Station? {
        var filter = StationFilter()
        filter.countryCode = "CN"
        // Remove strict server-side tag="music" to get a broader pool
        filter.order = "random"
        filter.limit = 100 // Fetch a large pool to filter client-side
        
        // 1. Fetch candidates (server-side shuffled)
        let stations = try await advancedSearch(filter: filter)
        
        // 2. Client-side filtering
        // Reuse common music/radio tags to ensure quality/relevance
        let musicTags = ["music", "pop", "hits", "rock", "jazz", "classical", "音乐", "流行", "top40", "dance", "rnb", "lofi", "radio", "fm", "电台", "之声", "资讯", "新闻"]
        
        let candidates = filterBlockedStations(stations).filter { station in
            // Exclude current station
            if let excluded = excludedId, station.id == excluded { return false }
            
            let tags = station.tags.lowercased()
            let name = station.name.lowercased()
            
            // Broad match: checks tags OR name for keywords
            for keyword in musicTags {
                if tags.contains(keyword) || name.contains(keyword) { return true }
            }
            
            // Fallback: if no tags but name is long enough (likely a real station name), keep it for variety
            // This helps discover stations that might not have perfect tags
            return !tags.isEmpty || name.count > 2
        }
        
        // 3. Pick one randomly from the filtered valid candidates
        return candidates.randomElement()
    }
    
    // MARK: - Convenience / Smart Search
    
    /// Smart search that handles "1017" frequency fixes and keyword splitting
    func searchStations(name: String) async throws -> [Station] {
        // 1. Pre-process logic (Kept from previous fix)
        // Insert space between non-digit and digit, but respect floating point "101.7"
        var processedName = name
        if let regex = try? NSRegularExpression(pattern: "([^\\d.])(\\d)", options: []) {
            processedName = regex.stringByReplacingMatches(in: processedName, options: [], range: NSRange(location: 0, length: processedName.utf16.count), withTemplate: "$1 $2")
        }
        
        let keywords = processedName.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        

        
        guard let firstKeyword = keywords.first else { return [] }
        
        // 2. Initial Fetch using the first keyword
        // usage of advancedSearch allows us to do this cleanly
        var filter = StationFilter()
        filter.name = firstKeyword
        filter.limit = 500 // Get enough candidates
        filter.hideBroken = true
        
        let stations = try await advancedSearch(filter: filter)

        
        // 3. Client-side filtering for remaining keywords
        if keywords.count > 1 {
            let remainingKeywords = keywords.dropFirst()
            let filtered = stations.filter { station in
                let stationName = station.name.lowercased()
                let stationTags = station.tags.lowercased()
                
                return remainingKeywords.allSatisfy { keyword in
                    let lowerKeyword = keyword.lowercased()
                    
                    // Direct match
                    if stationName.contains(lowerKeyword) || stationTags.contains(lowerKeyword) { return true }
                    
                    // Frequency fuzzy match (e.g. "1017" -> "101.7")
                    if let number = Int(keyword), String(number) == keyword {
                         if keyword.count > 2 {
                             let decimalKeyword = String(keyword.dropLast()) + "." + String(keyword.suffix(1))
                             if stationName.contains(decimalKeyword) || stationTags.contains(decimalKeyword) { return true }
                         }
                    }
                    return false
                }
            }
            

            
            // Fallback logic
            if filtered.isEmpty && !stations.isEmpty {
                return stations
            }
            
            return filtered
        }
        
        return stations
    }
    

    
    func fetchStationsByCountryCode(_ code: String, limit: Int = 20) async throws -> [Station] {
        var filter = StationFilter()
        filter.countryCode = code
        filter.limit = limit
        filter.order = "clickcount"
        filter.reverse = true
        return try await advancedSearch(filter: filter)
    }
    
    // MARK: - Tags / Styles
    
    struct Tag: Codable {
        let name: String
        let stationcount: Int
    }
    
    /// Fetch top tags (styles) from the API
    func fetchTopTags(limit: Int = 100) async throws -> [Tag] {
        // 乐观策略：直接使用当前 activeBaseURL
        
        guard let url = URL(string: "\(activeBaseURL)/tags?order=stationcount&reverse=true&limit=\(limit)") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let tags = try JSONDecoder().decode([Tag].self, from: data)
        return tags
    }
    
    // MARK: - Helper Methods
    
    /// Filter out stations containing blocked keywords OR hidden by user (Local + Online)
    private func filterBlockedStations(_ stations: [Station]) -> [Station] {
        return stations.filter { station in
            // Unified check for Local Block, Online Block, and Keywords
            !StationBlockManager.shared.isBlocked(station)
        }
    }
}
