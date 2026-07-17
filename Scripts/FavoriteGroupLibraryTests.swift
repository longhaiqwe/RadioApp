import Foundation

@main
struct FavoriteGroupLibraryTests {
    static func main() {
        testCreatesAndRenamesGroupsWithTrimmedNames()
        testAssigningStationMovesBetweenGroups()
        testDeletingGroupKeepsStationUngrouped()
        testReorderingFilteredFavoritesKeepsHiddenStationsInPlace()
        print("FavoriteGroupLibraryTests passed")
    }
}

private func testCreatesAndRenamesGroupsWithTrimmedNames() {
    var library = FavoriteGroupLibrary()

    let group = library.createGroup(named: "  音乐  ")
    expectEqual(group?.name, "音乐", "Group names should be trimmed when created")
    expectEqual(library.groups.count, 1, "A non-empty group should be created")

    let renamed = library.renameGroup(id: group!.id, to: " 新闻 ")
    expectTrue(renamed, "Existing groups should be renameable")
    expectEqual(library.groups.first?.name, "新闻", "Group names should be trimmed when renamed")

    let blankRename = library.renameGroup(id: group!.id, to: "   ")
    expectFalse(blankRename, "Blank group names should be rejected")
    expectEqual(library.groups.first?.name, "新闻", "Rejected renames should keep the previous name")
}

private func testAssigningStationMovesBetweenGroups() {
    var library = FavoriteGroupLibrary()
    let music = library.createGroup(named: "音乐")!
    let news = library.createGroup(named: "新闻")!
    let stationKey = "station-1"

    expectTrue(library.assignStation(stationKey, to: music.id), "Station should be assignable to an existing group")
    expectEqual(library.groupID(forStationKey: stationKey), music.id, "Station should belong to the first group")

    expectTrue(library.assignStation(stationKey, to: news.id), "Station should be movable to another group")
    expectEqual(library.groupID(forStationKey: stationKey), news.id, "Station should belong to the new group only")

    expectTrue(library.assignStation(stationKey, to: nil), "Station should be removable from a group")
    expectNil(library.groupID(forStationKey: stationKey), "Ungrouped station should have no group id")
}

private func testDeletingGroupKeepsStationUngrouped() {
    var library = FavoriteGroupLibrary()
    let music = library.createGroup(named: "音乐")!
    let stationKey = "station-1"

    _ = library.assignStation(stationKey, to: music.id)
    library.deleteGroup(id: music.id)

    expectTrue(library.groups.isEmpty, "Deleted groups should be removed")
    expectNil(library.groupID(forStationKey: stationKey), "Deleting a group should not keep dangling station assignments")
}

private func testReorderingFilteredFavoritesKeepsHiddenStationsInPlace() {
    let first = makeStation(id: "first")
    let hidden = makeStation(id: "hidden")
    let second = makeStation(id: "second")
    let third = makeStation(id: "third")

    let reordered = FavoriteStationOrdering.reorderedStations(
        [first, hidden, second, third],
        moving: third,
        over: first,
        visibleStations: [first, second, third]
    )

    expectEqual(
        reordered.map(\.id),
        ["third", "hidden", "first", "second"],
        "Reordering a filtered favorites view should keep hidden stations in their original slots"
    )
}

private func makeStation(id: String) -> Station {
    Station(
        changeuuid: id,
        stationuuid: id,
        name: id,
        url: "https://example.com/\(id)",
        urlResolved: "https://example.com/\(id)",
        homepage: "",
        favicon: "",
        tags: "",
        country: "",
        countrycode: "",
        state: "",
        language: "",
        languagecodes: nil,
        votes: 0,
        lastchangetime: "",
        codec: "",
        bitrate: 0,
        hls: 0,
        lastcheckok: 1,
        lastchecktime: "",
        lastcheckoktime: "",
        lastlocalchecktime: "",
        clicktimestamp: "",
        clickcount: 0,
        clicktrend: 0
    )
}

private func expectTrue(_ value: Bool, _ message: String) {
    guard value else {
        fatalError(message)
    }
}

private func expectFalse(_ value: Bool, _ message: String) {
    guard !value else {
        fatalError(message)
    }
}

private func expectNil<T>(_ value: T?, _ message: String) {
    guard value == nil else {
        fatalError(message)
    }
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    guard actual == expected else {
        fatalError("\(message). Expected \(expected), got \(actual)")
    }
}
