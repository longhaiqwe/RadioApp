import SwiftUI
import Combine

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            // 霓虹背景
            AnimatedMeshBackground()
            
            VStack(spacing: 0) {
                // MARK: - 顶部栏
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial.opacity(0.3))
                            )
                    }
                    
                    Spacer()
                    
                    Text("搜索")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                // MARK: - 搜索框
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(NeonColors.cyan)
                    
                    TextField("输入电台名称...", text: $viewModel.query)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .focused($isFocused)
                        .onSubmit {
                            viewModel.search()
                        }
                        .submitLabel(.search)
                    
                    if !viewModel.query.isEmpty {
                        Button(action: {
                            viewModel.query = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        Button(action: {
                            viewModel.search()
                            isFocused = false
                        }) {
                            Text("搜索")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [NeonColors.magenta, NeonColors.purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .shadow(color: NeonColors.magenta.opacity(0.4), radius: 8)
                        }
                    }
                    
                    // 筛选菜单
                    Menu {
                        Picker("选择省份", selection: $viewModel.selectedProvince) {
                            Text("全部地区").tag(String?.none)
                            ForEach(viewModel.provinces, id: \.code) { province in
                                Text(province.name).tag(String?.some(province.code))
                            }
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18))
                            .foregroundColor(viewModel.selectedProvince == nil ? .white.opacity(0.5) : NeonColors.cyan)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(viewModel.selectedProvince == nil ? 
                                          Color.white.opacity(0.1) : 
                                          NeonColors.cyan.opacity(0.2))
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    GlassmorphicBackground(cornerRadius: 16, glowColor: isFocused ? NeonColors.cyan : NeonColors.cyan.opacity(0.3))
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                // MARK: - 省份标签（如果选中）
                if let provinceCode = viewModel.selectedProvince,
                   let province = viewModel.provinces.first(where: { $0.code == provinceCode }) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(NeonColors.cyan)
                            
                            Text(province.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            Button(action: {
                                viewModel.selectedProvince = nil
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(NeonColors.cyan.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(NeonColors.cyan.opacity(0.3), lineWidth: 1)
                                )
                        )
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                
                // MARK: - 加载指示器
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .tint(NeonColors.cyan)
                        Text("搜索中...")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 20)
                }
                
                // MARK: - 搜索结果
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.stations) { station in
                            SearchResultRow(
                                station: station,
                                isPlaying: playerManager.currentStation?.id == station.id && playerManager.isPlaying
                            )
                            .onTapGesture {
                                playerManager.play(station: station)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - 搜索结果行
struct SearchResultRow: View {
    let station: Station
    var isPlaying: Bool = false
    
    var body: some View {
        HStack(spacing: 14) {
            // 封面
            ZStack(alignment: .bottomTrailing) {
                if let url = URL(string: station.favicon), !station.favicon.isEmpty {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            PlaceholderView(name: station.name, id: station.stationuuid)
                        } else {
                            ZStack {
                                NeonColors.cardBg
                                ProgressView()
                                    .tint(NeonColors.cyan)
                            }
                        }
                    }
                } else {
                    PlaceholderView(name: station.name, id: station.stationuuid)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPlaying ? NeonColors.cyan.opacity(0.8) : .clear, lineWidth: 2)
            )
            .shadow(color: isPlaying ? NeonColors.cyan.opacity(0.4) : .clear, radius: 8)
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(station.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if isPlaying {
                        PulsingView(color: NeonColors.cyan)
                    }
                }
                
                HStack(spacing: 8) {
                    if !station.state.isEmpty {
                        Text(station.state)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(NeonColors.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(NeonColors.cyan.opacity(0.15))
                            )
                    }
                    
                    Text(station.tags.isEmpty ? "电台" : station.tags)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 播放按钮
            Image(systemName: isPlaying ? "speaker.wave.2.fill" : "play.fill")
                .font(.system(size: 16))
                .foregroundColor(isPlaying ? NeonColors.cyan : .white.opacity(0.4))
        }
        .padding(12)
        .background(
            GlassmorphicBackground(
                cornerRadius: 16,
                glowColor: isPlaying ? NeonColors.cyan.opacity(0.5) : .clear,
                showBorder: isPlaying
            )
        )
    }
}

// MARK: - 数据模型
struct Province: Identifiable {
    let id = UUID()
    let name: String
    let code: String
}

class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var stations: [Station] = []
    @Published var isLoading: Bool = false
    @Published var selectedProvince: String? = nil {
        didSet {
            search()
        }
    }
    
    let provinces: [Province] = [
        Province(name: "北京市", code: "Beijing"),
        Province(name: "上海市", code: "Shanghai"),
        Province(name: "天津市", code: "Tianjin"),
        Province(name: "重庆市", code: "Chongqing"),
        Province(name: "湖南省", code: "Hunan"),
        Province(name: "广东省", code: "Guangdong"),
        Province(name: "湖北省", code: "Hubei"),
        Province(name: "江苏省", code: "Jiangsu"),
        Province(name: "浙江省", code: "Zhejiang"),
        Province(name: "四川省", code: "Sichuan"),
        Province(name: "山东省", code: "Shandong"),
        Province(name: "河南省", code: "Henan"),
        Province(name: "河北省", code: "Hebei"),
        Province(name: "辽宁省", code: "Liaoning"),
        Province(name: "陕西省", code: "Shaanxi"),
        Province(name: "福建省", code: "Fujian"),
        Province(name: "江西省", code: "Jiangxi"),
        Province(name: "黑龙江省", code: "Heilongjiang"),
        Province(name: "吉林省", code: "Jilin"),
        Province(name: "安徽省", code: "Anhui"),
        Province(name: "山西省", code: "Shanxi"),
        Province(name: "云南省", code: "Yunnan"),
        Province(name: "广西壮族自治区", code: "Guangxi"),
        Province(name: "贵州省", code: "Guizhou"),
        Province(name: "海南省", code: "Hainan"),
        Province(name: "甘肃省", code: "Gansu"),
        Province(name: "青海省", code: "Qinghai"),
        Province(name: "内蒙古自治区", code: "Inner Mongolia"),
        Province(name: "宁夏回族自治区", code: "Ningxia"),
        Province(name: "新疆维吾尔自治区", code: "Xinjiang"),
        Province(name: "西藏自治区", code: "Tibet"),
        Province(name: "香港", code: "Hong Kong"),
        Province(name: "澳门", code: "Macau"),
        Province(name: "台湾", code: "Taiwan")
    ]
    
    func search() {
        guard !query.isEmpty || selectedProvince != nil else { return }
        
        isLoading = true
        Task {
            do {
                let results: [Station]
                
                if let province = selectedProvince {
                    var filter = StationFilter()
                    filter.name = query.isEmpty ? nil : query
                    filter.state = province
                    filter.countryCode = "CN"
                    filter.limit = 100
                    filter.order = "clickcount"
                    filter.reverse = true
                    
                    results = try await RadioService.shared.advancedSearch(filter: filter)
                } else {
                    results = try await RadioService.shared.searchStations(name: query)
                }
                
                DispatchQueue.main.async {
                    self.stations = results
                    self.isLoading = false
                }
            } catch {
                print("Search error: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}
