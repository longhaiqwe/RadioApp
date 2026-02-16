import SwiftUI
import SwiftData

@main
struct RadioApp: App {
    
    init() {
        // 初始化 PostHog SDK
        PostHogManager.shared.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            MainLayout()
        }
        .modelContainer(HistoryManager.shared.container)
        #if targetEnvironment(macCatalyst)
        .defaultSize(width: 1000, height: 750)
        #endif
    }
}
