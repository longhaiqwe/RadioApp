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
    
    // The current active base URL
    private var activeBaseURL: String = "https://de1.api.radio-browser.info/json"
    private var isServerResolved = false
    
    private init() {
        // Start server discovery in background
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
                    request.timeoutInterval = 3.0 // Increased slightly for connectivity issues
                    
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
        }
        
        // IMPORTANT: Mark resolved true regardless of success/fail to prevent infinite retries during search
        self.isServerResolved = true
    }
    
    // ensure we have a good server before making requests (optional, usually strict)
    private func ensureServer() async {
        if !isServerResolved {
            await resolveBestServer()
        }
    }
    
    // MARK: - Core API Methods
    
    /// Advanced search using the generic /search endpoint
    func advancedSearch(filter: StationFilter) async throws -> [Station] {
        await ensureServer()
        
        guard let url = URL(string: "\(activeBaseURL)/stations/search") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("iOS-Radio-App/1.0", forHTTPHeaderField: "User-Agent")
        
        request.httpBody = try JSONEncoder().encode(filter)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let stations = try JSONDecoder().decode([Station].self, from: data)
        return stations
    }
    
    /// Fetch top stations (defaulting to China)
    func fetchTopStations(limit: Int = 20) async throws -> [Station] {
        // We can just use advanced search for this too!
        var filter = StationFilter()
        filter.countryCode = "CN"
        filter.order = "clickcount"
        filter.reverse = true
        filter.limit = limit
        return try await advancedSearch(filter: filter)
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
        filter.limit = 100 // Get enough candidates
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
                return deduplicateStations(stations)
            }
            
            return deduplicateStations(filtered)
        }
        
        return deduplicateStations(stations)
    }
    
    /// Deduplicates stations by name, keeping only the highest bitrate version
    private func deduplicateStations(_ stations: [Station]) -> [Station] {
        // 1. Sort by bitrate descending so the highest quality comes first
        let sorted = stations.sorted { $0.bitrate > $1.bitrate }
        
        // 2. Filter duplicates by name
        var seenNames = Set<String>()
        var result: [Station] = []
        
        for station in sorted {
            let name = station.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !seenNames.contains(name) {
                seenNames.insert(name)
                result.append(station)
            }
        }
        
        return result
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
        await ensureServer()
        
        guard let url = URL(string: "\(activeBaseURL)/tags?order=stationcount&reverse=true&limit=\(limit)") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let tags = try JSONDecoder().decode([Tag].self, from: data)
        return tags
    }
}
