import Foundation
import Combine

struct OnlineBlacklistItem: Decodable {
    let type: String
    let value: String
    let is_active: Bool?
}

class StationBlockManager: ObservableObject {
    static let shared = StationBlockManager()
    
    // Config
    private let supabaseURL = "https://xdvdxbjdtkzmyoqrgdmm.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhkdmR4YmpkdGt6bXlvcXJnZG1tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU1MTc1MjcsImV4cCI6MjA4MTA5MzUyN30.h8YfLhg-X4wapnUljK3DsrRiOQc6CqDrdQ3C3uXTlx0"
    
    private let kBlockedStationsKey = "blocked_station_uuids"
    private let kBlockedStationNamesKey = "blocked_station_names"
    
    // Local Blocklist (User Actions)
    @Published private(set) var localBlockedUUIDs: Set<String> = []
    @Published private(set) var blockedStationNames: [String: String] = [:] // UUID -> Name
    
    // Online Blocklist (Remote Config)
    @Published private(set) var onlineBlockedUUIDs: Set<String> = []
    @Published private(set) var onlineBlockedKeywords: [String] = [
        "CCTV", "CGTN", "卫视", "凤凰卫视", "VOA", "RFA", "伴音", "新闻联播", "国际新闻"
    ]
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadLocalBlockedStations()
        fetchOnlineBlacklist()
    }
    
    // MARK: - API
    
    /// Check if a station is blocked by any rule (Local UUID, Online UUID, Online Keyword)
    func isBlocked(_ station: Station) -> Bool {
        // 1. UUID Check
        if localBlockedUUIDs.contains(station.stationuuid) { return true }
        if onlineBlockedUUIDs.contains(station.stationuuid) { return true }
        
        // 2. Keyword Check
        if !onlineBlockedKeywords.isEmpty {
            let name = station.name.uppercased()
            let tags = station.tags.uppercased()
            for keyword in onlineBlockedKeywords {
                if name.contains(keyword) || tags.contains(keyword) {
                    return true
                }
            }
        }
        
        return false
    }
    
    // Only exposes raw/local UUIDs for the UI list
    var blockedUUIDs: Set<String> {
        return localBlockedUUIDs
    }
    
    func block(station: Station) {
        localBlockedUUIDs.insert(station.stationuuid)
        blockedStationNames[station.stationuuid] = station.name
        saveLocal()
        objectWillChange.send()
    }
    
    // Backward compatibility or direct UUID block
    func block(stationUUID: String) {
        localBlockedUUIDs.insert(stationUUID)
        // If we don't have the station object, we can't save the name, so it remains unknown or nil
        saveLocal()
        objectWillChange.send()
    }
    
    func unblock(stationUUID: String) {
        localBlockedUUIDs.remove(stationUUID)
        blockedStationNames.removeValue(forKey: stationUUID)
        saveLocal()
        objectWillChange.send()
    }
    
    // MARK: - Internal
    
    private func loadLocalBlockedStations() {
        if let saved = UserDefaults.standard.array(forKey: kBlockedStationsKey) as? [String] {
            self.localBlockedUUIDs = Set(saved)
        }
        if let savedNames = UserDefaults.standard.dictionary(forKey: kBlockedStationNamesKey) as? [String: String] {
            self.blockedStationNames = savedNames
        }
    }
    
    private func saveLocal() {
        UserDefaults.standard.set(Array(localBlockedUUIDs), forKey: kBlockedStationsKey)
        UserDefaults.standard.set(blockedStationNames, forKey: kBlockedStationNamesKey)
    }
    
    private func fetchOnlineBlacklist() {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/shiyin_blacklist?select=type,value,is_active&is_active=eq.true") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map { $0.data }
            .decode(type: [OnlineBlacklistItem].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error fetching online blacklist: \(error)")
                }
            }, receiveValue: { [weak self] items in
                self?.processOnlineItems(items)
            })
            .store(in: &cancellables)
    }
    
    private func processOnlineItems(_ items: [OnlineBlacklistItem]) {
        var uuids = Set<String>()
        var keywords = [String]()
        
        for item in items {
            // Trim whitespace
            let val = item.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !val.isEmpty else { continue }
            
            if item.type == "uuid" {
                uuids.insert(val)
            } else if item.type == "keyword" {
                keywords.append(val.uppercased())
            }
        }
        
        self.onlineBlockedUUIDs = uuids
        self.onlineBlockedKeywords = keywords
        
        // Notify UI/Service that rules have changed
        self.objectWillChange.send()
        
        print("Online Blacklist Updated: \(uuids.count) UUIDs, \(keywords.count) Keywords")
    }
    
    // MARK: - Fetch Missing Names
    
    /// 获取缺失名称的已屏蔽电台信息
    func fetchMissingStationNames() {
        print("[BlockManager] fetchMissingStationNames called")
        print("[BlockManager] localBlockedUUIDs: \(localBlockedUUIDs)")
        print("[BlockManager] blockedStationNames: \(blockedStationNames)")
        
        let missingUUIDs = localBlockedUUIDs.filter { blockedStationNames[$0] == nil || blockedStationNames[$0]?.isEmpty == true }
        print("[BlockManager] missingUUIDs: \(missingUUIDs)")
        guard !missingUUIDs.isEmpty else {
            print("[BlockManager] No missing UUIDs, all names present")
            return
        }
        
        let baseURL = "https://de1.api.radio-browser.info/json"
        
        for uuid in missingUUIDs {
            let urlStr = "\(baseURL)/stations/byuuid/\(uuid)"
            print("[BlockManager] Fetching name for UUID: \(uuid), URL: \(urlStr)")
            guard let url = URL(string: urlStr) else { continue }
            
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                if let error = error {
                    print("[BlockManager] Error fetching \(uuid): \(error)")
                    return
                }
                guard let data = data else {
                    print("[BlockManager] No data for \(uuid)")
                    return
                }
                
                print("[BlockManager] Response for \(uuid): \(String(data: data, encoding: .utf8)?.prefix(200) ?? "nil")")
                
                if let stations = try? JSONDecoder().decode([Station].self, from: data),
                   let station = stations.first, !station.name.isEmpty {
                    print("[BlockManager] Got name for \(uuid): \(station.name)")
                    DispatchQueue.main.async {
                        self?.blockedStationNames[uuid] = station.name
                        self?.saveLocal()
                        self?.objectWillChange.send()
                    }
                } else {
                    print("[BlockManager] Failed to decode station for \(uuid)")
                }
            }.resume()
        }
    }
    
    // MARK: - Reporting
    
    struct StationReport: Encodable {
        let station_uuid: String
        let station_name: String
        let station_url: String
        let reason: String
    }
    
    func reportStation(station: Station, reason: String) {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/shiyin_station_reports") else { return }
        
        let report = StationReport(
            station_uuid: station.stationuuid,
            station_name: station.name,
            station_url: station.url,
            reason: reason
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        do {
            request.httpBody = try JSONEncoder().encode(report)
        } catch {
            print("Error encoding report: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error reporting station: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                print("Station reported successfully")
            } else {
                print("Failed to report station: \(String(describing: response))")
            }
        }.resume()
    }
}
