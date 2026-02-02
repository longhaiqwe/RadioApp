import SwiftUI
import Combine
import UniformTypeIdentifiers

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var favoritesManager = FavoritesManager.shared
    @State private var draggingStation: Station?
    @State private var showFeedback = false
    
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        NavigationView {
            ZStack {
                // 动态霓虹背景
                AnimatedMeshBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - 顶部标题
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("发现")
                                    .font(.system(size: 42, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.white, .white.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                Spacer()
                                
                                // 反馈入口
                                Button(action: { showFeedback = true }) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(NeonColors.cyan)
                                        .padding(10)
                                        .background(
                                            Circle()
                                                .fill(.white.opacity(0.1))
                                        )
                                }
                            }
                            
                            Text("探索全球电台")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(NeonColors.cyan.opacity(0.8))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                        
                        // MARK: - 搜索入口
                        NavigationLink(destination: SearchView()) {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(NeonColors.cyan)
                                
                                Text("搜索电台、风格、地区...")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Spacer()
                                
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(NeonColors.purple.opacity(0.6))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                GlassmorphicBackground(cornerRadius: 16, glowColor: NeonColors.cyan.opacity(0.5))
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // MARK: - 收藏区域
                        if !favoritesManager.favoriteStations.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(NeonColors.magenta)
                                    Text("我的收藏")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("\(favoritesManager.favoriteStations.count)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(NeonColors.cyan)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(NeonColors.cyan.opacity(0.15))
                                        )
                                }
                                .padding(.horizontal, 20)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(favoritesManager.favoriteStations) { station in
                                            NeonStationCard(
                                                station: station,
                                                isPlaying: playerManager.currentStation?.id == station.id && playerManager.isPlaying
                                            )
                                            .onTapGesture {
                                                playerManager.play(station: station, in: favoritesManager.favoriteStations, title: "我的收藏")
                                            }
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    favoritesManager.removeFavorite(station)
                                                } label: {
                                                    Label("取消收藏", systemImage: "heart.slash")
                                                }
                                            }
                                            // 拖拽支持
                                            .onDrag {
                                                self.draggingStation = station
                                                return NSItemProvider(object: station.id as NSString)
                                            }
                                            .onDrop(of: [.text], delegate: StationDropDelegate(item: station, items: $favoritesManager.favoriteStations, favoritesManager: favoritesManager, draggingItem: $draggingStation))
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        // MARK: - 分割线
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, NeonColors.purple.opacity(0.3), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                        
                        // MARK: - 热门推荐
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(NeonColors.gold)
                                Text("热门推荐")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.stations) { station in
                                        NeonStationCard(
                                            station: station,
                                            isPlaying: playerManager.currentStation?.id == station.id && playerManager.isPlaying
                                        )
                                        .onTapGesture {
                                            playerManager.play(station: station, in: viewModel.stations, title: "热门推荐")
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // 底部留白给 Mini Player
                        Color.clear.frame(height: 100)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if viewModel.stations.isEmpty {
                viewModel.fetchStations()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active && viewModel.stations.isEmpty {
                print("App active, retrying fetch stations...")
                viewModel.fetchStations()
            }
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
        }
    }
}

class HomeViewModel: ObservableObject {
    @Published var stations: [Station] = []
    
    func fetchStations() {
        Task {
            do {
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

// MARK: - 霓虹风格电台卡片
struct NeonStationCard: View {
    let station: Station
    var isPlaying: Bool = false
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 封面
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(NeonColors.cardBg)
                    .frame(width: 150, height: 150)
                    .overlay(
                             StationAvatarView(urlString: station.favicon, placeholderName: station.name, placeholderId: station.stationuuid)
                     )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isPlaying ? NeonColors.cyan.opacity(0.8) : Color.white.opacity(0.1),
                                lineWidth: isPlaying ? 2 : 1
                            )
                    )
                    .shadow(color: isPlaying ? NeonColors.cyan.opacity(0.4) : .black.opacity(0.3), radius: isPlaying ? 15 : 8, x: 0, y: 5)
                
                // 正在播放指示器
                if isPlaying {
                    ZStack {
                        Circle()
                            .fill(NeonColors.darkBg.opacity(0.8))
                            .frame(width: 32, height: 32)
                        
                        PulsingView(color: NeonColors.cyan)
                    }
                    .offset(x: -8, y: 8)
                }
            }
            
            // 电台信息
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(station.tags.isEmpty ? "电台" : station.tags)
                    .font(.system(size: 12))
                    .foregroundColor(NeonColors.cyan.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

// 保留旧的 StationCard 以兼容其他地方可能的引用
struct StationCard: View {
    let station: Station
    
    var body: some View {
        NeonStationCard(station: station)
    }
}

struct StationDropDelegate: DropDelegate {
    let item: Station
    @Binding var items: [Station]
    var favoritesManager: FavoritesManager
    @Binding var draggingItem: Station?
    
    func performDrop(info: DropInfo) -> Bool {
        self.draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem else { return }
        
        guard let fromIndex = items.firstIndex(of: draggingItem) else { return }
        guard let toIndex = items.firstIndex(of: item) else { return }
        
        if fromIndex != toIndex {
            withAnimation {
                favoritesManager.moveFavorite(from: IndexSet(integer: fromIndex), to: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }
}
