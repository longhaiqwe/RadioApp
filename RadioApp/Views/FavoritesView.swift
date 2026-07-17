import SwiftUI
import UniformTypeIdentifiers

private enum FavoriteGroupFilter: Equatable {
    case all
    case group(String)
    case ungrouped
}

private enum FavoriteGroupEditorMode {
    case create
    case rename(FavoriteGroup)
}

struct FavoritesView: View {
    @ObservedObject var favoritesManager = FavoritesManager.shared
    @ObservedObject var stationBlockManager = StationBlockManager.shared
    @ObservedObject var playerManager = AudioPlayerManager.shared
    @State private var searchText = ""
    @State private var selectedFilter: FavoriteGroupFilter = .all
    @State private var groupNameDraft = ""
    @State private var groupEditorMode: FavoriteGroupEditorMode?
    @State private var groupPendingDelete: FavoriteGroup?
    @State private var draggingStation: Station?

    private var visibleFavorites: [Station] {
        favoritesManager.favoriteStations.filter { !stationBlockManager.isBlocked($0) }
    }

    var filteredStations: [Station] {
        let stationsForGroup: [Station]
        switch selectedFilter {
        case .all:
            stationsForGroup = visibleFavorites
        case .group(let groupID):
            stationsForGroup = visibleFavorites.filter { favoritesManager.groupID(for: $0) == groupID }
        case .ungrouped:
            stationsForGroup = visibleFavorites.filter { favoritesManager.groupID(for: $0) == nil }
        }

        if searchText.isEmpty {
            return stationsForGroup
        } else {
            return stationsForGroup.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]

    var body: some View {
        mainContent
            .searchable(text: $searchText, prompt: "搜索收藏")
            .alert(groupEditorTitle, isPresented: isGroupEditorPresented) {
                TextField("分组名称", text: $groupNameDraft)

                Button(groupEditorActionTitle) {
                    commitGroupEditor()
                }
                .disabled(trimmedGroupName.isEmpty)

                Button("取消", role: .cancel) {
                    groupEditorMode = nil
                }
            }
            .confirmationDialog("删除分组？", isPresented: isDeleteConfirmationPresented, titleVisibility: .visible) {
                if let group = groupPendingDelete {
                    Button("删除「\(group.name)」", role: .destructive) {
                        favoritesManager.deleteFavoriteGroup(id: group.id)
                        selectedFilter = .all
                        groupPendingDelete = nil
                    }
                }

                Button("取消", role: .cancel) {}
            } message: {
                Text("收藏电台会保留，并移动到未分组。")
            }
            .onChange(of: favoritesManager.favoriteGroups) { _, groups in
                guard case .group(let selectedGroupID) = selectedFilter else { return }
                if !groups.contains(where: { $0.id == selectedGroupID }) {
                    selectedFilter = .all
                }
            }
    }

    private var mainContent: some View {
        ZStack {
            AnimatedMeshBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerView
                        .padding(.horizontal)
                        .padding(.top, 20)

                    groupFilterBar

                    stationContent
                }
                .padding(.bottom, 100) // Space for mini player
            }
        }
    }

    @ViewBuilder
    private var stationContent: some View {
        if filteredStations.isEmpty {
            emptyStateView
        } else {
            stationGrid
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            Text(emptyStateTitle)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var stationGrid: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(filteredStations) { station in
                favoriteStationCard(for: station)
                    .opacity(draggingStation?.id == station.id ? 0.62 : 1)
                    .onDrag {
                        draggingStation = station
                        return NSItemProvider(object: station.id as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: StationDropDelegate(
                            item: station,
                            visibleItems: filteredStations,
                            favoritesManager: favoritesManager,
                            draggingItem: $draggingStation
                        )
                    )
            }
        }
        .padding(.horizontal)
    }

    private func favoriteStationCard(for station: Station) -> some View {
        NeonStationCard(
            station: station,
            isPlaying: playerManager.currentStation?.id == station.id && playerManager.isPlaying
        )
        .onTapGesture {
            playerManager.play(station: station, in: filteredStations, title: "我的收藏")
        }
        .contextMenu {
            FavoriteGroupAssignmentMenu(station: station) {
                Label("移动到分组", systemImage: "folder")
            }

            Button(role: .destructive) {
                favoritesManager.removeFavorite(station)
            } label: {
                Label("取消收藏", systemImage: "heart.slash")
            }
        }
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("我的收藏")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("\(visibleFavorites.count) 个电台 · \(favoritesManager.favoriteGroups.count) 个分组")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(NeonColors.cyan.opacity(0.75))
            }

            Spacer()

            Button(action: beginCreateGroup) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(NeonColors.cyan.opacity(0.18))
                            .overlay(
                                Circle()
                                    .stroke(NeonColors.cyan.opacity(0.35), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .neonGlow(color: NeonColors.cyan.opacity(0.55), radius: 6)

            Menu {
                Button {
                    beginCreateGroup()
                } label: {
                    Label("新增分组", systemImage: "folder.badge.plus")
                }

                if let group = selectedCustomGroup {
                    Button {
                        beginRenameGroup(group)
                    } label: {
                        Label("重命名当前分组", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        groupPendingDelete = group
                    } label: {
                        Label("删除当前分组", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        }
    }

    private var groupFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FavoriteGroupFilterChip(
                    title: "全部",
                    count: visibleFavorites.count,
                    systemImage: "rectangle.stack.fill",
                    isSelected: selectedFilter == .all
                ) {
                    selectedFilter = .all
                }

                ForEach(favoritesManager.favoriteGroups) { group in
                    FavoriteGroupFilterChip(
                        title: group.name,
                        count: visibleFavorites.filter { favoritesManager.groupID(for: $0) == group.id }.count,
                        systemImage: "folder.fill",
                        isSelected: selectedFilter == .group(group.id)
                    ) {
                        selectedFilter = .group(group.id)
                    }
                    .contextMenu {
                        Button {
                            beginRenameGroup(group)
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            groupPendingDelete = group
                        } label: {
                            Label("删除分组", systemImage: "trash")
                        }
                    }
                }

                FavoriteGroupFilterChip(
                    title: "未分组",
                    count: visibleFavorites.filter { favoritesManager.groupID(for: $0) == nil }.count,
                    systemImage: "tray.fill",
                    isSelected: selectedFilter == .ungrouped
                ) {
                    selectedFilter = .ungrouped
                }
            }
            .padding(.horizontal)
        }
    }

    private var selectedCustomGroup: FavoriteGroup? {
        guard case .group(let groupID) = selectedFilter else { return nil }
        return favoritesManager.favoriteGroups.first { $0.id == groupID }
    }

    private var emptyStateIcon: String {
        if !searchText.isEmpty { return "magnifyingglass" }
        switch selectedFilter {
        case .all:
            return "heart.slash"
        case .group:
            return "folder"
        case .ungrouped:
            return "tray"
        }
    }

    private var emptyStateTitle: String {
        if !searchText.isEmpty { return "没有匹配的收藏" }
        switch selectedFilter {
        case .all:
            return "还没有收藏电台"
        case .group:
            return "这个分组还没有电台"
        case .ungrouped:
            return "没有未分组电台"
        }
    }

    private var groupEditorTitle: String {
        switch groupEditorMode {
        case .rename:
            return "重命名分组"
        case .create, .none:
            return "新增分组"
        }
    }

    private var groupEditorActionTitle: String {
        switch groupEditorMode {
        case .rename:
            return "保存"
        case .create, .none:
            return "新增"
        }
    }

    private var trimmedGroupName: String {
        groupNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isGroupEditorPresented: Binding<Bool> {
        Binding(
            get: { groupEditorMode != nil },
            set: { isPresented in
                if !isPresented {
                    groupEditorMode = nil
                }
            }
        )
    }

    private var isDeleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { groupPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    groupPendingDelete = nil
                }
            }
        )
    }

    private func beginCreateGroup() {
        groupNameDraft = ""
        groupEditorMode = .create
    }

    private func beginRenameGroup(_ group: FavoriteGroup) {
        groupNameDraft = group.name
        groupEditorMode = .rename(group)
    }

    private func commitGroupEditor() {
        switch groupEditorMode {
        case .create:
            if let group = favoritesManager.createFavoriteGroup(named: groupNameDraft) {
                selectedFilter = .group(group.id)
            }
        case .rename(let group):
            if favoritesManager.renameFavoriteGroup(id: group.id, to: groupNameDraft) {
                selectedFilter = .group(group.id)
            }
        case .none:
            break
        }

        groupEditorMode = nil
    }
}

