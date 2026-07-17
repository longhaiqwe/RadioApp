import Foundation
import Combine
import SwiftUI

struct FavoriteGroup: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    let createdAt: Date

    init(id: String = UUID().uuidString, name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

struct FavoriteGroupLibrary: Codable, Equatable {
    var groups: [FavoriteGroup] = []
    var stationGroupIDs: [String: String] = [:]

    mutating func createGroup(named rawName: String) -> FavoriteGroup? {
        let name = normalizedName(rawName)
        guard !name.isEmpty else { return nil }

        if let existingGroup = groups.first(where: { namesMatch($0.name, name) }) {
            return existingGroup
        }

        let group = FavoriteGroup(name: name)
        groups.append(group)
        return group
    }

    mutating func renameGroup(id: String, to rawName: String) -> Bool {
        let name = normalizedName(rawName)
        guard !name.isEmpty else { return false }
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return false }
        guard !groups.contains(where: { $0.id != id && namesMatch($0.name, name) }) else { return false }

        groups[index].name = name
        return true
    }

    mutating func deleteGroup(id: String) {
        groups.removeAll { $0.id == id }
        stationGroupIDs = stationGroupIDs.filter { $0.value != id }
    }

    @discardableResult
    mutating func assignStation(_ stationKey: String, to groupID: String?) -> Bool {
        guard !stationKey.isEmpty else { return false }

        guard let groupID else {
            stationGroupIDs.removeValue(forKey: stationKey)
            return true
        }

        guard groups.contains(where: { $0.id == groupID }) else { return false }
        stationGroupIDs[stationKey] = groupID
        return true
    }

    func groupID(forStationKey stationKey: String) -> String? {
        guard let groupID = stationGroupIDs[stationKey],
              groups.contains(where: { $0.id == groupID }) else {
            return nil
        }
        return groupID
    }

    mutating func removeStation(_ stationKey: String) {
        stationGroupIDs.removeValue(forKey: stationKey)
    }

    mutating func keepAssignments(onlyFor stationKeys: Set<String>) {
        stationGroupIDs = stationGroupIDs.filter { stationKeys.contains($0.key) }
    }

    private func normalizedName(_ rawName: String) -> String {
        rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
}

struct FavoriteStationOrdering {
    static func reorderedStations(
        _ allStations: [Station],
        moving movingStation: Station,
        over targetStation: Station,
        visibleStations: [Station]
    ) -> [Station] {
        guard movingStation.id != targetStation.id else { return allStations }

        let allStationIDs = Set(allStations.map(\.id))
        var visibleStations = visibleStations.filter { allStationIDs.contains($0.id) }

        guard let fromIndex = visibleStations.firstIndex(where: { $0.id == movingStation.id }),
              let toIndex = visibleStations.firstIndex(where: { $0.id == targetStation.id }),
              fromIndex != toIndex else {
            return allStations
        }

        visibleStations.move(
            fromOffsets: IndexSet(integer: fromIndex),
            toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
        )

        let visibleStationIDs = Set(visibleStations.map(\.id))
        var reorderedVisibleStations = visibleStations.makeIterator()

        return allStations.map { station in
            guard visibleStationIDs.contains(station.id),
                  let reorderedStation = reorderedVisibleStations.next() else {
                return station
            }
            return reorderedStation
        }
    }
}

class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()

    @Published var favoriteStations: [Station] = []
    @Published private(set) var favoriteGroups: [FavoriteGroup] = []
    @Published private(set) var favoriteGroupAssignments: [String: String] = [:]
    private let favoritesKey = "favorite_stations"
    private let favoriteGroupsKey = "favorite_groups_v1"
    private var groupLibrary = FavoriteGroupLibrary()

    private init() {
        loadFavorites()
        loadFavoriteGroups()
    }

    func isFavorite(_ station: Station) -> Bool {
        return favoriteStations.contains { savedStation in
            stationsMatch(savedStation, station)
        }
    }

    func toggleFavorite(_ station: Station) {
        if isFavorite(station) {
            removeFavorite(station)
        } else {
            addFavorite(station)
        }
    }

    func addFavorite(_ station: Station, groupID: String? = nil) {
        if !isFavorite(station) {
            favoriteStations.insert(station, at: 0) // Add to top
            saveFavorites()
        }

        if let groupID {
            assignFavorite(station, toGroupID: groupID)
        }
    }

    func removeFavorite(_ station: Station) {
        let removedKeys = favoriteStations
            .filter { stationsMatch($0, station) }
            .map(stationKey)

        favoriteStations.removeAll { savedStation in
            stationsMatch(savedStation, station)
        }
        removeFavoriteGroupAssignments(for: removedKeys)
        saveFavorites()
    }

    func moveFavorite(from source: IndexSet, to destination: Int) {
        favoriteStations.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
    }

    func moveFavorite(_ movingStation: Station, over targetStation: Station, visibleStations: [Station]) {
        let reorderedStations = FavoriteStationOrdering.reorderedStations(
            favoriteStations,
            moving: movingStation,
            over: targetStation,
            visibleStations: visibleStations
        )

        guard reorderedStations != favoriteStations else { return }

        favoriteStations = reorderedStations
        saveFavorites()
    }

    @discardableResult
    func createFavoriteGroup(named name: String) -> FavoriteGroup? {
        var library = groupLibrary
        guard let group = library.createGroup(named: name) else { return nil }
        updateFavoriteGroups(with: library)
        saveFavoriteGroups()
        return group
    }

    @discardableResult
    func renameFavoriteGroup(id: String, to name: String) -> Bool {
        var library = groupLibrary
        guard library.renameGroup(id: id, to: name) else { return false }
        updateFavoriteGroups(with: library)
        saveFavoriteGroups()
        return true
    }

    func deleteFavoriteGroup(id: String) {
        var library = groupLibrary
        library.deleteGroup(id: id)
        updateFavoriteGroups(with: library)
        saveFavoriteGroups()
    }

    func assignFavorite(_ station: Station, toGroupID groupID: String?) {
        if !isFavorite(station) {
            addFavorite(station)
        }

        guard let key = favoriteKey(for: station) else { return }
        var library = groupLibrary
        guard library.assignStation(key, to: groupID) else { return }
        updateFavoriteGroups(with: library)
        saveFavoriteGroups()
    }

    func groupID(for station: Station) -> String? {
        guard let key = favoriteKey(for: station) else { return nil }
        return groupLibrary.groupID(forStationKey: key)
    }

    func favoriteStations(inGroupID selectedGroupID: String?) -> [Station] {
        favoriteStations.filter { groupID(for: $0) == selectedGroupID }
    }

    func favoriteCount(inGroupID selectedGroupID: String?) -> Int {
        favoriteStations(inGroupID: selectedGroupID).count
    }

    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favoriteStations)
            UserDefaults.standard.set(data, forKey: favoritesKey)
        } catch {
            print("Failed to save favorites: \(error)")
        }
    }

    private func saveFavoriteGroups() {
        do {
            let data = try JSONEncoder().encode(groupLibrary)
            UserDefaults.standard.set(data, forKey: favoriteGroupsKey)
        } catch {
            print("Failed to save favorite groups: \(error)")
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

    private func loadFavoriteGroups() {
        guard let data = UserDefaults.standard.data(forKey: favoriteGroupsKey) else {
            updateFavoriteGroups(with: FavoriteGroupLibrary())
            return
        }

        do {
            let library = try JSONDecoder().decode(FavoriteGroupLibrary.self, from: data)
            updateFavoriteGroups(with: library)
            pruneFavoriteGroupAssignments()
        } catch {
            print("Failed to load favorite groups: \(error)")
            updateFavoriteGroups(with: FavoriteGroupLibrary())
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
        pruneFavoriteGroupAssignments()
        // Only save if count changed to avoid unnecessary writes
        if existing.count != uniqueStations.count
            || uniqueStations.contains(where: { $0.stationuuid == "24711f7f-8ff5-4141-8e0f-ab17f3da1b89" && $0.favicon == "bundle://huaiji_cover" && existing.first(where: { $0.stationuuid == "24711f7f-8ff5-4141-8e0f-ab17f3da1b89" })?.favicon != "bundle://huaiji_cover" })
            || uniqueStations.contains(where: { $0.stationuuid == "94de57d1-542a-46b8-8e18-d97517d93f99" && $0.favicon == "bundle://morning_music_cover" && existing.first(where: { $0.stationuuid == "94de57d1-542a-46b8-8e18-d97517d93f99" })?.favicon != "bundle://morning_music_cover" }) {
            saveFavorites()
        }
    }

    private func updateFavoriteGroups(with library: FavoriteGroupLibrary) {
        groupLibrary = library
        favoriteGroups = library.groups
        favoriteGroupAssignments = library.stationGroupIDs
    }

    private func removeFavoriteGroupAssignments(for stationKeys: [String]) {
        guard !stationKeys.isEmpty else { return }

        var library = groupLibrary
        for key in stationKeys {
            library.removeStation(key)
        }

        if library != groupLibrary {
            updateFavoriteGroups(with: library)
            saveFavoriteGroups()
        }
    }

    private func pruneFavoriteGroupAssignments() {
        let validKeys = Set(favoriteStations.map(stationKey))
        var library = groupLibrary
        library.keepAssignments(onlyFor: validKeys)

        if library != groupLibrary {
            updateFavoriteGroups(with: library)
            saveFavoriteGroups()
        }
    }

    private func favoriteKey(for station: Station) -> String? {
        guard let favoriteStation = favoriteStations.first(where: { stationsMatch($0, station) }) else {
            return nil
        }
        return stationKey(for: favoriteStation)
    }

    private func stationKey(for station: Station) -> String {
        station.id
    }

    private func stationsMatch(_ lhs: Station, _ rhs: Station) -> Bool {
        if lhs.id == rhs.id { return true }
        if !lhs.urlResolved.isEmpty && lhs.urlResolved == rhs.urlResolved {
            return true
        }
        return false
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
