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
            ContentView()
        }
        .modelContainer(HistoryManager.shared.container)
    }
}
