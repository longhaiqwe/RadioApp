import Foundation

class RadioService {
    static let shared = RadioService()
    // Using a specific mirror for reliability. In production, we should discover mirrors.
    private let baseURL = "https://de1.api.radio-browser.info/json" 
    
    private init() {}
    
    func fetchTopStations(limit: Int = 20) async throws -> [Station] {
        // Defaulting to China for "Top Stations" in this localized version
        return try await fetchStationsByCountryCode("CN", limit: limit)
    }
    
    func searchStations(name: String) async throws -> [Station] {
        guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/stations/byname/\(encodedName)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("iOS-Radio-App/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let stations = try JSONDecoder().decode([Station].self, from: data)
        return stations
    }
    
    func fetchStationsByCountryCode(_ code: String, limit: Int = 20) async throws -> [Station] {
        guard let url = URL(string: "\(baseURL)/stations/bycountrycodeexact/\(code)?limit=\(limit)&order=clickcount&reverse=true") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("iOS-Radio-App/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let stations = try JSONDecoder().decode([Station].self, from: data)
        return stations
    }
}
