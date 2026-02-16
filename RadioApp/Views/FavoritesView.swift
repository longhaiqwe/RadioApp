import SwiftUI

struct FavoritesView: View {
    @ObservedObject var favoritesManager = FavoritesManager.shared
    @ObservedObject var stationBlockManager = StationBlockManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @State private var searchText = ""
    
    var filteredStations: [Station] {
        let all = favoritesManager.favoriteStations.filter { !stationBlockManager.isBlocked($0) }
        if searchText.isEmpty {
            return all
        } else {
            return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            AnimatedMeshBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("我的收藏")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    if filteredStations.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "heart.slash")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.3))
                            Text("还没有收藏电台")
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(filteredStations) { station in
                                NeonStationCard(
                                    station: station,
                                    isPlaying: playerManager.currentStation?.id == station.id && playerManager.isPlaying
                                )
                                .onTapGesture {
                                    playerManager.play(station: station, in: filteredStations, title: "我的收藏")
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        favoritesManager.removeFavorite(station)
                                    } label: {
                                        Label("取消收藏", systemImage: "heart.slash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100) // Space for mini player
            }
        }
        .searchable(text: $searchText, prompt: "搜索收藏")
    }
}
