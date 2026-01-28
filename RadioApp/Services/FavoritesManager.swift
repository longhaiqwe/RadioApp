import Foundation
import Combine
import SwiftUI

class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published var favoriteStations: [Station] = []
    private let favoritesKey = "favorite_stations"
    
    private init() {
        loadFavorites()
    }
    
    func isFavorite(_ station: Station) -> Bool {
        return favoriteStations.contains { savedStation in
            if savedStation.id == station.id { return true }
            // Fallback: Check if streaming URL is identical (handles duplicates with different UUIDs)
            if !savedStation.urlResolved.isEmpty && savedStation.urlResolved == station.urlResolved {
                return true
            }
            return false
        }
    }
    
    func toggleFavorite(_ station: Station) {
        if isFavorite(station) {
            removeFavorite(station)
        } else {
            addFavorite(station)
        }
    }
    
    func addFavorite(_ station: Station) {
        if !isFavorite(station) {
            favoriteStations.insert(station, at: 0) // Add to top
            saveFavorites()
        }
    }
    
    func removeFavorite(_ station: Station) {
        favoriteStations.removeAll { savedStation in
            if savedStation.id == station.id { return true }
            if !savedStation.urlResolved.isEmpty && savedStation.urlResolved == station.urlResolved {
                return true
            }
            return false
        }
        saveFavorites()
    }
    
    func moveFavorite(from source: IndexSet, to destination: Int) {
        favoriteStations.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
    }
    
    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favoriteStations)
            UserDefaults.standard.set(data, forKey: favoritesKey)
        } catch {
            print("Failed to save favorites: \(error)")
        }
    }
    
    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey) else {
            // No data found, load defaults
            self.favoriteStations = createDefaultStations()
            saveFavorites()
            return
        }
        do {
            let stations = try JSONDecoder().decode([Station].self, from: data)
            if stations.isEmpty {
                self.favoriteStations = createDefaultStations()
                saveFavorites()
            } else {
                self.favoriteStations = stations
            }
        } catch {
            print("Failed to load favorites: \(error)")
        }
    }

    private func createDefaultStations() -> [Station] {
        return [
            Station(
                changeuuid: UUID().uuidString,
                stationuuid: "a09db942-832d-4932-8c05-494e17dc37e0",
                name: "CNR-3 音乐之声",
                url: "https://ngcdn001.cnr.cn/live/yyzs/index.m3u8",
                urlResolved: "https://ngcdn001.cnr.cn/live/yyzs/index.m3u8",
                homepage: "http://www.cnr.cn/",
                favicon: "",
                tags: "pop,news,china",
                country: "China",
                countrycode: "CN",
                state: "",
                language: "Chinese",
                languagecodes: "zh",
                votes: 0,
                lastchangetime: "",
                codec: "MP3",
                bitrate: 128,
                hls: 1,
                lastcheckok: 1,
                lastchecktime: "",
                lastcheckoktime: "",
                lastlocalchecktime: "",
                clicktimestamp: "",
                clickcount: 0,
                clicktrend: 0
            ),
            Station(
                changeuuid: UUID().uuidString,
                stationuuid: "24711f7f-8ff5-4141-8e0f-ab17f3da1b89",
                name: "怀集音乐之声",
                url: "https://lhttp.qingting.fm/live/4804/64k.mp3",
                urlResolved: "https://lhttp.qingting.fm/live/4804/64k.mp3",
                homepage: "",
                favicon: "",
                tags: "local,music",
                country: "China",
                countrycode: "CN",
                state: "Guangdong",
                language: "Chinese",
                languagecodes: "zh",
                votes: 0,
                lastchangetime: "",
                codec: "MP3",
                bitrate: 64,
                hls: 0,
                lastcheckok: 1,
                lastchecktime: "",
                lastcheckoktime: "",
                lastlocalchecktime: "",
                clicktimestamp: "",
                clickcount: 0,
                clicktrend: 0
            ),
             Station(
                changeuuid: UUID().uuidString,
                stationuuid: "f3638a83-ac26-4b05-b0b9-0245b023ae0f",
                name: "AsiaFM 亚洲粤语台",
                url: "https://lhttp.qtfm.cn/live/15318569/64k.mp3",
                urlResolved: "https://lhttp.qtfm.cn/live/15318569/64k.mp3",
                homepage: "http://asiafm.hk",
                favicon: "",
                tags: "cantonese,pop",
                country: "China",
                countrycode: "CN",
                state: "",
                language: "Cantonese",
                languagecodes: "yue",
                votes: 0,
                lastchangetime: "",
                codec: "MP3",
                bitrate: 64,
                hls: 0,
                lastcheckok: 1,
                lastchecktime: "",
                lastcheckoktime: "",
                lastlocalchecktime: "",
                clicktimestamp: "",
                clickcount: 0,
                clicktrend: 0
            )
        ]
    }
}
