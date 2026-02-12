import SwiftUI
import Combine
import UniformTypeIdentifiers

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @ObservedObject var favoritesManager = FavoritesManager.shared
    @ObservedObject var stationBlockManager = StationBlockManager.shared
    @State private var draggingStation: Station?
    @State private var showFeedback = false
    @State private var showSettings = false
    
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
                                

                                
                                // 随便听听入口 (Placed next to title)
                                Button(action: {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    
                                    // 播放随机电台
                                    Task {
                                        do {
                                            // Pass current station ID to exclude it from the random result
                                            // ensuring we always get a NEW station
                                            let currentId = playerManager.currentStation?.id
                                            if let station = try await RadioService.shared.fetchRandomStation(excluding: currentId) {
                                                await MainActor.run {
                                                    // Always play (context: itself to avoid prev/next confusion for now)
                                                    playerManager.play(station: station, in: [station], title: "随便听听")
                                                }
                                            }
                                        } catch {
                                            print("Random station fetch failed: \(error)")
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "shuffle")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("随便听听")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(NeonColors.cyan)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(NeonColors.cyan.opacity(0.15))
                                            .overlay(
                                                Capsule().stroke(NeonColors.cyan.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                                .padding(.leading, 8) // Add some spacing from title
                                
                                Spacer()
                                
                                // 设置入口
                                Button(action: { showSettings = true }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(NeonColors.cyan)
                                        .padding(10)
                                        .background(
                                            Circle()
                                                .fill(.white.opacity(0.1))
                                        )
                                }
                                .padding(.trailing, 8)
                                
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
                        let visibleFavorites = favoritesManager.favoriteStations.filter { !stationBlockManager.isBlocked($0) }
                        if !visibleFavorites.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(NeonColors.magenta)
                                    Text("我的收藏")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("\(visibleFavorites.count)")
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
                                        ForEach(visibleFavorites) { station in
                                            NeonStationCard(
                                                station: station,
                                                isPlaying: playerManager.currentStation?.id == station.id && playerManager.isPlaying
                                            )
                                            .onTapGesture {
                                                playerManager.play(station: station, in: visibleFavorites, title: "我的收藏")
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
                            
                            .padding(.horizontal, 20)
                            

                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(viewModel.stations.filter { !stationBlockManager.isBlocked($0) }) { station in
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
            // 每次出现都尝试静默更新 (L3)
            // 此时 L1/L2 数据已经在 init 中加载完成，UI 应该是有内容的
             viewModel.fetchStations()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // App 回到前台，检查更新
                viewModel.fetchStations()
            }
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

class HomeViewModel: ObservableObject {
    @Published var stations: [Station] = []
    @Published var isLoading = false
    
    private let kCachedTopStationsKey = "home_top_stations_cache"
    
    init() {
        loadInitialData()
    }
    
    // L1 -> L2 加载策略
    private func loadInitialData() {
        // 1. 尝试读取缓存 (L1)
        if let cached = loadFromCache() {
            print("Loaded \(cached.count) stations from cache")
            self.stations = cached
            return
        }
        
        // 2. 尝试读取预置数据 (L2)
        print("No cache found, loading preset data")
        if let preset = loadFromPreset() {
            print("Loaded \(preset.count) stations from preset")
            self.stations = preset
        }
    }
    
    // L3: 网络更新
    func fetchStations() {
        // 如果当前是空的（极端情况），显示 loading
        if stations.isEmpty {
            isLoading = true
        }
        
        Task {
            do {
                print("Fetching fresh data from network...")
                let fetchedStations = try await RadioService.shared.fetchTopStations()
                
                await MainActor.run {
                    // 只有当数据有变化时才更新，避免 UI 闪烁 (简单判断数量或首个ID)
                    if self.stations.map(\.id) != fetchedStations.map(\.id) {
                        self.stations = fetchedStations
                        self.saveToCache(fetchedStations)
                        print("Network update success: \(fetchedStations.count) stations")
                    } else {
                         print("Network data matches local data, skipping update")
                    }
                    self.isLoading = false
                }
            } catch {
                print("Error fetching stations: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Cache & Preset
    
    private func loadFromCache() -> [Station]? {
        guard let data = UserDefaults.standard.data(forKey: kCachedTopStationsKey) else { return nil }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([Station].self, from: data)
        } catch {
            print("Failed to decode cache: \(error)")
            return nil
        }
    }
    
    private func saveToCache(_ stations: [Station]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(stations)
            UserDefaults.standard.set(data, forKey: kCachedTopStationsKey)
        } catch {
            print("Failed to encode cache: \(error)")
        }
    }
    
    private func loadFromPreset() -> [Station]? {
        let jsonString = PresetStationData.jsonString
        guard let data = jsonString.data(using: .utf8) else { return nil }
        
        do {
            let decoder = JSONDecoder()
            // Preset data might miss some optional fields, but Station struct uses specific coding keys
            // We need to ensure the JSON matches the Struct.
            // Our generated JSON should be compatible.
            let stations = try decoder.decode([Station].self, from: data)
            return stations
        } catch {
            print("Failed to decode preset: \(error)")
            // Fallback for debugging (print first 500 chars)
            print("Preset JSON start: \(jsonString.prefix(500))")
            return nil
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
