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
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        List(selection: $selection) {
            Section {
                SidebarRow(item: .home, selection: selection)
                SidebarRow(item: .search, selection: selection)
            } header: {
                Text("浏览")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.footnote)
                    .fontWeight(.medium)
            }
            
            Section {
                SidebarRow(item: .favorites, selection: selection)
                
                NavigationLink(value: SidebarItem.history) {
                    HStack {
                        Label {
                            Text(SidebarItem.history.title)
                                .foregroundColor(selection == .history ? .white : .white.opacity(0.8))
                        } icon: {
                            Image(systemName: SidebarItem.history.icon)
                                .foregroundColor(selection == .history ? .white : NeonColors.cyan)
                        }
                        
                        if !subscriptionManager.isPro {
                            Spacer()
                            Text("PRO")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(NeonColors.gold)
                                .cornerRadius(4)
                        }
                    }
                }
                .listRowBackground(rowBackground(for: .history))
            } header: {
                Text("我的")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.footnote)
                    .fontWeight(.medium)
            }
            
            Section {
                SidebarRow(item: .settings, selection: selection)
            } header: {
                Text("应用")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.footnote)
                    .fontWeight(.medium)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(NeonColors.darkBg)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 12) {
                // Logo 图标
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [NeonColors.magenta, NeonColors.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .shadow(color: NeonColors.magenta.opacity(0.5), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "radio.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // 应用名称
                Text("拾音 FM")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: NeonColors.purple.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20) // Add top padding for visual balance
            .padding(.bottom, 12)
            .background(NeonColors.darkBg) // Ensure header is opaque
        }
    }
    
    @ViewBuilder
    private func rowBackground(for item: SidebarItem) -> some View {
        if selection == item {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [NeonColors.purple.opacity(0.8), NeonColors.cyan.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 4) // Adjust padding to fit sidebar list better
        } else {
            Color.clear
        }
    }
}

struct SidebarRow: View {
    let item: SidebarItem
    let selection: SidebarItem?
    
    var body: some View {
        NavigationLink(value: item) {
            Label {
                Text(item.title)
                    .foregroundColor(selection == item ? .white : .white.opacity(0.8))
            } icon: {
                Image(systemName: item.icon)
                    .foregroundColor(selection == item ? .white : NeonColors.cyan)
            }
        }
        .listRowBackground(
            selection == item ? 
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [NeonColors.purple.opacity(0.8), NeonColors.cyan.opacity(0.6)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
            : nil
        )
    }
}
