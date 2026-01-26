import SwiftUI
import Combine

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
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
                    }
                }
                .padding()
                .background(Color.white.opacity(0.15))
                .cornerRadius(12)
                .padding(.horizontal)
                
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
                                    Text(station.tags)
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                        .lineLimit(1)
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

class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var stations: [Station] = []
    @Published var isLoading: Bool = false
    
    func search() {
        guard !query.isEmpty else { return }
        isLoading = true
        Task {
            do {
                let results = try await RadioService.shared.searchStations(name: query)
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
