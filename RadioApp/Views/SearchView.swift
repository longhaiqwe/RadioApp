import SwiftUI
import Combine

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    Text("搜索")
                        .foregroundColor(.white)
                        .font(.headline)
                    Spacer()
                    // Spacer to balance back button
                    Image(systemName: "chevron.left")
                        .foregroundColor(.clear)
                        .padding()
                }
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("输入电台名称...", text: $viewModel.query)
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
                                .foregroundColor(.gray)
                        }
                        
                        // Explicit Search Button
                        Button(action: {
                            viewModel.search()
                            isFocused = false // Dismiss keyboard on search
                        }) {
                            Text("搜索")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    
                    // Filter Menu
                    Menu {
                        Picker("选择省份", selection: $viewModel.selectedProvince) {
                            Text("全部地区").tag(String?.none)
                            ForEach(viewModel.provinces, id: \.code) { province in
                                Text(province.name).tag(String?.some(province.code))
                            }
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                             .font(.system(size: 20))
                            .foregroundColor(viewModel.selectedProvince == nil ? .gray : .white)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.15))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 10) // Add some spacing below search bar
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding()
                }
                
                List {
                    ForEach(viewModel.stations) { station in
                        Button(action: {
                            playerManager.play(station: station)
                        }) {
                            HStack {
                                if let url = URL(string: station.favicon), !station.favicon.isEmpty {
                                    AsyncImage(url: url) { image in
                                        image.resizable()
                                    } placeholder: {
                                        Color.gray
                                    }
                                    .frame(width: 44, height: 44)
                                    .cornerRadius(8)
                                } else {
                                    Image(systemName: "radio.fill")
                                        .resizable()
                                        .padding(8)
                                        .frame(width: 44, height: 44)
                                        .background(Color.gray.opacity(0.3))
                                        .cornerRadius(8)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(station.name)
                                        .foregroundColor(.white)
                                        .font(.headline)
                                        .lineLimit(1)
                                    HStack {
                                        if !station.state.isEmpty {
                                            Text(station.state)
                                                .font(.caption2)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.3))
                                                .cornerRadius(4)
                                        }
                                        Text(station.tags)
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Color.white.opacity(0.2))
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationBarHidden(true)
    }
}

struct Province: Identifiable {
    let id = UUID()
    let name: String // Chinese name
    let code: String // English state name in API
}

class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var stations: [Station] = []
    @Published var isLoading: Bool = false
    @Published var selectedProvince: String? = nil {
        didSet {
            // Auto search when filter changes
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
        // If filter is active, we validly allow empty query (to show all stations in province)
        // If filter is inactive, we need a query
        guard !query.isEmpty || selectedProvince != nil else { return }
        
        isLoading = true
        Task {
            do {
                let results: [Station]
                
                if let province = selectedProvince {
                    // Use Advanced Search
                    var filter = StationFilter()
                    filter.name = query.isEmpty ? nil : query
                    filter.state = province
                    filter.countryCode = "CN" // Restrict to China to be safe
                    filter.limit = 100 // Higher limit for state browsing
                    filter.order = "clickcount"
                    filter.reverse = true
                    
                    results = try await RadioService.shared.advancedSearch(filter: filter)
                } else {
                    // Use Smart Search (Simple Name)
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
