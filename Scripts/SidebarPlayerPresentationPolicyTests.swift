import Foundation

private enum TestSidebarItem: Equatable {
    case home
    case favorites
    case history
}

@main
struct SidebarPlayerPresentationPolicyTests {
    static func main() {
        testDismissesPresentedPlayerWhenSelectionChanges()
        testDismissesPresentedPlayerWhenSidebarDestinationIsActivated()
        testKeepsPresentedPlayerWhenSelectionStaysTheSame()
        testKeepsHiddenPlayerHiddenWhenSelectionChanges()
        testDismissesPresentedPlayerWhenSelectionAppearsFromNil()
        print("SidebarPlayerPresentationPolicyTests passed")
    }
}

private func testDismissesPresentedPlayerWhenSelectionChanges() {
    let shouldDismiss = SidebarPlayerPresentationPolicy.shouldDismissPlayerOnSelectionChange(
        from: TestSidebarItem.home,
        to: TestSidebarItem.favorites,
        isPlayerPresented: true
    )

    expectTrue(shouldDismiss, "Changing sidebar destinations should dismiss the presented player")
}

private func testDismissesPresentedPlayerWhenSidebarDestinationIsActivated() {
    let shouldDismiss = SidebarPlayerPresentationPolicy.shouldDismissPlayerOnSidebarActivation(
        activatedSelection: TestSidebarItem.favorites,
        isPlayerPresented: true
    )

    expectTrue(shouldDismiss, "Activating any sidebar destination should dismiss the presented player")
}

private func testKeepsPresentedPlayerWhenSelectionStaysTheSame() {
    let shouldDismiss = SidebarPlayerPresentationPolicy.shouldDismissPlayerOnSelectionChange(
        from: TestSidebarItem.history,
        to: TestSidebarItem.history,
        isPlayerPresented: true
    )

    expectFalse(shouldDismiss, "Re-selecting the same destination should not dismiss the player")
}

private func testKeepsHiddenPlayerHiddenWhenSelectionChanges() {
    let shouldDismiss = SidebarPlayerPresentationPolicy.shouldDismissPlayerOnSelectionChange(
        from: TestSidebarItem.home,
        to: TestSidebarItem.history,
        isPlayerPresented: false
    )

    expectFalse(shouldDismiss, "Hidden player should not request another dismissal")
}

private func testDismissesPresentedPlayerWhenSelectionAppearsFromNil() {
    let shouldDismiss = SidebarPlayerPresentationPolicy.shouldDismissPlayerOnSelectionChange(
        from: Optional<TestSidebarItem>.none,
        to: TestSidebarItem.home,
        isPlayerPresented: true
    )

    expectTrue(shouldDismiss, "Selecting a destination from nil should dismiss the presented player")
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
