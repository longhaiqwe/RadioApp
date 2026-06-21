enum SidebarPlayerPresentationPolicy {
    static func shouldDismissPlayerOnSidebarActivation<Selection>(
        activatedSelection: Selection?,
        isPlayerPresented: Bool
    ) -> Bool {
        isPlayerPresented && activatedSelection != nil
    }

    static func shouldDismissPlayerOnSelectionChange<Selection: Equatable>(
        from oldSelection: Selection?,
        to newSelection: Selection?,
        isPlayerPresented: Bool
    ) -> Bool {
        isPlayerPresented && oldSelection != newSelection
    }
}