struct FavoriteGroupFilterChip: View {
    let title: String
    let count: Int
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isSelected ? NeonColors.darkBg.opacity(0.85) : NeonColors.cyan)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(isSelected ? .white.opacity(0.65) : NeonColors.cyan.opacity(0.14))
                    )
            }
            .foregroundColor(isSelected ? NeonColors.darkBg : .white.opacity(0.78))
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isSelected ? NeonColors.cyan : Color.white.opacity(0.08))
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? NeonColors.cyan.opacity(0.9) : Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .neonGlow(color: isSelected ? NeonColors.cyan.opacity(0.45) : .clear, radius: 6)
    }
}

struct FavoriteGroupAssignmentMenu<LabelContent: View>: View {
    let station: Station
    private let label: () -> LabelContent
    @ObservedObject private var favoritesManager = FavoritesManager.shared

    init(station: Station, @ViewBuilder label: @escaping () -> LabelContent) {
        self.station = station
        self.label = label
    }

    var body: some View {
        Menu {
            assignmentItems
        } label: {
            label()
        }
    }

    @ViewBuilder
    private var assignmentItems: some View {
        let currentGroupID = favoritesManager.groupID(for: station)

        Button {
            favoritesManager.addFavorite(station)
            favoritesManager.assignFavorite(station, toGroupID: nil)
        } label: {
            Label(
                favoritesManager.isFavorite(station) ? "未分组" : "收藏到未分组",
                systemImage: currentGroupID == nil && favoritesManager.isFavorite(station) ? "checkmark" : "tray"
            )
        }

        if !favoritesManager.favoriteGroups.isEmpty {
            Divider()
        }

        ForEach(favoritesManager.favoriteGroups) { group in
            Button {
                favoritesManager.addFavorite(station, groupID: group.id)
            } label: {
                Label(
                    group.name,
                    systemImage: currentGroupID == group.id ? "checkmark.circle.fill" : "folder"
                )
            }
        }
    }
}
