import SwiftUI
import Combine

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var favoritesManager = FavoritesManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(gradient: Gradient(colors: [Color.black, Color.blue.opacity(0.3)]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading) {
                        // MARK: - Search Section
                        NavigationLink(destination: SearchView()) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                Text("搜索")
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        .padding(.top, 20)
                        
                        // MARK: - Favorites Section
                        if !favoritesManager.favoriteStations.isEmpty {
                            Text("我的收藏")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal)
                                .padding(.top, 10)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 15) {
                                    ForEach(favoritesManager.favoriteStations) { station in
                                        StationCard(station: station)
                                            .onTapGesture {
                                                playerManager.play(station: station)
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.bottom, 20)
                        }
                        
                        Divider().background(Color.white.opacity(0.2)).padding(.horizontal)
                        
                        Text("热门推荐")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal)
                            .padding(.top, 10)
                            
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 15) {
                                ForEach(viewModel.stations) { station in
                                    StationCard(station: station)
                                        .onTapGesture {
                                            playerManager.play(station: station)
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Bottom padding for mini-player
                        Color.clear.frame(height: 80)
                    }
                    .padding(.top)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            viewModel.fetchStations()
        }
    }
}

class HomeViewModel: ObservableObject {
    @Published var stations: [Station] = []
    
    func fetchStations() {
        Task {
            do {
                // Fetch China Top (via modified fetchTopStations)
                let stations = try await RadioService.shared.fetchTopStations()
                DispatchQueue.main.async {
                    self.stations = stations
                }
            } catch {
                print("Error fetching stations: \(error)")
            }
        }
    }
}

struct StationCard: View {
    let station: Station
    
    var body: some View {
        VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .frame(width: 140, height: 140)
                .overlay(
                    Group {
                        if let url = URL(string: station.favicon), !station.favicon.isEmpty {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                case .failure:
                                    Image(systemName: "radio.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.white.opacity(0.5))
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: "radio.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
            
            Text(station.name)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
            
            Text(station.tags)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)
        }
    }
}
