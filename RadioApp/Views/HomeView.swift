import SwiftUI
import Combine

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject var playerManager = AudioPlayerManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(gradient: Gradient(colors: [Color.black, Color.blue.opacity(0.3)]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("精选电台")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            NavigationLink(destination: SearchView()) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)
                        
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
