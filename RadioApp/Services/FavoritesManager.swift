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
                deduplicateFavorites()
            }
        } catch {
            print("Failed to load favorites: \(error)")
        }
    }
    
    /// Deduplicates favorites by name, keeping the highest bitrate version
    private func deduplicateFavorites() {
        var seenNames = Set<String>()
        var uniqueStations: [Station] = []
        
        // 1. Sort by bitrate descending to prioritize higher quality
        // Note: We need to preserve original order as much as possible for user preference,
        // but for duplicates, we want the best quality.
        // Strategy: Group by name, find best in group, then reconstruct list preserving first appearance order?
        // Simpler for now: Just straightforward dedupe prioritizing quality.
        
        let existing = favoriteStations
        
        // Helper to find best station among those with same name
        func bestStation(for name: String) -> Station? {
            return existing.filter { $0.name == name }
                .max(by: { $0.bitrate < $1.bitrate })
        }
        
        for station in existing {
            if !seenNames.contains(station.name) {
                if let best = bestStation(for: station.name) {
                    var finalStation = best
                    // Patch: Fix missing Huaiji favicon & Use local assets for defaults
                    if finalStation.stationuuid == "24711f7f-8ff5-4141-8e0f-ab17f3da1b89" && finalStation.favicon != "bundle://huaiji_cover" {
                         finalStation = Station(
                             changeuuid: finalStation.changeuuid,
                             stationuuid: finalStation.stationuuid,
                             name: finalStation.name,
                             url: finalStation.url,
                             urlResolved: finalStation.urlResolved,
                             homepage: finalStation.homepage,
                             favicon: "bundle://huaiji_cover",
                             tags: finalStation.tags,
                             country: finalStation.country,
                             countrycode: finalStation.countrycode,
                             state: finalStation.state,
                             language: finalStation.language,
                             languagecodes: finalStation.languagecodes,
                             votes: finalStation.votes,
                             lastchangetime: finalStation.lastchangetime,
                             codec: finalStation.codec,
                             bitrate: finalStation.bitrate,
                             hls: finalStation.hls,
                             lastcheckok: finalStation.lastcheckok,
                             lastchecktime: finalStation.lastchecktime,
                             lastcheckoktime: finalStation.lastcheckoktime,
                             lastlocalchecktime: finalStation.lastlocalchecktime,
                             clicktimestamp: finalStation.clicktimestamp,
                             clickcount: finalStation.clickcount,
                             clicktrend: finalStation.clicktrend
                         )
                    } else if finalStation.stationuuid == "94de57d1-542a-46b8-8e18-d97517d93f99" && finalStation.favicon != "bundle://morning_music_cover" {
                         finalStation = Station(
                             changeuuid: finalStation.changeuuid,
                             stationuuid: finalStation.stationuuid,
                             name: "清晨音乐台",
                             url: finalStation.url,
                             urlResolved: finalStation.urlResolved,
                             homepage: finalStation.homepage,
                             favicon: "bundle://morning_music_cover",
                             tags: finalStation.tags,
                             country: finalStation.country,
                             countrycode: finalStation.countrycode,
                             state: finalStation.state,
                             language: finalStation.language,
                             languagecodes: finalStation.languagecodes,
                             votes: finalStation.votes,
                             lastchangetime: finalStation.lastchangetime,
                             codec: finalStation.codec,
                             bitrate: finalStation.bitrate,
                             hls: finalStation.hls,
                             lastcheckok: finalStation.lastcheckok,
                             lastchecktime: finalStation.lastchecktime,
                             lastcheckoktime: finalStation.lastcheckoktime,
                             lastlocalchecktime: finalStation.lastlocalchecktime,
                             clicktimestamp: finalStation.clicktimestamp,
                             clickcount: finalStation.clickcount,
                             clicktrend: finalStation.clicktrend
                         )
                    }
                    uniqueStations.append(finalStation)
                    seenNames.insert(station.name)
                }
            }
        }
        
        self.favoriteStations = uniqueStations
        // Only save if count changed to avoid unnecessary writes
        if existing.count != uniqueStations.count 
            || uniqueStations.contains(where: { $0.stationuuid == "24711f7f-8ff5-4141-8e0f-ab17f3da1b89" && $0.favicon == "bundle://huaiji_cover" && existing.first(where: { $0.stationuuid == "24711f7f-8ff5-4141-8e0f-ab17f3da1b89" })?.favicon != "bundle://huaiji_cover" })
            || uniqueStations.contains(where: { $0.stationuuid == "94de57d1-542a-46b8-8e18-d97517d93f99" && $0.favicon == "bundle://morning_music_cover" && existing.first(where: { $0.stationuuid == "94de57d1-542a-46b8-8e18-d97517d93f99" })?.favicon != "bundle://morning_music_cover" }) {
            saveFavorites()
        }
    }

    private func createDefaultStations() -> [Station] {
        return [
            Station(
                changeuuid: UUID().uuidString,
                stationuuid: "94de57d1-542a-46b8-8e18-d97517d93f99",
                name: "清晨音乐台",
                url: "http://lhttp.qingting.fm/live/4915/64k.mp3",
                urlResolved: "http://lhttp.qingting.fm/live/4915/64k.mp3",
                homepage: "https://m.weibo.cn/u/2022851417",
                favicon: "bundle://morning_music_cover",
                tags: "music,pop music",
                country: "China",
                countrycode: "CN",
                state: "Kwangsi",
                language: "chinese",
                languagecodes: "zh",
                votes: 4238,
                lastchangetime: "2026-01-15 02:35:55",
                codec: "MP3",
                bitrate: 0,
                hls: 0,
                lastcheckok: 1,
                lastchecktime: "2026-01-15 02:35:56",
                lastcheckoktime: "2026-01-15 02:35:56",
                lastlocalchecktime: "2026-01-15 02:35:56",
                clicktimestamp: "2026-02-11 09:46:34",
                clickcount: 38,
                clicktrend: 38
            ),
            Station(
                changeuuid: UUID().uuidString,
                stationuuid: "a09db942-832d-4932-8c05-494e17dc37e0",
                name: "CNR-3 音乐之声",
                url: "https://ngcdn001.cnr.cn/live/yyzs/index.m3u8",
                urlResolved: "https://ngcdn001.cnr.cn/live/yyzs/index.m3u8",
                homepage: "http://www.cnr.cn/",
                favicon: "bundle://cnr3_cover_v2",
                tags: "music",
                country: "China",
                countrycode: "CN",
                state: "",
                language: "Chinese",
                languagecodes: "zh",
                votes: 405,
                lastchangetime: "2026-01-15 06:45:25",
                codec: "UNKNOWN",
                bitrate: 0,
                hls: 1,
                lastcheckok: 1,
                lastchecktime: "2026-01-15 06:45:25",
                lastcheckoktime: "2026-01-15 06:45:25",
                lastlocalchecktime: "2026-01-15 06:45:25",
                clicktimestamp: "2026-01-30 03:06:23",
                clickcount: 16,
                clicktrend: 16
            ),
            Station(
                changeuuid: UUID().uuidString,
                stationuuid: "24711f7f-8ff5-4141-8e0f-ab17f3da1b89",
                name: "怀集音乐之声",
                url: "https://lhttp.qingting.fm/live/4804/64k.mp3",
                urlResolved: "https://lhttp.qingting.fm/live/4804/64k.mp3",
                homepage: "",
                favicon: "bundle://huaiji_cover",
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
