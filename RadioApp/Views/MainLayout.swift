import SwiftUI

struct MainLayout: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    
    @State private var sidebarSelection: SidebarItem? = .home
    @State private var showPlayer = false
    @ObservedObject var playerManager = AudioPlayerManager.shared
    
    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
             ContentView()
        } else {
            SidebarLayout(selection: $sidebarSelection, showPlayer: $showPlayer)
        }
        #else
        SidebarLayout(selection: $sidebarSelection, showPlayer: $showPlayer)
        #endif
    }
}

struct SidebarLayout: View {
    @Binding var selection: SidebarItem?
    @Binding var showPlayer: Bool
    @ObservedObject var playerManager = AudioPlayerManager.shared
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            ZStack(alignment: .bottom) {
                // Background
                NeonColors.darkBg.ignoresSafeArea()
                
                // Content
                switch selection {
                case .home:
                    HomeView()
                        .navigationBarHidden(true) // Hide internal nav bar if any
                case .search:
                    SearchView(showBackButton: false)
                        .navigationBarHidden(true)
                case .favorites:
                    FavoritesView()
                case .history:
                    HistoryView(showBackButton: false)
                case .settings:
                    SettingsView(showDoneButton: false)
                case .none:
                    Text("Select an item")
                }
                
                // Mini Player
                if playerManager.currentStation != nil && !showPlayer {
                    // Reuse MiniPlayerBar from ContentView logic
                    // We need to match the logic in ContentView
                    VStack {
                        Spacer()
                        MiniPlayerBar(showPlayer: $showPlayer)
                            .padding(.bottom, 20)
                            .padding(.horizontal)
                            .frame(maxWidth: 600) // Constraint width on large screens
                    }
                }

                if showPlayer {
                    PlayerView {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showPlayer = false
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(50)
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
            .toolbar(.hidden, for: .navigationBar)
            .background(TitleBarHider()) // Inject the title bar hider
            .animation(.easeInOut(duration: 0.25), value: showPlayer)
        }
        .navigationSplitViewStyle(.balanced)
        .background(NeonColors.darkBg)
        #if targetEnvironment(macCatalyst)
        .frame(minWidth: 1000, maxWidth: .infinity, minHeight: 860, maxHeight: .infinity)
        #endif
    }
}
