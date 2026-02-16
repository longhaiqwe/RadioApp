import SwiftUI

enum SidebarItem: Hashable, CaseIterable {
    case home
    case search
    case favorites
    case history
    case settings
    
    var title: String {
        switch self {
        case .home: return "发现"
        case .search: return "搜索"
        case .favorites: return "我的收藏"
        case .history: return "历史记录"
        case .settings: return "设置"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "radio"
        case .search: return "magnifyingglass"
        case .favorites: return "heart"
        case .history: return "clock"
        case .settings: return "gearshape"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    
    var body: some View {
        List(selection: $selection) {
            Section {
                NavigationLink(value: SidebarItem.home) {
                    Label(SidebarItem.home.title, systemImage: SidebarItem.home.icon)
                }
                
                NavigationLink(value: SidebarItem.search) {
                    Label(SidebarItem.search.title, systemImage: SidebarItem.search.icon)
                }
            } header: {
                Text("浏览")
            }
            
            Section {
                NavigationLink(value: SidebarItem.favorites) {
                    Label(SidebarItem.favorites.title, systemImage: SidebarItem.favorites.icon)
                }
                
                NavigationLink(value: SidebarItem.history) {
                    Label(SidebarItem.history.title, systemImage: SidebarItem.history.icon)
                }
            } header: {
                Text("我的")
            }
            
            Section {
                NavigationLink(value: SidebarItem.settings) {
                    Label(SidebarItem.settings.title, systemImage: SidebarItem.settings.icon)
                }
            } header: {
                Text("应用")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("拾音 FM")
    }
}
