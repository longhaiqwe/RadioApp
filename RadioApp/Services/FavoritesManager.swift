import Foundation
import Combine

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
    
    private func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favoriteStations)
            UserDefaults.standard.set(data, forKey: favoritesKey)
        } catch {
            print("Failed to save favorites: \(error)")
        }
    }
    
    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey) else { return }
        do {
            let stations = try JSONDecoder().decode([Station].self, from: data)
            self.favoriteStations = stations
        } catch {
            print("Failed to load favorites: \(error)")
        }
    }
}
